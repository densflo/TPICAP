<#
.SYNOPSIS
    Logs and tracks new server connections across network shares.

.DESCRIPTION
    This script captures current server connections, resolves computer names to FQDNs, 
    and logs unique connections to a daily CSV file. It helps track network share usage 
    and user access patterns.

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    .\Logconnections.ps1
    Runs the script and logs new server connections to a daily CSV file.

.LINK
    https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance
#>

# Log file path (with date)
$logFile = Join-Path "C:\logs" "$(Get-Date -Format 'yyyy-MM-dd').csv"

# Create log directory if it doesn't exist
if (-not (Test-Path -Path "C:\logs" -PathType Container)) {
    New-Item -Path "C:\logs" -ItemType Directory -Force | Out-Null
}

# Function to get the share path using Get-SmbShare with error handling
function Get-SharePath {
    <#
    .SYNOPSIS
        Retrieves the file system path for a given SMB share name
    .PARAMETER ShareName
        The name of the SMB share
    .RETURNS
        Full path of the share or "Unknown" if resolution fails
    #>
    param([string]$ShareName)
    try {
        # Attempt to get share path
        (Get-SmbShare -Name $ShareName -ErrorAction Stop).Path
    } catch {
        # Log warning and return "Unknown" if share path cannot be resolved
        Write-Warning "Could not resolve path for share '$ShareName': $_"
        return "Unknown"
    }
}

# Function to resolve an IP address to an FQDN with error handling
function Get-FqdnFromIP {
    <#
    .SYNOPSIS
        Resolves an IP address to its Fully Qualified Domain Name (FQDN)
    .PARAMETER IPAddress
        The IP address to resolve
    .RETURNS
        FQDN if resolution is successful, otherwise returns the original IP
    #>
    param([string]$IPAddress)
    $dnsServer = "LDN1WS0060.corp.ad.tullib.com"

    try {
        # Attempt to resolve IP to FQDN using PTR record
        $hostInfo = Resolve-DnsName -Name $IPAddress -Type PTR -Server $dnsServer -ErrorAction Stop
        return $hostInfo.NameHost
    } catch {
        # Log warning and return original IP if resolution fails
        Write-Warning "Could not resolve FQDN for IP '$IPAddress': $_"
        return $IPAddress
    }
}

# Get current connections with enhanced properties
$currentConnections = Get-CimInstance -ClassName Win32_ServerConnection | ForEach-Object {
    # Create a custom object with resolved computer name and share details
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
    # Import existing log file if it exists
    $loggedConnections = Import-Csv -Path $logFile
} else {
    # Create initial log file with current connections if no log exists
    $currentConnections | Export-Csv -Path $logFile -NoTypeInformation
    $loggedConnections = @()
}

# Determine new connections efficiently
$newConnections = Compare-Object -ReferenceObject $loggedConnections -DifferenceObject $currentConnections -Property ComputerName, ShareName, UserName, ConnectionID -PassThru | 
    Where-Object {$_.SideIndicator -eq "=>"}

# Append new connections to the log file
if ($newConnections) {
    # Export new connections to the log file
    $newConnections | Export-Csv -Path $logFile -Append -NoTypeInformation
    Write-Host "Logged $($newConnections.Count) new connections."
} else {
    Write-Host "No new connections to log."
}
