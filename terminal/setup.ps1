#Requires -Version 5.1
<#
.SYNOPSIS
    Configures Windows Terminal settings, injects Git and Radian R paths, and links profiles.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

$sourceSettings = Join-Path -Path $PSScriptRoot -ChildPath "settings.json"

# 1. Discover Git Bash path
$gitBashCandidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "$env:ProgramFiles(x86)\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)

if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitCmd = (Get-Command git).Source
    $gitRoot = Split-Path -Path (Split-Path -Path $gitCmd -Parent) -Parent
    $gitBashCandidates = @(Join-Path $gitRoot "bin\bash.exe") + $gitBashCandidates
}

$detectedGitBash = $null
foreach ($candidate in $gitBashCandidates) {
    if (Test-Path $candidate) {
        $detectedGitBash = $candidate
        break
    }
}

# 2. Discover Micromamba path
$mambaCandidates = @(
    "$HOME\micromamba\bin\micromamba.exe",
    "$HOME\.local\bin\micromamba.exe",
    "$env:LOCALAPPDATA\micromamba\micromamba.exe",
    "C:\Program Files\micromamba\micromamba.exe"
)

if (Get-Command micromamba -ErrorAction SilentlyContinue) {
    $mambaCandidates = @((Get-Command micromamba).Source) + $mambaCandidates
}

$detectedMamba = "micromamba.exe"
foreach ($candidate in $mambaCandidates) {
    if (Test-Path $candidate) {
        $detectedMamba = $candidate
        break
    }
}

# 3. Update settings.json with discovered paths
if (Test-Path $sourceSettings) {
    try {
        $jsonContent = Get-Content -Path $sourceSettings -Raw | ConvertFrom-Json
        $modified = $false

        # Update Git Bash profile
        if ($detectedGitBash) {
            $gitProfile = $jsonContent.profiles.list | Where-Object { $_.guid -eq "{2ece5bfe-50ed-5f3a-ab87-5cd4baafed2b}" -or $_.name -eq "Git Bash" }
            if ($gitProfile) {
                $gitProfile.commandline = "`"$detectedGitBash`" -i -l"
                $gitIcon = Join-Path (Split-Path (Split-Path $detectedGitBash -Parent) -Parent) "mingw64\share\git\git-for-windows.ico"
                if (Test-Path $gitIcon) {
                    $gitProfile.icon = $gitIcon
                }
                $modified = $true
                Write-Host "Injected Git Bash path: $detectedGitBash" -ForegroundColor DarkGray
            }
        }

        # Update R (radian) profile
        $rProfile = $jsonContent.profiles.list | Where-Object { $_.guid -eq "{8b6d8ec4-512c-4c4f-a9db-484725357f89}" -or $_.name -like "R*" }
        if ($rProfile) {
            $rProfile.commandline = "$detectedMamba run -n R radian"
            $modified = $true
            Write-Host "Injected R (radian) command: $($rProfile.commandline)" -ForegroundColor DarkGray
        }

        if ($modified -and (-not $DryRun)) {
            $jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $sourceSettings -Encoding utf8
        }
    }
    catch {
        Write-Warning "Could not update terminal settings with discovered paths: $_"
    }
}

# 4. Target paths for Windows Terminal (Stable and Preview)
$terminalPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"
)

foreach ($termDir in $terminalPaths) {
    $packageDir = Split-Path -Path $termDir -Parent
    if (Test-Path $packageDir) {
        New-Directory -Path $termDir -DryRun:$DryRun
        Set-Softlink -Path (Join-Path $termDir "settings.json") -Target $sourceSettings -DryRun:$DryRun
    }
    elseif ($DryRun) {
        Write-Host "[DryRun] Would configure Windows Terminal settings at $termDir\settings.json if package is installed" -ForegroundColor DarkCyan
    }
}
