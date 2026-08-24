#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helper functions and utilities for windots setup scripts.
#>

function Test-Admin {
    <#
    .SYNOPSIS
        Checks if the current PowerShell session has Administrative privileges.
    #>
    [CmdletBinding()]
    param ()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Hide-File {
    <#
    .SYNOPSIS
        Applies the Hidden file attribute to a given file or folder.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,
        [switch]$DryRun
    )

    PROCESS {
        if (-not (Test-Path -Path $Path)) {
            Write-Verbose "Hide-File: Path '$Path' does not exist."
            return
        }

        $item = Get-Item -Path $Path -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::Hidden) -eq 0) {
            if ($DryRun) {
                Write-Host "[DryRun] Would set Hidden attribute on: $Path" -ForegroundColor DarkCyan
            }
            elseif ($PSCmdlet.ShouldProcess($Path, "Set Hidden attribute")) {
                $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
                Write-Verbose "Set Hidden attribute on $Path"
            }
        }
    }
}

function New-Directory {
    <#
    .SYNOPSIS
        Creates a directory if it does not already exist.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,
        [switch]$Hide,
        [switch]$DryRun
    )

    PROCESS {
        if (-not (Test-Path -Path $Path)) {
            if ($DryRun) {
                Write-Host "[DryRun] Would create directory: $Path" -ForegroundColor DarkCyan
            }
            elseif ($PSCmdlet.ShouldProcess($Path, "Create Directory")) {
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
                Write-Host "Created directory: $Path" -ForegroundColor Cyan
            }
        }

        if ($Hide) {
            Hide-File -Path $Path -DryRun:$DryRun
        }
    }
}

function Set-Softlink {
    <#
    .SYNOPSIS
        Creates a symbolic link at Path pointing to Target.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [switch]$Hide,
        [switch]$DryRun
    )

    PROCESS {
        # Ensure target file exists
        if (-not (Test-Path -Path $Target)) {
            Write-Warning "Set-Softlink: Target '$Target' does not exist. Softlink at '$Path' may be broken."
        }

        # Ensure parent directory exists for Path
        $parentDir = Split-Path -Path $Path -Parent
        if ($parentDir -and (-not (Test-Path -Path $parentDir))) {
            New-Directory -Path $parentDir -DryRun:$DryRun
        }

        if (Test-Path -Path $Path) {
            $existingItem = Get-Item -Path $Path -Force
            $isSymlink = ($existingItem.LinkType -eq "SymbolicLink") -or ($existingItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)

            if ($isSymlink) {
                $currentTarget = $existingItem.Target
                if ($currentTarget -eq $Target) {
                    Write-Host "Softlink already up to date: $Path -> $Target" -ForegroundColor DarkGray
                    if ($Hide) { Hide-File -Path $Path -DryRun:$DryRun }
                    return
                }

                if ($DryRun) {
                    Write-Host "[DryRun] Would update softlink: $Path -> $Target (was $currentTarget)" -ForegroundColor DarkCyan
                }
                elseif ($PSCmdlet.ShouldProcess($Path, "Update Softlink target to $Target")) {
                    Remove-Item -Path $Path -Force
                    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
                    Write-Host "Updated softlink: $Path -> $Target" -ForegroundColor Blue
                }
            }
            else {
                $backupPath = "$Path.old"
                if ($DryRun) {
                    Write-Host "[DryRun] Would back up existing non-symlink file to $backupPath and link to $Target" -ForegroundColor DarkCyan
                }
                elseif ($PSCmdlet.ShouldProcess($Path, "Backup to $backupPath and create symlink to $Target")) {
                    Write-Host "Backing up existing file to $backupPath..." -ForegroundColor Yellow
                    Move-Item -Path $Path -Destination $backupPath -Force
                    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
                    Write-Host "Created softlink: $Path -> $Target" -ForegroundColor Blue
                }
            }
        }
        else {
            if ($DryRun) {
                Write-Host "[DryRun] Would create softlink: $Path -> $Target" -ForegroundColor DarkCyan
            }
            elseif ($PSCmdlet.ShouldProcess($Path, "Create Softlink to $Target")) {
                New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
                Write-Host "Created softlink: $Path -> $Target" -ForegroundColor Blue
            }
        }

        if ($Hide) {
            Hide-File -Path $Path -DryRun:$DryRun
        }
    }
}

function Find-Installed {
    <#
    .SYNOPSIS
        Searches uninstall registry keys for an installed application.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProgramName
    )

    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $regPaths) {
        if (Test-Path (Split-Path -Path $path -Parent)) {
            $matches = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.DisplayName -like "*$ProgramName*" -or
                    $_.PSChildName -like "*$ProgramName*"
                }
            if ($matches) {
                return $true
            }
        }
    }

    return $false
}
