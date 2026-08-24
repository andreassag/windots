#Requires -Version 5.1
<#
.SYNOPSIS
    Automates approving and enabling auto-merge for Dependabot PRs via GitHub CLI.
.PARAMETER MergeMethod
    Merge method to use. Defaults to squash.
.PARAMETER DryRun
    Simulates actions without approving or merging PRs.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [ValidateSet("squash", "rebase", "merge")]
    [string]$MergeMethod = "squash",
    [switch]$DryRun
)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI ('gh') is required but not installed or not in PATH."
}

Write-Host "Fetching open Dependabot PRs..." -ForegroundColor Cyan

try {
    $prsJson = gh pr list --app dependabot --json number,title,url,headRefName,isDraft 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $prsJson) {
        Write-Host "No open Dependabot PRs found or failed to query GitHub CLI." -ForegroundColor DarkGray
        return
    }

    $prs = $prsJson | ConvertFrom-Json
    if (-not $prs -or $prs.Count -eq 0) {
        Write-Host "No open Dependabot pull requests found." -ForegroundColor Green
        return
    }

    foreach ($pr in $prs) {
        Write-Host "`nFound PR #$($pr.number): $($pr.title)" -ForegroundColor Yellow
        Write-Host "URL: $($pr.url)" -ForegroundColor DarkGray

        if ($pr.isDraft) {
            Write-Host "Skipping PR #$($pr.number) (Draft)." -ForegroundColor DarkGray
            continue
        }

        if ($DryRun) {
            Write-Host "[DryRun] Would approve and enable auto-merge ($MergeMethod) for PR #$($pr.number)" -ForegroundColor DarkCyan
        }
        else {
            Write-Host "Approving PR #$($pr.number)..." -ForegroundColor Cyan
            gh pr review --approve $pr.url

            Write-Host "Enabling auto-merge ($MergeMethod) for PR #$($pr.number)..." -ForegroundColor Cyan
            gh pr merge --auto --$MergeMethod $pr.url
        }
    }

    Write-Host "`nAutomerge processing finished." -ForegroundColor Green
}
catch {
    Write-Error "Error during automerge execution: $_"
}
