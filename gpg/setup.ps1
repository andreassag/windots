#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and configures GnuPG on Windows.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# Install GnuPG via Micromamba (or fallback to winget) if not present
if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
    $installed = Install-MambaPackage -PackageName "gnupg" -CommandCheck "gpg" -DryRun:$DryRun
    if (-not $installed -and -not $DryRun) {
        if ($PSCmdlet.ShouldProcess("GnuPG", "Install via winget")) {
            Write-Host "Falling back to winget for GnuPG..." -ForegroundColor Cyan
            winget install --id GnuPG.GnuPG -e --source winget --accept-source-agreements --accept-package-agreements
        }
    }
}
else {
    Write-Host "GnuPG is already installed." -ForegroundColor DarkGray
}

# Create GnuPG directories in user profile
New-Directory -Path "$HOME\.gpg" -Hide -DryRun:$DryRun
New-Directory -Path "$HOME\.gnupg" -Hide -DryRun:$DryRun

# Create softlinks for GnuPG configuration
Set-Softlink -Path "$HOME\.gnupg\gpg.conf" -Target (Join-Path $PSScriptRoot "gpg.conf") -DryRun:$DryRun
Set-Softlink -Path "$HOME\.gnupg\common.conf" -Target (Join-Path $PSScriptRoot "common.conf") -DryRun:$DryRun
