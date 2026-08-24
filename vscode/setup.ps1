#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and configures Visual Studio Code on Windows.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# Install VS Code via winget if not installed
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    if ($DryRun) {
        Write-Host "[DryRun] Would install Visual Studio Code via winget" -ForegroundColor DarkCyan
    }
    elseif ($PSCmdlet.ShouldProcess("Visual Studio Code", "Install via winget")) {
        Write-Host "Installing Visual Studio Code..." -ForegroundColor Cyan
        winget install --id Microsoft.VisualStudioCode -e --source winget --accept-source-agreements --accept-package-agreements
    }
}
else {
    Write-Host "Visual Studio Code is already installed." -ForegroundColor DarkGray
}

# Create softlink for VS Code User settings.json
$vscodeUserDir = "$env:APPDATA\Code\User"
New-Directory -Path $vscodeUserDir -DryRun:$DryRun
Set-Softlink -Path "$vscodeUserDir\settings.json" -Target (Join-Path $PSScriptRoot "settings.json") -DryRun:$DryRun

# Install recommended extensions if code command is available
$extensions = @(
    "ms-vscode-remote.remote-containers",
    "ms-azuretools.vscode-docker",
    "github.codespaces",
    "github.copilot",
    "github.copilot-chat",
    "github.vscode-github-actions",
    "ms-toolsai.jupyter-keymap",
    "ms-vscode.live-server",
    "ms-vscode.powershell",
    "ms-vscode-remote.remote-ssh",
    "ms-vscode-remote.remote-ssh-edit",
    "ms-vscode.remote-explorer",
    "ms-vscode-remote.remote-wsl",
    "gruntfuggly.todo-tree"
)

if (Get-Command code -ErrorAction SilentlyContinue) {
    foreach ($ext in $extensions) {
        if ($DryRun) {
            Write-Host "[DryRun] Would install VS Code extension: $ext" -ForegroundColor DarkCyan
        }
        else {
            Write-Host "Installing extension: $ext" -ForegroundColor DarkGray
            code --install-extension $ext --force | Out-Null
        }
    }
}
