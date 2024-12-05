# Function to get FQDN from IP address
function Get-FqdnFromIp {
    param(
        [string]$ipAddress,
        [string]$dnsServer = "LDN1WS0060.corp.ad.tullib.com"
    )
    if ($ipAddress -as [IPAddress]) {
        try {
            $result = Resolve-DnsName -Name $ipAddress -Server $dnsServer -ErrorAction Stop
            return $result.NameHost
        }
        catch {
            Write-Warning "Could not resolve FQDN for IP '$ipAddress': $_"
            return "N/A"
        }
    } else {
        return "N/A" # Return N/A for invalid IP format
    }
}

# Hashtable for logon type mapping
$logonTypes = @{
    2 = "Interactive"
    3 = "Network"
    4 = "Batch"
    5 = "Service"
}

# Set error action preference
$ErrorActionPreference = "Stop"

try {
    $events = Get-WinEvent -FilterHashtable @{Logname='Security'; ID=4624} -ErrorAction Stop

    $totalEvents = $events.Count
    $processedEvents = 0

    $events | 
        Where-Object {$_.Properties[8].Value -in 2, 3, 4, 5} | 
        ForEach-Object {
            $processedEvents++
            $percentComplete = ($processedEvents / $totalEvents) * 100
            Write-Progress -Activity "Processing Events" -Status "Progress" -PercentComplete $percentComplete

            $logonType = if ($logonTypes.ContainsKey($_.Properties[8].Value)) {
                $logonTypes[$_.Properties[8].Value]
            } else {
                "Unknown"
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
        Export-Csv -Path "C:\logs\ServerLogons.csv" -NoTypeInformation

    Write-Host "Export completed successfully. File saved at C:\logs\ServerLogons.csv"
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    Write-Progress -Activity "Processing Events" -Completed
}
