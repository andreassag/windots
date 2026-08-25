#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and configures Micromamba, provisions the 'R' environment with Radian,
    and integrates with Rdots dotfiles.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# 1. Ensure Micromamba is installed and available
$mambaExe = Ensure-Micromamba -DryRun:$DryRun

# 2. Link Micromamba / Conda configurations
$mambarcSource = Join-Path -Path $PSScriptRoot -ChildPath ".mambarc"
Set-Softlink -Path "$HOME\.mambarc" -Target $mambarcSource -Hide -DryRun:$DryRun
Set-Softlink -Path "$HOME\.condarc" -Target $mambarcSource -Hide -DryRun:$DryRun

# 3. Create or verify the 'R' environment with r-base and radian
$hasMamba = (Get-Command micromamba -ErrorAction SilentlyContinue) -ne $null
if ($DryRun) {
    Write-Host "[DryRun] Would create/ensure Micromamba environment 'R' with r-base and radian" -ForegroundColor DarkCyan
}
elseif ($hasMamba) {
    Write-Host "Checking Micromamba 'R' environment..." -ForegroundColor Cyan
    $envList = micromamba env list 2>&1
    if ($envList -notmatch "(?m)^R\s+") {
        Write-Host "Creating Micromamba environment 'R' (latest r-base + radian)..." -ForegroundColor Cyan
        micromamba create -n R -c conda-forge r-base radian -y
    }
    else {
        Write-Host "Micromamba environment 'R' already exists." -ForegroundColor DarkGray
    }
}

# 4. Integrate Rdots (https://github.com/andreassag/rdots)
$rdotsCandidates = @(
    (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "..\rdots"),
    (Join-Path -Path $HOME -ChildPath "repo\rdots")
)

$rdotsDir = $null
foreach ($candidate in $rdotsCandidates) {
    if (Test-Path $candidate) {
        $rdotsDir = (Resolve-Path $candidate).Path
        break
    }
}

if (-not $rdotsDir) {
    $rdotsDir = Join-Path -Path $HOME -ChildPath "repo\rdots"
    if ($DryRun) {
        Write-Host "[DryRun] Would clone https://github.com/andreassag/rdots.git to $rdotsDir" -ForegroundColor DarkCyan
    }
    elseif (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "Cloning Rdots repository..." -ForegroundColor Cyan
        git clone https://github.com/andreassag/rdots.git $rdotsDir
    }
}

if (Test-Path $rdotsDir) {
    Write-Host "Configuring Rdots integration from '$rdotsDir'..." -ForegroundColor Cyan

    # Ensure R config directories exist
    New-Directory -Path "$HOME\.config\R" -DryRun:$DryRun
    New-Directory -Path "$HOME\.vscode-R" -Hide -DryRun:$DryRun

    # Softlink .Rprofile
    $rprofileAsset = Join-Path -Path $rdotsDir -ChildPath "assets\.Rprofile"
    if (Test-Path $rprofileAsset) {
        Set-Softlink -Path "$HOME\.config\R\.Rprofile" -Target $rprofileAsset -DryRun:$DryRun
        Set-Softlink -Path "$HOME\.Rprofile" -Target $rprofileAsset -Hide -DryRun:$DryRun

        if (-not $DryRun) {
            [Environment]::SetEnvironmentVariable("R_PROFILE_USER", "$HOME\.config\R\.Rprofile", "User")
        }
    }

    # Install Rdots user packages if R environment is available
    $rdotsScript = Join-Path -Path $rdotsDir -ChildPath "utils\script.R"
    $rdotsAssets = Join-Path -Path $rdotsDir -ChildPath "assets"
    if ((Test-Path $rdotsScript) -and $hasMamba -and (-not $DryRun)) {
        Write-Host "Installing standard R user packages via Micromamba R environment..." -ForegroundColor Cyan
        micromamba run -n R Rscript "$rdotsScript" "$rdotsAssets"
    }
}
