#Requires -Version 5.1
<#
.SYNOPSIS
    Configures Windows Terminal settings and profiles.
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

# Target paths for Windows Terminal (Stable and Preview)
$terminalPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"
)

foreach ($termDir in $terminalPaths) {
    # If the parent package directory exists (or in dry run), link settings
    $packageDir = Split-Path -Path $termDir -Parent
    if (Test-Path $packageDir) {
        New-Directory -Path $termDir -DryRun:$DryRun
        Set-Softlink -Path (Join-Path $termDir "settings.json") -Target $sourceSettings -DryRun:$DryRun
    }
    elseif ($DryRun) {
        Write-Host "[DryRun] Would configure Windows Terminal settings at $termDir\settings.json if package is installed" -ForegroundColor DarkCyan
    }
}
