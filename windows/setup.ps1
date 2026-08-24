#Requires -Version 5.1
<#
.SYNOPSIS
    Configures Windows 10/11 system preferences, privacy, explorer, and default applications.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$DryRun,
    [string]$ComputerName
)

# Import shared helper functions if not already loaded
if (-not (Get-Command Set-Softlink -ErrorAction SilentlyContinue)) {
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\common.ps1")
}

# Helper for setting registry values safely
function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$PropertyType = "DWord"
    )

    if (-not (Test-Path $Path)) {
        if ($DryRun) {
            Write-Host "[DryRun] Would create registry key: $Path" -ForegroundColor DarkCyan
        }
        else {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
    }

    if ($DryRun) {
        Write-Host "[DryRun] Would set $Path -> $Name = $Value" -ForegroundColor DarkCyan
    }
    else {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $PropertyType -Force -ErrorAction SilentlyContinue
    }
}

# Optional: Set Computer Name if specified
if ($ComputerName) {
    if ($DryRun) {
        Write-Host "[DryRun] Would rename computer to: $ComputerName" -ForegroundColor DarkCyan
    }
    elseif ($PSCmdlet.ShouldProcess($ComputerName, "Rename Computer")) {
        Write-Host "Renaming computer to: $ComputerName..." -ForegroundColor Cyan
        Rename-Computer -NewName $ComputerName -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Configuring Privacy..." -ForegroundColor "Yellow"

# Advertising ID
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
if (-not $DryRun) {
    Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Id" -ErrorAction SilentlyContinue
}

# Disable Application launch tracking
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start-TrackProgs" 0

# Enable SmartScreen Filter
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" "EnableWebContentEvaluation" 1

# Disable key logging & transmission to Microsoft
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Input\TIPC" "Enabled" 0

# Opt-out from websites from accessing language list
Set-RegistryValue "HKCU:\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 1

# Disable suggested content in settings app
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338393Enabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338394Enabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338396Enabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0

# Speech, Inking, & Typing: Stop "Getting to know me"
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 0

# App Permissions: Deny access to sensitive capabilities
$capabilities = @(
    "userAccountInformation",
    "contacts",
    "appointments",
    "appDiagnostics",
    "documentsLibrary",
    "email",
    "broadFileSystemAccess",
    "location",
    "picturesLibrary",
    "userDataTasks",
    "videosLibrary"
)

foreach ($cap in $capabilities) {
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$cap" "Value" "Deny" -PropertyType "String"
}

# Disable feedback frequency
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0

# Diagnostic data collection (Basic: 1)
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 1

Write-Host "Configuring Devices, Power, and Startup..." -ForegroundColor "Yellow"

# Disable Startup Sound
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "DisableStartupSound" 1
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation" "DisableStartupSound" 1

# Disable SuperFetch
Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0

Write-Host "Configuring Explorer, Taskbar, and System Tray..." -ForegroundColor "Yellow"

# Show file extensions by default
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0

# Avoid creating Thumbs.db files on network volumes
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "DisableThumbnailsOnNetworkFolders" 1

# Disable Bing Search in Start Menu
Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0

Write-Host "Configuring Default Windows Applications..." -ForegroundColor "Yellow"

# List of bloatware packages to remove
$bloatPackages = @(
    "Microsoft.3DBuilder",
    "Microsoft.WindowsAlarms",
    "Microsoft.BingFinance",
    "Microsoft.BingNews",
    "Microsoft.BingSports",
    "Microsoft.BingWeather",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.GetStarted"
)

foreach ($pkg in $bloatPackages) {
    if ($DryRun) {
        Write-Host "[DryRun] Would remove AppX package: $pkg" -ForegroundColor DarkCyan
    }
    else {
        Get-AppxPackage -Name $pkg -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppXProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pkg } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}

# Prevent suggested applications from returning
Set-RegistryValue "HKLM:\Software\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1

Write-Host "Configuring Windows Update..." -ForegroundColor "Yellow"

Set-RegistryValue "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 0
Set-RegistryValue "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" "NoAutoRebootWithLoggedOnUsers" 1
Set-RegistryValue "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoRebootWithLoggedOnUsers" 1
Set-RegistryValue "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 3
Set-RegistryValue "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" "IncludeRecommendedUpdates" 1

# Delivery Optimization: HTTP Only (0)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0
Set-RegistryValue "HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0

Write-Host "Configuring Windows Defender..." -ForegroundColor "Yellow"
if (-not $DryRun) {
    Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
    Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
}

Write-Host "Configuring Disk Cleanup..." -ForegroundColor "Yellow"
$diskCleanupRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$cleanupEnabledKeys = @(
    "Downloaded Program Files",
    "Internet Cache Files",
    "Old ChkDsk Files",
    "RetailDemo Offline Content",
    "Setup Log Files",
    "Temporary Files",
    "Temporary Setup Files",
    "Thumbnail Cache",
    "Update Cleanup",
    "Windows Defender"
)

foreach ($key in $cleanupEnabledKeys) {
    Set-RegistryValue "$diskCleanupRegPath\$key" "StateFlags6174" 2
}
