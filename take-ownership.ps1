[CmdletBinding()]
param(
    [switch]$Confirm = $true,
    [switch]$DryRun
)

# Create log file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "C:\temp\ownership_changes_$timestamp.txt"
New-Item -ItemType Directory -Path "C:\temp" -Force -ErrorAction SilentlyContinue | Out-Null

# Function to write to both console and log file
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value $Message
}

# Get current user and path
$currentUser = $env:USERNAME
$profilePath = "E:\SHARES\UserDir\bcraig"

# Validate profile path
if (-not $profilePath.StartsWith("E:\SHARES\UserDir\")) {
    Write-Log "Error: Script can only process files within E:\SHARES\UserDir\" "Red"
    exit
}

Write-Log "File Ownership Analysis - $(Get-Date)"
Write-Log "User: $currentUser"
Write-Log "Target Folder: $profilePath"
Write-Log "Note: Changes will ONLY affect files within $profilePath"
Write-Log "----------------------------------------"

# Get initial file listing
Write-Log "Initial File Listing:"
Write-Log "----------------------------------------"
Write-Log "Root directory: $profilePath"

try {
    Get-ChildItem -Path $profilePath -Recurse -Force -ErrorAction Stop | 
    Where-Object { 
        # Double-check path is within profile folder and not recyclebin
        $_.FullName.StartsWith($profilePath) -and 
        $_.FullName -notlike "*\`$RECYCLE.BIN*" 
    } | 
    ForEach-Object {
        $indent = "  " * ($_.FullName.Split("\").Count - $profilePath.Split("\").Count)
        $type = if ($_.PSIsContainer) { "DIR" } else { "FILE" }
        Write-Log "$indent[$type] $($_.Name)"
    }
} catch {
    Write-Log "Note: Some items may be inaccessible until ownership is taken" "Yellow"
}

Write-Log "----------------------------------------"

if (-not $DryRun) {
    if ($Confirm) {
        Write-Log "IMPORTANT: Changes will only affect files within: $profilePath"
        $response = Read-Host "Do you want to proceed with taking ownership? (Y/N)"
        if ($response -ne "Y" -and $response -ne "y") {
            Write-Log "Operation cancelled. Log file saved to: $logFile"
            exit
        }
    }

    # Take ownership and grant permissions (restricted to profile path)
    Write-Log "Taking ownership of items within $profilePath..."
    $result = takeown.exe /F $profilePath /R /D Y /SKIPSL
    $result = icacls.exe $profilePath /grant "${currentUser}:(OI)(CI)(F)" /T /C

    # Get updated file listing
    Write-Log "----------------------------------------"
    Write-Log "Updated File Listing After Taking Ownership:"
    Write-Log "----------------------------------------"
    Write-Log "Scope: Only files within $profilePath"
    
    Get-ChildItem -Path $profilePath -Recurse -Force | 
    Where-Object { 
        # Double-check path is within profile folder and not recyclebin
        $_.FullName.StartsWith($profilePath) -and 
        $_.FullName -notlike "*\`$RECYCLE.BIN*" 
    } | 
    ForEach-Object {
        $indent = "  " * ($_.FullName.Split("\").Count - $profilePath.Split("\").Count)
        $type = if ($_.PSIsContainer) { "DIR" } else { "FILE" }
        Write-Log "$indent[$type] $($_.Name)"
    }
}

Write-Log "----------------------------------------"
Write-Log "Operation completed at $(Get-Date)"
Write-Log "Changes were restricted to: $profilePath"
Write-Log "Log file saved to: $logFile"

Write-Host ""
Write-Host "Operation completed. All changes were restricted to: $profilePath" -ForegroundColor Cyan
Write-Host "Log file saved to: $logFile" -ForegroundColor Cyan
