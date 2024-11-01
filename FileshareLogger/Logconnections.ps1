# PowerShell Script: LogNewServerConnections.ps1

# Log file path (with date)
$logFile = Join-Path "C:\logs" "$(Get-Date -Format 'yyyy-MM-dd').csv"

# Create log directory if it doesn't exist
if (-not (Test-Path -Path "C:\logs" -PathType Container)) {
    New-Item -Path "C:\logs" -ItemType Directory -Force | Out-Null
}

# Function to get the share path using Get-SmbShare
function Get-SharePath {
    param([string]$ShareName)
    try {
        (Get-SmbShare -Name $ShareName -ErrorAction Stop).Path
    } catch {
        Write-Warning "Could not resolve path for share '$ShareName': $_"
        return "Unknown"
    }
}

# Function to resolve an IP address to an FQDN
function Get-FqdnFromIP {
    param([string]$IPAddress)
    $dnsServer = "LDN1WS0060.corp.ad.tullib.com"

    try {
        $hostInfo = Resolve-DnsName -Name $IPAddress -Type PTR -Server $dnsServer -ErrorAction Stop
        return $hostInfo.NameHost
    } catch {
        Write-Warning "Could not resolve FQDN for IP '$IPAddress': $_"
        return $IPAddress
    }
}

# Get current connections with enhanced properties
$currentConnections = Get-CimInstance -ClassName Win32_ServerConnection | ForEach-Object {
    [PSCustomObject]@{
        ComputerName = Get-FqdnFromIP $_.ComputerName
        ShareName    = $_.ShareName
        SharePath    = Get-SharePath $_.ShareName
        UserName     = $_.UserName
        ConnectionID = $_.ConnectionID
        Timestamp    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
}

# Load existing logged connections or create new log file
if (Test-Path $logFile) {
    $loggedConnections = Import-Csv -Path $logFile
} else {
    $currentConnections | Export-Csv -Path $logFile -NoTypeInformation
    $loggedConnections = @()
}

# Determine new connections efficiently
$newConnections = Compare-Object -ReferenceObject $loggedConnections -DifferenceObject $currentConnections -Property ComputerName, ShareName, UserName, ConnectionID -PassThru | 
    Where-Object {$_.SideIndicator -eq "=>"}

# Append new connections to the log file
if ($newConnections) {
    $newConnections | Export-Csv -Path $logFile -Append -NoTypeInformation
    Write-Host "Logged $($newConnections.Count) new connections."
} else {
    Write-Host "No new connections to log."
}
