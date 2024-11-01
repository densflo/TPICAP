#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Implements protection against CVE-2018-3639 - Speculative Store Bypass (Spectre Variant 4)
.DESCRIPTION
    Addresses Microsoft Windows Security Update Registry Key Configuration Missing (ADV180012) by implementing
    required registry keys based on processor type. This script specifically mitigates CVE-2018-3639,
    also known as Speculative Store Bypass (SSB) or Spectre Variant 4.

    This vulnerability allows an attacker to read privileged data across trust boundaries through
    speculative execution side channels. The script implements the registry mitigations required
    by Microsoft's ADV180012 advisory.

.NOTES
    Filename: Protect-SpectreMeltdownV4.ps1
    Author: Cline
    Requires: PowerShell running as Administrator
    Qualys QID: 91462
    CVE: CVE-2018-3639
    CVSS Score: 5.6 MEDIUM
    Microsoft Advisory: ADV180012
    Vulnerability: Speculative Store Bypass (Spectre Variant 4)
    Release Date: May 21, 2018
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Initialize logging
$LogPath = Join-Path $env:TEMP "SpectreMeltdownV4_Protection.log"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-Log {
    param($Message)
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
    Write-Host $LogMessage
}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ProcessorDetails {
    try {
        $processor = Get-WmiObject -Class Win32_Processor
        $processorId = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Session Manager\Environment").PROCESSOR_IDENTIFIER
        Write-Log "Detected Processor: $processorId"
        
        if ($processor.Manufacturer -match "AMD") {
            return @{
                Type = "AMD"
                Details = $processorId
            }
        }
        elseif ($processor.Manufacturer -match "Intel") {
            return @{
                Type = "Intel"
                Details = $processorId
            }
        }
        else {
            throw "Unknown processor manufacturer: $($processor.Manufacturer)"
        }
    }
    catch {
        throw "Failed to detect processor details: $_"
    }
}

function Set-SpectreMeltdownProtection {
    param (
        [string]$ProcessorType
    )

    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    
    try {
        Write-Log "Implementing CVE-2018-3639 mitigation..."
        
        # Create registry path if it doesn't exist
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            Write-Log "Created registry path: $registryPath"
        }

        # Set FeatureSettingsOverrideMask for all processors
        Set-ItemProperty -Path $registryPath -Name "FeatureSettingsOverrideMask" -Value 3 -Type DWORD
        Write-Log "Set FeatureSettingsOverrideMask = 3"

        # Set processor-specific FeatureSettingsOverride
        switch ($ProcessorType) {
            "AMD" {
                # AMD processors support values 72 or 8
                Set-ItemProperty -Path $registryPath -Name "FeatureSettingsOverride" -Value 72 -Type DWORD
                Write-Log "Set FeatureSettingsOverride = 72 (AMD processor)"
            }
            "Intel" {
                # Non-AMD processors support values 8264, 72, or 8
                Set-ItemProperty -Path $registryPath -Name "FeatureSettingsOverride" -Value 8264 -Type DWORD
                Write-Log "Set FeatureSettingsOverride = 8264 (Intel processor)"
            }
        }
    }
    catch {
        throw "Failed to set registry keys for CVE-2018-3639 mitigation: $_"
    }
}

function Test-Protection {
    param (
        [string]$ProcessorType
    )

    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    
    try {
        if (-not (Test-Path $registryPath)) {
            Write-Log "Registry path does not exist: $registryPath"
            return $false
        }

        $settings = Get-ItemProperty -Path $registryPath -ErrorAction Stop
        
        # Check FeatureSettingsOverrideMask
        if (-not (Get-ItemProperty -Path $registryPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue)) {
            Write-Log "FeatureSettingsOverrideMask is missing"
            return $false
        }
        if ($settings.FeatureSettingsOverrideMask -ne 3) {
            Write-Log "FeatureSettingsOverrideMask value is incorrect: $($settings.FeatureSettingsOverrideMask)"
            return $false
        }

        # Check FeatureSettingsOverride
        if (-not (Get-ItemProperty -Path $registryPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue)) {
            Write-Log "FeatureSettingsOverride is missing"
            return $false
        }

        # Verify processor-specific settings
        switch ($ProcessorType) {
            "AMD" {
                if ($settings.FeatureSettingsOverride -notin @(72, 8)) {
                    Write-Log "Invalid FeatureSettingsOverride value for AMD: $($settings.FeatureSettingsOverride)"
                    return $false
                }
            }
            "Intel" {
                if ($settings.FeatureSettingsOverride -notin @(8264, 72, 8)) {
                    Write-Log "Invalid FeatureSettingsOverride value for Intel: $($settings.FeatureSettingsOverride)"
                    return $false
                }
            }
        }
        return $true
    }
    catch {
        Write-Log "Error verifying CVE-2018-3639 protection: $_"
        return $false
    }
}

# Main execution block
try {
    Write-Log "Starting protection script for CVE-2018-3639 (Spectre Variant 4)"
    Write-Log "This script implements mitigations for the Speculative Store Bypass vulnerability"

    # Check for admin privileges
    if (-not (Test-AdminPrivileges)) {
        throw "This script requires administrator privileges"
    }

    # Detect processor details
    $processorInfo = Get-ProcessorDetails
    Write-Log "Processor Type: $($processorInfo.Type)"
    Write-Log "Processor Details: $($processorInfo.Details)"

    # Check current registry settings
    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if (Test-Path $registryPath) {
        $currentSettings = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
        if ($currentSettings) {
            Write-Log "Current FeatureSettingsOverride: $(if ($currentSettings.FeatureSettingsOverride) { $currentSettings.FeatureSettingsOverride } else { 'missing' })"
            Write-Log "Current FeatureSettingsOverrideMask: $(if ($currentSettings.FeatureSettingsOverrideMask) { $currentSettings.FeatureSettingsOverrideMask } else { 'missing' })"
        }
    }

    # Apply protection
    Set-SpectreMeltdownProtection -ProcessorType $processorInfo.Type
    Write-Log "Applied CVE-2018-3639 protection settings"

    # Verify protection
    if (Test-Protection -ProcessorType $processorInfo.Type) {
        Write-Log "SUCCESS: CVE-2018-3639 mitigation verified successfully"
        Write-Log "System is now protected against Speculative Store Bypass (Spectre Variant 4)"
    }
    else {
        throw "CVE-2018-3639 protection verification failed"
    }
}
catch {
    Write-Log "ERROR: $_"
    throw $_
}
finally {
    Write-Log "Script execution completed"
}
