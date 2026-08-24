#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and configures Microsoft PowerToys on Windows.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# Install PowerToys via winget if not present
if (-not (Find-Installed "PowerToys")) {
    if ($DryRun) {
        Write-Host "[DryRun] Would install PowerToys via winget" -ForegroundColor DarkCyan
    }
    elseif ($PSCmdlet.ShouldProcess("PowerToys", "Install via winget")) {
        Write-Host "Installing PowerToys..." -ForegroundColor Cyan
        winget install --id Microsoft.PowerToys -e --source winget --accept-source-agreements --accept-package-agreements
    }
}
else {
    Write-Host "PowerToys is already installed." -ForegroundColor DarkGray
}
