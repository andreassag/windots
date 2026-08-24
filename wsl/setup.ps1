#Requires -Version 5.1
<#
.SYNOPSIS
    Configures WSL (Windows Subsystem for Linux) and links .wslconfig.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# Create softlink to .wslconfig
$wslConfigFile = Join-Path -Path $PSScriptRoot -ChildPath ".wslconfig"
Set-Softlink -Path "$HOME\.wslconfig" -Target $wslConfigFile -Hide -DryRun:$DryRun

# Enable WSL Optional Feature if not in dry run
if (-not $DryRun) {
    try {
        if (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
            Enable-WindowsOptionalFeature -Online -All -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
        }
    }
    catch {
        Write-Warning "Could not enable Microsoft-Windows-Subsystem-Linux feature: $_"
    }
}
