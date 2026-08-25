#Requires -Version 5.1
<#
.SYNOPSIS
    Zero-dependency standalone bootstrapper and installer for Windows dotfiles (windots).
.DESCRIPTION
    Installs dotfiles on a fresh Windows 10/11 system without requiring Git or any pre-installed tools.
    Downloads the repository via GitHub ZIP archive (or git clone if available), bootstraps package
    managers and core dependencies (Winget, Git, PowerShell 7, Windows Terminal, GnuPG, Mamba),
    and executes setup.ps1.
.PARAMETER Destination
    Target directory to clone or extract the repository. Defaults to '$HOME\repo\windots'.
.PARAMETER Branch
    Git branch or archive release to download. Defaults to 'main'.
.PARAMETER Components
    Specific component modules to configure in setup.ps1.
.PARAMETER DryRun
    Simulates download, dependency installations, and setup without modifying the system.
.PARAMETER SkipElevationCheck
    Bypasses administrative privilege check.
.PARAMETER SkipDependencies
    Skips installing system package dependencies and only configures dotfiles.
.EXAMPLE
    # One-liner execution from vanilla PowerShell:
    irm https://raw.githubusercontent.com/andreassag/windots/main/install.ps1 | iex
.EXAMPLE
    # Dry-run test:
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/andreassag/windots/main/install.ps1))) -DryRun -SkipElevationCheck
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [string]$Destination = "$HOME\repo\windots",
    [string]$Branch = "main",
    [string[]]$Components,
    [switch]$DryRun,
    [switch]$SkipElevationCheck,
    [switch]$SkipDependencies
)

$ErrorActionPreference = "Stop"

