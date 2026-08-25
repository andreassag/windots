# PowerShell Profile (Compatible with Windows PowerShell 5.1 and PowerShell 7+)

# =============================================================================
# PSReadLine Configuration
# =============================================================================
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

    # Key handlers
    Set-PSReadLineKeyHandler -Key Tab -Function Complete -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteChar -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo -ErrorAction SilentlyContinue

    # Predictive IntelliSense (supported in PSReadLine 2.2.0+ in interactive consoles)
    $setOptionCmd = Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue
    $isRedirected = try { [Console]::IsOutputRedirected } catch { $false }
    if ($setOptionCmd -and $setOptionCmd.Parameters.ContainsKey('PredictionSource') -and -not $isRedirected) {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction SilentlyContinue
        if ($setOptionCmd.Parameters.ContainsKey('PredictionViewStyle')) {
            Set-PSReadLineOption -PredictionViewStyle InlineView -ErrorAction SilentlyContinue
        }
    }

    # Universal syntax highlight colors (ConsoleColor names compatible with all PS versions)
    $colorTable = @{
        Command          = "Cyan"
        Parameter        = "DarkGray"
        Operator         = "DarkYellow"
        Variable         = "Green"
        String           = "Magenta"
        Number           = "Blue"
        Type             = "White"
        Comment          = "DarkGray"
    }
    if ($setOptionCmd -and $setOptionCmd.Parameters.ContainsKey('PredictionSource')) {
        $colorTable["InlinePrediction"] = "DarkGray"
    }
    Set-PSReadLineOption -Colors $colorTable -ErrorAction SilentlyContinue
}

# =============================================================================
# Terminal Icons
# =============================================================================
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}

# =============================================================================
# Micromamba / Mamba Integration
# =============================================================================
$mambaCandidates = @(
    (Get-Command micromamba -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    "$HOME\.local\bin\micromamba.exe",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links\micromamba.exe",
    "$HOME\micromamba\micromamba.exe",
    "$env:LOCALAPPDATA\micromamba\micromamba.exe",
    "C:\Program Files\micromamba\micromamba.exe"
)

$mambaExe = $null
foreach ($cand in $mambaCandidates) {
    if ($cand -and (Test-Path $cand)) {
        $mambaExe = $cand
        $binDir = Split-Path -Path $cand -Parent
        if ($env:PATH -notlike "*$binDir*") {
            $env:PATH = "$env:PATH;$binDir"
        }
        break
    }
}

if ($mambaExe) {
    try {
        $mambaHook = (& $mambaExe shell hook -s powershell 2>$null)
        if ($mambaHook) {
            $mambaHook | Out-String | Invoke-Expression
        }
    }
    catch {
        Set-Alias -Name micromamba -Value $mambaExe -Option AllScope -ErrorAction SilentlyContinue
    }

    if (-not (Get-Command mamba -ErrorAction SilentlyContinue)) {
        Set-Alias -Name mamba -Value micromamba -Option AllScope -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# Oh-My-Posh Prompt
# =============================================================================
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $poshShell = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh" } else { "powershell" }
    $themeConfig = if ($env:POSH_THEMES_PATH -and (Test-Path "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json")) {
        "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json"
    }
    else {
        "jandedobbeleer"
    }

    try {
        oh-my-posh init $poshShell --config $themeConfig | Invoke-Expression
    }
    catch {
        # Silently continue if oh-my-posh cannot hook console
    }
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
