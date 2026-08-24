# PowerShell Profile

# =============================================================================
# PSReadLine Configuration
# =============================================================================
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine

    # Enable Predictive IntelliSense from command history
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionViewStyle InlineView -ErrorAction SilentlyContinue

    # Key handlers
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteChar
    Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo

    # Colors
    Set-PSReadLineOption -Colors @{
        Command            = "`e[36m"
        Parameter          = "`e[90m"
        Operator           = "`e[33m"
        Variable           = "`e[32m"
        String             = "`e[35m"
        Number             = "`e[94m"
        Type               = "`e[37m"
        Comment            = "`e[90m"
        InlinePrediction   = "`e[90m"
    } -ErrorAction SilentlyContinue
}

# =============================================================================
# Terminal Icons
# =============================================================================
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# =============================================================================
# Oh-My-Posh Prompt
# =============================================================================
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # Initialize oh-my-posh prompt
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
}

# =============================================================================
# Aliases & Functions
# =============================================================================
# Git shorthand
Set-Alias -Name g -Value git -Option AllScope -ErrorAction SilentlyContinue

# Unix-like shortcuts
function which ($name) {
    Get-Command $name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

function touch ($file) {
    if (Test-Path $file) {
        (Get-Item $file).LastWriteTime = Get-Date
    }
    else {
        New-Item -ItemType File -Path $file | Out-Null
    }
}

function ll {
    Get-ChildItem -Path . | Format-Table Mode, Length, LastWriteTime, Name
}

function la {
    Get-ChildItem -Path . -Force | Format-Table Mode, Length, LastWriteTime, Name
}

function reload-profile {
    & $PROFILE
}

function admin {
    Start-Process powershell -Verb RunAs
}