# Ensure TLS 1.2 for secure GitHub downloads across all PowerShell versions
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Windows Dotfiles (windots) Bootstrapper " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[DRY RUN MODE ENABLED - No changes will be made]`n" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 1. Elevation & Administrator Check
# -----------------------------------------------------------------------------
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not $SkipElevationCheck -and -not $DryRun) {
    if (-not (Test-IsAdmin)) {
        Write-Host "Administrative privileges are required for system configuration." -ForegroundColor Yellow
        Write-Host "Relaunching in an elevated PowerShell session..." -ForegroundColor Cyan

        $scriptArgs = "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
        if ($Destination) { $scriptArgs += " -Destination `"$Destination`"" }
        if ($Branch) { $scriptArgs += " -Branch `"$Branch`"" }
        if ($Components) { $scriptArgs += " -Components $($Components -join ',')" }
        if ($SkipDependencies) { $scriptArgs += " -SkipDependencies" }

        try {
            Start-Process powershell -Verb RunAs -ArgumentList $scriptArgs
            exit 0
        }
        catch {
            throw "Failed to elevate privileges: $_. Please run PowerShell as Administrator."
        }
    }
}

# -----------------------------------------------------------------------------
# 2. Smart Repository Retrieval (without Git prerequisite)
# -----------------------------------------------------------------------------
$repoUrl = "https://github.com/andreassag/windots"
$zipUrl = "$repoUrl/archive/refs/heads/$Branch.zip"
$downloadedViaZip = $false

if (-not (Test-Path $Destination)) {
    if ($DryRun) {
        Write-Host "[DryRun] Would create directory: $Destination" -ForegroundColor DarkCyan
    }
    else {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
}

$hasGit = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
$isGitRepo = Test-Path (Join-Path $Destination ".git")

if ($isGitRepo -and $hasGit) {
    Write-Host "Existing Git repository detected at '$Destination'." -ForegroundColor DarkGray
    if (-not $DryRun) {
        Push-Location $Destination
        try {
            git pull --quiet
        }
        catch {
            Write-Warning "Could not update existing repository with git pull: $_"
        }
        finally {
            Pop-Location
        }
    }
}
elseif ($hasGit -and (-not (Test-Path (Join-Path $Destination "setup.ps1")))) {
    Write-Host "Cloning windots repository via Git to '$Destination'..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "[DryRun] Would run: git clone --branch $Branch $repoUrl.git `"$Destination`"" -ForegroundColor DarkCyan
    }
    else {
        git clone --branch $Branch "$repoUrl.git" "$Destination"
    }
}
elseif (-not (Test-Path (Join-Path $Destination "setup.ps1"))) {
    Write-Host "Git not detected. Downloading windots archive ($Branch) from GitHub..." -ForegroundColor Cyan
    $tempZip = Join-Path $env:TEMP "windots-$Branch.zip"
    $tempExtract = Join-Path $env:TEMP "windots-extract-$([Guid]::NewGuid().ToString('N'))"

    if ($DryRun) {
        Write-Host "[DryRun] Would download $zipUrl to $tempZip" -ForegroundColor DarkCyan
        Write-Host "[DryRun] Would extract and populate $Destination" -ForegroundColor DarkCyan
    }
    else {
        Write-Host "Downloading $zipUrl..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing

        Write-Host "Extracting archive to temporary folder..." -ForegroundColor DarkGray
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        # GitHub archives contain a root folder e.g. windots-main
        $extractedRoot = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
        if ($extractedRoot) {
            Write-Host "Populating target directory '$Destination'..." -ForegroundColor DarkGray
            Copy-Item -Path "$($extractedRoot.FullName)\*" -Destination $Destination -Recurse -Force
        }

        # Cleanup temporary files
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        $downloadedViaZip = $true
    }
}
else {
    Write-Host "Repository files already present at '$Destination'." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# 3. Autonomous Dependency Installation (Micromamba, Git, GnuPG, CLI & GUI Tools)
# -----------------------------------------------------------------------------
if (-not $SkipDependencies) {
    Write-Host "`nChecking core system dependencies..." -ForegroundColor "Yellow"

    # 3.1 Bootstrap Standalone Micromamba
    $mambaBinDir = "$HOME\.local\bin"
    $mambaExe = $null

    if (Get-Command micromamba -ErrorAction SilentlyContinue) {
        $mambaExe = (Get-Command micromamba).Source
    }
    else {
        $candidatePaths = @(
            "$mambaBinDir\micromamba.exe",
            "$HOME\micromamba\bin\micromamba.exe",
            "$env:LOCALAPPDATA\Microsoft\WinGet\Links\micromamba.exe",
            "$env:LOCALAPPDATA\micromamba\micromamba.exe",
            "C:\Program Files\micromamba\micromamba.exe"
        )
        foreach ($cand in $candidatePaths) {
            if (Test-Path $cand) {
                $mambaExe = $cand
                $binFolder = Split-Path -Path $cand -Parent
                if ($env:PATH -notlike "*$binFolder*") {
                    $env:PATH = "$env:PATH;$binFolder"
                }
                break
            }
        }
    }

    if (-not $mambaExe) {
        if ($DryRun) {
            Write-Host "[DryRun] Would download standalone Micromamba binary to $mambaBinDir\micromamba.exe" -ForegroundColor DarkCyan
            $mambaExe = "$mambaBinDir\micromamba.exe"
        }
        else {
            Write-Host "Bootstrapping standalone Micromamba..." -ForegroundColor Cyan
            if (-not (Test-Path $mambaBinDir)) {
                New-Item -ItemType Directory -Path $mambaBinDir -Force | Out-Null
            }
            $targetExe = "$mambaBinDir\micromamba.exe"
            $downloadUrl = "https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-win-64.exe"
            try {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $targetExe -UseBasicParsing
                $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
                if ($userPath -notlike "*$mambaBinDir*") {
                    [Environment]::SetEnvironmentVariable("Path", "$userPath;$mambaBinDir", "User")
                }
                $env:PATH = "$env:PATH;$mambaBinDir"
                $mambaExe = $targetExe
            }
            catch {
                Write-Warning "Could not bootstrap standalone Micromamba: $_"
            }
        }
    }

    # 3.2 Helper function to install packages via Micromamba
    function Install-CliTool {
        param (
            [string]$PackageName,
            [string]$CommandCheck,
            [string]$WingetId
        )

        $installed = if ($CommandCheck) { (Get-Command $CommandCheck -ErrorAction SilentlyContinue) -ne $null } else { $false }
        if ($installed) {
            Write-Host "$PackageName is already installed." -ForegroundColor DarkGray
            return
        }

        if ($DryRun) {
            Write-Host "[DryRun] Would install $PackageName via Micromamba (channel: conda-forge)" -ForegroundColor DarkCyan
            return
        }

        if ($mambaExe -and (Test-Path $mambaExe)) {
            Write-Host "Installing $PackageName via Micromamba..." -ForegroundColor Cyan
            try {
                & $mambaExe install -n base -c conda-forge $PackageName -y
                return
            }
            catch {
                Write-Warning "Micromamba installation of $PackageName failed: $_"
            }
        }

        # Fallback to winget if available
        if ($WingetId -and (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "Falling back to winget for $PackageName ($WingetId)..." -ForegroundColor Cyan
            try {
                winget install --id $WingetId -e --source winget --accept-source-agreements --accept-package-agreements
            }
            catch {
                Write-Warning "Winget installation of $PackageName failed: $_"
            }
        }
    }

    # Install CLI tools via Micromamba (with winget fallback)
    Install-CliTool -PackageName "git" -CommandCheck "git" -WingetId "Git.Git"
    Install-CliTool -PackageName "gnupg" -CommandCheck "gpg" -WingetId "GnuPG.Gpg4win"
    Install-CliTool -PackageName "gh" -CommandCheck "gh" -WingetId "GitHub.cli"
    Install-CliTool -PackageName "oh-my-posh" -CommandCheck "oh-my-posh" -WingetId "JanDeDobbeleer.OhMyPosh"

    # 3.3 Helper function to install Windows GUI packages via Winget
    $hasWinget = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
    if (-not $hasWinget -and -not $DryRun) {
        Write-Host "Winget not found. Attempting to bootstrap Windows Package Manager..." -ForegroundColor Cyan
        try {
            $wingetBundle = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller.msixbundle"
            $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetBundle -UseBasicParsing
            Add-AppxPackage -Path $wingetBundle -ErrorAction Stop
            Remove-Item -Path $wingetBundle -Force -ErrorAction SilentlyContinue
            $hasWinget = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
        }
        catch {
            Write-Warning "Could not automatically bootstrap Winget: $_"
        }
    }

    function Install-GuiPackage {
        param (
            [string]$Id,
            [string]$Name,
            [string]$CommandCheck
        )

        $installed = if ($CommandCheck) { (Get-Command $CommandCheck -ErrorAction SilentlyContinue) -ne $null } else { $false }
        if ($installed) {
            Write-Host "$Name is already installed." -ForegroundColor DarkGray
            return
        }

        if ($DryRun) {
            Write-Host "[DryRun] Would install $Name via Winget (ID: $Id)" -ForegroundColor DarkCyan
            return
        }

        if ($hasWinget) {
            Write-Host "Installing $Name ($Id)..." -ForegroundColor Cyan
            try {
                winget install --id $Id -e --source winget --accept-source-agreements --accept-package-agreements
            }
            catch {
                Write-Warning "Winget installation of $Name failed: $_"
            }
        }
        else {
            Write-Warning "Winget is unavailable; skipping installation of $Name ($Id)."
        }
    }

    Install-GuiPackage -Id "Microsoft.PowerShell" -Name "PowerShell 7" -CommandCheck "pwsh"
    Install-GuiPackage -Id "Microsoft.WindowsTerminal" -Name "Windows Terminal" -CommandCheck "wt"
    Install-GuiPackage -Id "Microsoft.VisualStudioCode" -Name "Visual Studio Code" -CommandCheck "code"

    # Refresh PATH environment variable in current session
    $env:PATH = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    # If repository was extracted via ZIP, initialize Git tracking once Git is available
    if ($downloadedViaZip -or (-not (Test-Path (Join-Path $Destination ".git")))) {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Write-Host "Initializing Git tracking in '$Destination'..." -ForegroundColor Cyan
            if (-not $DryRun) {
                Push-Location $Destination
                try {
                    git init --quiet
                    git remote add origin "$repoUrl.git"
                    git branch -M $Branch
                    git fetch origin $Branch --quiet
                    git reset --mixed "origin/$Branch" --quiet
                }
                catch {
                    Write-Warning "Could not initialize Git tracking: $_"
                }
                finally {
                    Pop-Location
                }
            }
        }
    }
}

# -----------------------------------------------------------------------------
# 4. Launch setup.ps1 Orchestrator
# -----------------------------------------------------------------------------
$setupScript = Join-Path $Destination "setup.ps1"
if (-not (Test-Path $setupScript) -and $PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "setup.ps1"))) {
    $setupScript = Join-Path $PSScriptRoot "setup.ps1"
}

if (Test-Path $setupScript) {
    Write-Host "`nLaunching dotfiles setup from '$setupScript'..." -ForegroundColor "Yellow"

    $setupParams = @{
        DryRun = $DryRun
        SkipElevationCheck = $true
    }
    if ($Components -and $Components.Count -gt 0) {
        $parsedComponents = @()
        foreach ($c in $Components) {
            $parsedComponents += ($c -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
        $setupParams["Components"] = [string[]]$parsedComponents
    }

    $execDir = Split-Path -Path $setupScript -Parent
    Push-Location $execDir
    try {
        & $setupScript @setupParams
    }
    catch {
        Write-Error "Setup failed during execution: $_"
    }
    finally {
        Pop-Location
    }
}
elseif ($DryRun) {
    Write-Host "`n[DryRun] Would launch dotfiles setup from '$Destination\setup.ps1'" -ForegroundColor DarkCyan
}
else {
    Write-Error "Setup orchestrator not found at '$setupScript'."
}

$global:LASTEXITCODE = 0
Write-Host "`nInstallation process completed." -ForegroundColor "Green"
