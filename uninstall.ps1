#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstalls windots configurations, removes softlinks, and restores backups.
.DESCRIPTION
    Reverts system modifications made by windots setup scripts by removing
    created symbolic links, restoring .old backup files, resetting Git hook
    configuration, and optionally removing provisioned Conda/Micromamba environments.
.PARAMETER DryRun
    Simulates uninstallation actions without making changes.
.PARAMETER RemoveEnvironments
    Also removes provisioned Conda/Micromamba environments (e.g. 'R').
.PARAMETER SkipElevationCheck
    Bypasses administrative privilege check.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun,
    [switch]$RemoveEnvironments,
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

Write-Host "=== Uninstalling Windows Dotfiles ===" -ForegroundColor "Cyan"
if ($DryRun) {
    Write-Host "[DRY RUN MODE ENABLED - No changes will be made]" -ForegroundColor "Yellow"
}

# List of softlinks managed by windots
$docPath = [Environment]::GetFolderPath("MyDocuments")
$managedLinks = @(
    # Git
    "$HOME\.config\git\config",
    "$HOME\.config\git\.gitignore",
    "$HOME\.config\git\.gitattributes",
    "$HOME\.config\git\.gitmessage",
    "$env:ProgramFiles\Git\etc\gitconfig",

    # VS Code
    "$env:APPDATA\Code\User\settings.json",

    # PowerShell Profiles
    "$docPath\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$docPath\PowerShell\Microsoft.PowerShell_profile.ps1",

    # Windows Terminal
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",

    # GnuPG
    "$HOME\.gnupg\gpg.conf",
    "$HOME\.gnupg\common.conf",

    # WSL
    "$HOME\.wslconfig",

    # Micromamba / Conda
    "$HOME\.mambarc",
    "$HOME\.condarc",

    # R / Rdots
    "$HOME\.config\R\.Rprofile",
    "$HOME\.Rprofile"
)

Write-Host "`nRemoving managed softlinks and restoring backups..." -ForegroundColor "Yellow"
foreach ($link in $managedLinks) {
    Remove-Softlink -Path $link -DryRun:$DryRun
}

# Reset Git hooks path
if (Test-Path (Join-Path $PSScriptRoot ".git")) {
    $currentHooksPath = & git config --get core.hooksPath 2>$null
    if ($currentHooksPath -eq ".githooks") {
        if ($DryRun) {
            Write-Host "[DryRun] Would reset git config core.hooksPath" -ForegroundColor DarkCyan
        }
        else {
            Write-Host "Resetting git config core.hooksPath..." -ForegroundColor Yellow
            git config --unset core.hooksPath
        }
    }
}

# Optional: Remove provisioned 'R' environment in Mamba / Micromamba
if ($RemoveEnvironments) {
    $mambaExec = if (Get-Command mamba -ErrorAction SilentlyContinue) { "mamba" } elseif (Get-Command micromamba -ErrorAction SilentlyContinue) { "micromamba" } else { $null }
    if ($mambaExec) {
        if ($DryRun) {
            Write-Host "[DryRun] Would remove $mambaExec environment 'R'" -ForegroundColor DarkCyan
        }
        elseif ($PSCmdlet.ShouldProcess("R", "Remove Mamba Environment")) {
            Write-Host "Removing $mambaExec environment 'R'..." -ForegroundColor Cyan
            & $mambaExec env remove -n R -y
        }
    }
}

$global:LASTEXITCODE = 0
Write-Host "`nUninstallation completed successfully." -ForegroundColor "Green"
