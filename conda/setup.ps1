#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Miniconda and links .condarc configuration.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# Install Miniconda via winget if not present
if (-not (Get-Command conda -ErrorAction SilentlyContinue)) {
    if ($DryRun) {
        Write-Host "[DryRun] Would install Miniconda via winget" -ForegroundColor DarkCyan
    }
    elseif ($PSCmdlet.ShouldProcess("Miniconda", "Install via winget")) {
        Write-Host "Installing Miniconda..." -ForegroundColor Cyan
        winget install --id Anaconda.Miniconda3 -e --source winget --accept-source-agreements --accept-package-agreements
    }
}
else {
    Write-Host "Conda is already installed." -ForegroundColor DarkGray
}

# Create softlink to .condarc and hide it
$condarcPath = Join-Path -Path $PSScriptRoot -ChildPath ".condarc"
Set-Softlink -Path "$HOME\.condarc" -Target $condarcPath -Hide -DryRun:$DryRun
