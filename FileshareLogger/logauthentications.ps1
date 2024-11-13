$logDir = "C:\logs"
if (-not (Test-Path -Path $logDir -PathType Container)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$logFile = Join-Path $logDir "ServerLogons_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').csv"

function Get-FqdnFromIp {
    param([string]$ipAddress)
    
    if ($ipAddress -match '^(127\.|169\.254\.|::1|fe80:)' -or $ipAddress -eq '-') {
        return $ipAddress
    }

    try {
        $ErrorActionPreference = 'Stop'
        $result = nslookup $ipAddress 2>$null
        $fqdn = ($result | Where-Object { $_ -match '\s+Name:\s+(.+)' } | Select-Object -First 1)
        
        return ($fqdn -replace '^\s*Name:\s*', '') -replace '\.$', ''
    }
    catch {
        return $ipAddress
    }
}

$logonTypes = @{
    2 = "Interactive"
    3 = "Network"
    4 = "Batch"
    5 = "Service"
}

try {
    $startTime = (Get-Date).AddHours(-94)
    
    Get-WinEvent -FilterHashtable @{
        Logname='Security'; 
        ID=4624;
        StartTime=$startTime
    } -ErrorAction Stop | 
        Where-Object {$_.Properties[8].Value -in 2, 3, 4, 5} | 
        Select-Object -First 500 |
        ForEach-Object {
            $logonTypeValue = $_.Properties[8].Value
            $logonType = if ($logonTypes.ContainsKey($logonTypeValue)) {
                $logonTypes[$logonTypeValue]
            } else {
                "Unknown"
            }
            
            [PSCustomObject]@{
                Time = $_.TimeCreated
                'Logon Type' = $logonType
                User = $_.Properties[5].Value
                'Target Computer' = $_.Properties[4].Value
                'Source IP' = $_.Properties[18].Value
                'Source Computer' = $_.Properties[11].Value
                'Logon Process' = $_.Properties[9].Value
                FQDN = Get-FqdnFromIp $_.Properties[18].Value
            }
        } |
        Export-Csv -Path $logFile -NoTypeInformation

    Write-Host "Authentication logs have been successfully exported to: $logFile"
}
catch {
    Write-Error "An error occurred while processing authentication logs: $_"
}
