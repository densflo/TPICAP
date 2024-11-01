# PowerShell Script: logauthentications.ps1

# Ensure log directory exists
$logDir = "C:\logs"
if (-not (Test-Path -Path $logDir -PathType Container)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Log file path with timestamp
$logFile = Join-Path $logDir "ServerLogons_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').csv"

# Function to resolve IP to FQDN
function Get-FqdnFromIp {
    param([string]$ipAddress)

    $dnsServer = "LDN1WS0060.corp.ad.tullib.com"

    try {
        $hostInfo = Resolve-DnsName -Name $ipAddress -Type PTR -Server $dnsServer -ErrorAction Stop
        return $hostInfo.NameHost
    }
    catch {
        Write-Warning "Could not resolve FQDN for IP '$ipAddress': $_"
        return $ipAddress # Return IP if resolution fails 
    }
}

# Define logon types
$logonTypes = @{
    2 = "Interactive"
    3 = "Network"
    4 = "Batch"
    5 = "Service"
}

try {
    Get-WinEvent -FilterHashtable @{Logname='Security'; ID=4624} -ErrorAction Stop | 
        Where-Object {$_.Properties[8].Value -in 2, 3, 4, 5} | # Filter for specific logon types
        ForEach-Object {
            $logonTypeValue = $_.Properties[8].Value
            if ($logonTypes.ContainsKey($logonTypeValue)) {
                $logonType = $logonTypes[$logonTypeValue]
            } else {
                $logonType = "Unknown"
            }
            
            [PSCustomObject]@{
                Time = $_.TimeCreated
                'Logon Type' = $logonType
                User = $_.Properties[5].Value
                Computer = $_.Properties[6].Value
                FQDN = Get-FqdnFromIp $_.Properties[18].Value
                'Logon Process' = $_.Properties[9].Value
            }
        } |
        Export-Csv -Path $logFile -NoTypeInformation

    Write-Host "Authentication logs have been successfully exported to: $logFile"
}
catch {
    Write-Error "An error occurred while processing authentication logs: $_"
}
