#Requires -Version 5.1
<#
.SYNOPSIS
    Main setup script for Windows dotfiles (windots).
.DESCRIPTION
    Configures Windows, terminal, developer tools, shell profiles, and creates
    symbolic links to configuration files.
.PARAMETER DryRun
    Simulates actions without making changes to the system.
.PARAMETER Components
    Specifies which component modules to run. Default is all.
.PARAMETER SkipElevationCheck
    Bypasses administrative privilege check (useful for dry runs or testing).
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun,
    [ValidateSet("windows", "vscode", "git", "powershell", "powertoys", "wsl", "terminal", "gpg", "mamba")]
    [string[]]$Components = @("windows", "vscode", "git", "powershell", "powertoys", "wsl", "terminal", "gpg", "mamba"),
    [switch]$SkipElevationCheck
)

$ErrorActionPreference = "Stop"

# Import shared helper functions
$commonScript = Join-Path -Path $PSScriptRoot -ChildPath "scripts\common.ps1"
if (Test-Path -Path $commonScript) {
    . $commonScript
}
else {
    throw "Required helper script '$commonScript' not found."
}

# Check administrative privileges
if (-not $SkipElevationCheck -and -not $DryRun) {
    if (-not (Test-Admin)) {
        throw "Administrative privileges required. Please run PowerShell as Administrator."
    }
}

Write-Host "=== Configuring Windows Dotfiles ===" -ForegroundColor "Cyan"
if ($DryRun) {
    Write-Host "[DRY RUN MODE ENABLED - No changes will be made]" -ForegroundColor "Yellow"
}

# Configure local git hooks if running inside a git repository
if (Test-Path (Join-Path $PSScriptRoot ".git")) {
    $hooksDir = Join-Path $PSScriptRoot ".githooks"
    if (Test-Path $hooksDir) {
        Write-Host "Configuring git hooks path to .githooks..." -ForegroundColor "DarkGray"
        if (-not $DryRun) {
            git config core.hooksPath .githooks
        }
    }
}

# Trust PSGallery for PowerShell package management
if (-not $DryRun) {
    try {
        $gallery = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
        if ($gallery -and $gallery.InstallationPolicy -ne "Trusted") {
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Warning "Could not configure PSGallery repository policy: $_"
    }
}

# Create core user directories
New-Directory -Path "$HOME\repo" -DryRun:$DryRun
New-Directory -Path "$HOME\.config" -Hide -DryRun:$DryRun

# Execute selected component setup scripts
foreach ($component in $Components) {
    $componentScript = Join-Path -Path $PSScriptRoot -ChildPath "$component\setup.ps1"
    if (Test-Path -Path $componentScript) {
        Write-Host "`n--> Running setup for: $component" -ForegroundColor "Yellow"
        try {
            . $componentScript -DryRun:$DryRun
        }
        catch {
            Write-Error "Error executing $component setup: $_"
        }
    }
    else {
        Write-Warning "Setup script for component '$component' not found at '$componentScript'."
    }
}

Write-Host "`nSetup completed successfully." -ForegroundColor "Green"
