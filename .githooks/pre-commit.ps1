#Requires -Version 5.1
<#
.SYNOPSIS
    Pre-commit verification hook for windots repository.
.DESCRIPTION
    Validates PowerShell AST syntax, JSON formatting, PSScriptAnalyzer rules,
    and symlink target existence prior to git commit.
#>
param ()

$ErrorActionPreference = "Stop"
$hasErrors = $false
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host "`n[pre-commit] Starting repository validation..." -ForegroundColor Cyan

# 1. Validate PowerShell syntax with AST Parser
Write-Host "`n[1/4] Checking PowerShell syntax..." -ForegroundColor Yellow
$psFiles = Get-ChildItem -Path $repoRoot -Include *.ps1, *.psm1, *.psd1 -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\(\.git|vendor|node_modules)\\' }

foreach ($file in $psFiles) {
    $tokens = $null
    $errors = $null
    $content = Get-Content -Path $file.FullName -Raw
    [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors) | Out-Null

    if ($errors.Count -gt 0) {
        $hasErrors = $true
        Write-Host "  [FAIL] $($file.FullName.Replace($repoRoot, ''))" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "    Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  [OK] $($file.FullName.Replace($repoRoot, ''))" -ForegroundColor DarkGreen
    }
}

# 2. Validate JSON files
Write-Host "`n[2/4] Validating JSON files..." -ForegroundColor Yellow
$jsonFiles = Get-ChildItem -Path $repoRoot -Include *.json -Recurse -File |
    Where-Object { $_.FullName -notmatch '\\(\.git|vendor|node_modules)\\' }

foreach ($file in $jsonFiles) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $null = ConvertFrom-Json -InputObject $content -ErrorAction Stop
        Write-Host "  [OK] $($file.FullName.Replace($repoRoot, ''))" -ForegroundColor DarkGreen
    }
    catch {
        $hasErrors = $true
        Write-Host "  [FAIL] $($file.FullName.Replace($repoRoot, ''))" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 3. Verify Softlink targets exist in repository
Write-Host "`n[3/4] Checking softlink targets integrity..." -ForegroundColor Yellow
$setupScripts = Get-ChildItem -Path $repoRoot -Filter "setup.ps1" -Recurse -File

foreach ($setupScript in $setupScripts) {
    $content = Get-Content -Path $setupScript.FullName
    $dir = $setupScript.DirectoryName

    # Find Set-Softlink calls with Join-Path $PSScriptRoot "<file>"
    $matches = [regex]::Matches($content, 'Join-Path\s+\$PSScriptRoot\s+["'']([^"'']+)["'']')
    foreach ($m in $matches) {
        $relTarget = $m.Groups[1].Value
        $targetPath = Join-Path $dir $relTarget
        if (-not (Test-Path $targetPath)) {
            $hasErrors = $true
            Write-Host "  [FAIL] Missing softlink target in $($setupScript.FullName.Replace($repoRoot, '')) -> '$relTarget'" -ForegroundColor Red
        }
    }
}
if (-not $hasErrors) {
    Write-Host "  [OK] All referenced softlink targets exist." -ForegroundColor DarkGreen
}

# 4. Run PSScriptAnalyzer (if available)
Write-Host "`n[4/4] Checking PSScriptAnalyzer..." -ForegroundColor Yellow
if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
    Import-Module PSScriptAnalyzer
    $analysisErrors = Invoke-ScriptAnalyzer -Path $repoRoot -Recurse -Severity Error
    if ($analysisErrors.Count -gt 0) {
        $hasErrors = $true
        Write-Host "  [FAIL] PSScriptAnalyzer reported errors:" -ForegroundColor Red
        $analysisErrors | Format-Table ScriptName, Line, Message -AutoSize
    }
    else {
        Write-Host "  [OK] PSScriptAnalyzer found no critical errors." -ForegroundColor DarkGreen
    }
}
else {
    Write-Host "  [SKIP] PSScriptAnalyzer module not installed in current session." -ForegroundColor DarkGray
}

Write-Host ""
if ($hasErrors) {
    Write-Host "[pre-commit] FAILED. Please resolve errors before committing." -ForegroundColor Red
    exit 1
}
else {
    Write-Host "[pre-commit] SUCCESS. All pre-commit checks passed!" -ForegroundColor Green
    exit 0
}
