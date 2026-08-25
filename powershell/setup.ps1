#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and configures PowerShell environment, modules, and profile.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# Install NuGet Package Provider
if (-not $DryRun) {
    try {
        if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        }
    }
    catch {
        Write-Warning "Could not install NuGet package provider: $_"
    }
}

# Install Oh-My-Posh via Micromamba (or fallback to winget)
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    $installed = Install-MambaPackage -PackageName "oh-my-posh" -CommandCheck "oh-my-posh" -DryRun:$DryRun
    if (-not $installed -and -not $DryRun) {
        if ($PSCmdlet.ShouldProcess("Oh-My-Posh", "Install via winget")) {
            Write-Host "Falling back to winget for Oh-My-Posh..." -ForegroundColor Cyan
            winget install --id JanDeDobbeleer.OhMyPosh -e --source winget --accept-source-agreements --accept-package-agreements
        }
    }
}
else {
    Write-Host "Oh-My-Posh is already installed." -ForegroundColor DarkGray
}

# Install recommended PowerShell modules
$modules = @(
    "PSReadLine",
    "Terminal-Icons",
    "PSScriptAnalyzer"
)

foreach ($mod in $modules) {
    $existingMod = Get-Module -ListAvailable -Name $mod | Sort-Object Version -Descending | Select-Object -First 1
    $needsInstall = ($existingMod -eq $null)
    if ($mod -eq "PSReadLine" -and $existingMod -and ($existingMod.Version -lt [version]"2.2.0")) {
        $needsInstall = $true
    }

    if ($needsInstall) {
        if ($DryRun) {
            Write-Host "[DryRun] Would install/update PowerShell module: $mod" -ForegroundColor DarkCyan
        }
        else {
            Write-Host "Installing/updating module: $mod..." -ForegroundColor Cyan
            Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Host "Module '$mod' (v$($existingMod.Version)) is already installed." -ForegroundColor DarkGray
    }
}

# Configure PowerShell Profiles
$profileSource = Join-Path -Path $PSScriptRoot -ChildPath "profile.ps1"

# Windows PowerShell profile path
$winPSDir = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath "WindowsPowerShell"
New-Directory -Path $winPSDir -DryRun:$DryRun
Set-Softlink -Path (Join-Path $winPSDir "Microsoft.PowerShell_profile.ps1") -Target $profileSource -DryRun:$DryRun

# PowerShell Core (pwsh) profile path
$pwshDir = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath "PowerShell"
New-Directory -Path $pwshDir -DryRun:$DryRun
Set-Softlink -Path (Join-Path $pwshDir "Microsoft.PowerShell_profile.ps1") -Target $profileSource -DryRun:$DryRun
