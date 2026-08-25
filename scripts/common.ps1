#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helper functions and utilities for windots setup and uninstall scripts.
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

function Remove-Softlink {
    <#
    .SYNOPSIS
        Safely removes a symbolic link and restores any .old backup file if present.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,
        [switch]$DryRun
    )

    PROCESS {
        if (Test-Path -Path $Path) {
            $item = Get-Item -Path $Path -Force
            $isSymlink = ($item.LinkType -eq "SymbolicLink") -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)

            if ($isSymlink) {
                if ($DryRun) {
                    Write-Host "[DryRun] Would remove softlink: $Path" -ForegroundColor DarkCyan
                }
                elseif ($PSCmdlet.ShouldProcess($Path, "Remove Softlink")) {
                    Remove-Item -Path $Path -Force
                    Write-Host "Removed softlink: $Path" -ForegroundColor Yellow
                }
            }
            else {
                Write-Verbose "Remove-Softlink: $Path is not a symbolic link, skipping."
            }
        }

        # Check for .old backup to restore
        $backupPath = "$Path.old"
        if (Test-Path -Path $backupPath) {
            if ($DryRun) {
                Write-Host "[DryRun] Would restore backup $backupPath -> $Path" -ForegroundColor DarkCyan
            }
            elseif ($PSCmdlet.ShouldProcess($backupPath, "Restore to $Path")) {
                Move-Item -Path $backupPath -Destination $Path -Force
                Write-Host "Restored backup: $backupPath -> $Path" -ForegroundColor Green
            }
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
            $foundMatches = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.DisplayName -like "*$ProgramName*" -or
                    $_.PSChildName -like "*$ProgramName*"
                }
            if ($foundMatches) {
                return $true
            }
        }
    }

    return $false
}

function Ensure-Micromamba {
    <#
    .SYNOPSIS
        Ensures Micromamba executable is available and in PATH.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [switch]$DryRun
    )

    if (Get-Command micromamba -ErrorAction SilentlyContinue) {
        return (Get-Command micromamba).Source
    }

    $candidatePaths = @(
        "$HOME\.local\bin\micromamba.exe",
        "$HOME\micromamba\bin\micromamba.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\micromamba.exe",
        "$env:LOCALAPPDATA\micromamba\micromamba.exe",
        "C:\Program Files\micromamba\micromamba.exe"
    )

    foreach ($cand in $candidatePaths) {
        if (Test-Path $cand) {
            $binDir = Split-Path -Path $cand -Parent
            if ($env:PATH -notlike "*$binDir*") {
                $env:PATH = "$env:PATH;$binDir"
            }
            return $cand
        }
    }

    if ($DryRun) {
        Write-Host "[DryRun] Would download standalone Micromamba binary to $HOME\.local\bin\micromamba.exe" -ForegroundColor DarkCyan
        return "$HOME\.local\bin\micromamba.exe"
    }

    if ($PSCmdlet.ShouldProcess("Micromamba", "Download standalone binary")) {
        Write-Host "Bootstrapping standalone Micromamba..." -ForegroundColor Cyan
        $mambaBinDir = "$HOME\.local\bin"
        New-Directory -Path $mambaBinDir
        $targetExe = "$mambaBinDir\micromamba.exe"
        $downloadUrl = "https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-win-64.exe"

        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $targetExe -UseBasicParsing
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$mambaBinDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$userPath;$mambaBinDir", "User")
            }
            if ($env:PATH -notlike "*$mambaBinDir*") {
                $env:PATH = "$env:PATH;$mambaBinDir"
            }
            return $targetExe
        }
        catch {
            Write-Warning "Could not bootstrap standalone Micromamba: $_"
            return $null
        }
    }
    return $null
}

function Install-MambaPackage {
    <#
    .SYNOPSIS
        Installs a package via Micromamba from conda-forge.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName,
        [string]$CommandCheck,
        [string]$Environment = "base",
        [switch]$DryRun
    )

    if ($CommandCheck -and (Get-Command $CommandCheck -ErrorAction SilentlyContinue)) {
        Write-Host "$PackageName is already installed." -ForegroundColor DarkGray
        return $true
    }

    $mambaExe = Ensure-Micromamba -DryRun:$DryRun
    if (-not $mambaExe) {
        Write-Warning "Micromamba is not available to install '$PackageName'."
        return $false
    }

    if ($DryRun) {
        Write-Host "[DryRun] Would install $PackageName via Micromamba (env: $Environment, channel: conda-forge)" -ForegroundColor DarkCyan
        return $true
    }

    if ($PSCmdlet.ShouldProcess($PackageName, "Install via Micromamba")) {
        Write-Host "Installing $PackageName via Micromamba (env: $Environment)..." -ForegroundColor Cyan
        try {
            & $mambaExe install -n $Environment -c conda-forge $PackageName -y
            return $true
        }
        catch {
            Write-Warning "Micromamba installation of '$PackageName' failed: $_"
            return $false
        }
    }

    return $false
}
