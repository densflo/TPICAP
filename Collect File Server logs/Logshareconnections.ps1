# PowerShell Script: LogNewServerConnections.ps1

# Log file path (with date)
$logFile = "C:\logs\$(Get-Date -Format 'yyyy-MM-dd').csv"

# Create log directory if it doesn't exist
if (-not (Test-Path -Path "C:\logs" -PathType Container)) {
    New-Item -Path "C:\logs" -ItemType Directory | Out-Null
}

# Function to get share path (more robust than relying on Win32_Share)
function Get-SharePath {
    param([string]$ShareName)
    try {
        (Get-SmbShare -Name $ShareName).Path
    }
    catch {
        Write-Warning "Could not resolve path for share '$ShareName': $_"
        return "" # Or some other indicator like "Unknown"
    }
}

# Function to resolve IP to FQDN
function Get-FqdnFromIp {
    param([string]$ipAddress)
    try {
        [System.Net.Dns]::GetHostByAddress($ipAddress).HostName
    }
    catch {
        Write-Warning "Could not resolve FQDN for IP '$ipAddress': $_"
        return $ipAddress # Return IP if resolution fails 
    }
}

# Get current connections with simplified properties, share path, resolved FQDN, and timestamp
$currentConnections = Get-CimInstance -ClassName Win32_ServerConnection | ForEach-Object {
    $fqdn = Get-FqdnFromIp $_.ComputerName
    [PSCustomObject]@{
        ComputerName = $fqdn 
        ShareName    = $_.ShareName
        SharePath    = Get-SharePath $_.ShareName
        UserName     = $_.UserName
        ConnectionID = $_.ConnectionID
        Timestamp    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss' 
    }
}


# Load existing logged connections (if the file exists)
if (Test-Path $logFile) {
    $loggedConnections = Import-Csv -Path $logFile
} else {
    # Create the log file with headers if it doesn't exist
    $currentConnections | Select-Object * | Export-Csv -Path $logFile -NoTypeInformation
    $loggedConnections = @() 
}


# Compare and log new connections (using Compare-Object for efficiency)
$newConnections = Compare-Object -ReferenceObject $loggedConnections -DifferenceObject $currentConnections -Property ComputerName, ShareName, UserName, ConnectionID -PassThru | Where-Object {$_.SideIndicator -eq "=>"}

if ($newConnections) {
    $newConnections | Export-Csv -Path $logFile -Append -NoTypeInformation
}
