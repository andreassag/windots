#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and configures Git on Windows.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# Install Git via winget if not present
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if ($DryRun) {
        Write-Host "[DryRun] Would install Git via winget" -ForegroundColor DarkCyan
    }
    elseif ($PSCmdlet.ShouldProcess("Git", "Install via winget")) {
        Write-Host "Installing Git..." -ForegroundColor Cyan
        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    }
}
else {
    Write-Host "Git is already installed: $(git --version)" -ForegroundColor DarkGray
}

# Create Git config directory in user profile
New-Directory -Path "$HOME\.config\git" -DryRun:$DryRun

# Create softlinks for Git configuration files
Set-Softlink -Path "$HOME\.config\git\config" -Target (Join-Path $PSScriptRoot "config") -DryRun:$DryRun
Set-Softlink -Path "$HOME\.config\git\.gitignore" -Target (Join-Path $PSScriptRoot ".gitignore") -DryRun:$DryRun
Set-Softlink -Path "$HOME\.config\git\.gitattributes" -Target (Join-Path $PSScriptRoot ".gitattributes") -DryRun:$DryRun
Set-Softlink -Path "$HOME\.config\git\.gitmessage" -Target (Join-Path $PSScriptRoot ".gitmessage") -DryRun:$DryRun

# Link system-wide gitconfig if Git program directory exists
$systemGitConfig = "$env:programfiles\Git\etc\gitconfig"
if (Test-Path (Split-Path $systemGitConfig -Parent)) {
    Set-Softlink -Path $systemGitConfig -Target (Join-Path $PSScriptRoot "gitconfig") -DryRun:$DryRun
}
