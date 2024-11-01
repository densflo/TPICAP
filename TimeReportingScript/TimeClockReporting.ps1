param (
    [string] $scriptDir = "D:\TimeReportingScript\",
    [string] $smtpServer = "smtprelay.corp.ad.tullib.com",
    [string] $fromEmail = "svtautomation@tpicap.com",
    [string] $toEmail = "dennisjeffrey.flores@tpicap.com"
)
function Log-Message {
    param (
        [string] $message,
        [switch] $isWarning,
        [switch] $isError
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp $message"
    $global:logData += $logMessage + "`n"

    if ($isWarning) {
        Write-Warning $logMessage
    } elseif ($isError) {
        Write-Error $logMessage
    } else {
        Write-Host $logMessage
    }
}
function Test-RemoteComputer {
    param (
        [String] $Server
    )
    
    Log-Message "Testing connection to $Server..."
    try {
        $ping = Test-Connection -ComputerName $Server -Count 2 -ErrorAction Stop -Quiet
        $connectionStatus = if ($ping) { "successful" } else { "failed" }
        Log-Message "Connection $connectionStatus to $Server"
        $ping
    } catch {
        Log-Message "Error testing connection to $Server : $_" -isError
        $false
    }
}
function OpenAndReadServersFile {
    param (
        [string] $filePath
    )

    Log-Message "Reading servers file from $filePath"

    if (Test-Path $filePath) {
        Get-Content -Path $filePath
    } else {
        Log-Message "The file 'servers.txt' does not exist in the script's directory." -isWarning
        @()
    }
}
function Get-RemoteSession {
    param (
        [String] $Server
    )
    
    Log-Message "Getting remote session for $Server..."
    try {
        $cred = & "D:\Thycotic\Get-thycoticCredentials_v3.ps1" -server $Server
        $securePassword = ConvertTo-SecureString $cred.Password -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential ($cred.Username, $securePassword)
        Log-Message "Credential for $Server is $($cred.Username)"
        New-PSSession -ComputerName $Server -Credential $psCred -ErrorAction Stop
    } catch {
        Log-Message "Error getting remote session for $Server : $_" -isWarning
        $null
    }
}
function Get-TimeKeeperStatus {
    param (
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $server
    )

    try {
        $report = Invoke-Command -Session $session -ScriptBlock {
            $output = & 'C:\Program Files\timekeeper\release64\tkstatus.bat'
            $serviceStatus = Get-Service -Name 'timekeeper' -ErrorAction SilentlyContinue
            return @{
                Output        = $output
                ServiceName   = $serviceStatus.DisplayName
                ServiceStatus = $serviceStatus.Status
            } 
        } -ErrorAction SilentlyContinue

        if ($report) {
            $statusLines = ($report.Output -join "`n") -split "`n"
            [PSCustomObject]@{
                Server            = $server
                TimeKeeperVersion = if ($statusLines[2] -match '\d+(\.\d+)+') { $matches[0] } else { "N/A" }
                LicenseExpires    = if ($statusLines[3] -match '\d+') { $matches[0] } else { "N/A" }
                TKStatus          = if ($statusLines[6]) { $statusLines[5] } else { $statusLines[4] }
                ServiceName       = if ($report.ServiceName) { $report.ServiceName } else { "N/A" }
                ServiceStatus     = if ($report.ServiceStatus) { $report.ServiceStatus } else { "N/A" }
            }
        } else {
            Log-Message "Cannot run tkstatus.bat on $server" -isWarning
            [PSCustomObject]@{
                Server            = $server
                TimeKeeperVersion = "N/A"
                LicenseExpires    = "N/A"
                TKStatus          = "N/A"
                ServiceName       = "N/A"
                ServiceStatus     = "N/A"
            }
        }
    } catch {
        Log-Message "Error invoking command on $[server]: $_" -isWarning
        [PSCustomObject]@{
            Server            = $server
            TimeKeeperVersion = "N/A"
            LicenseExpires    = "N/A"
            TKStatus          = "N/A"
            ServiceName       = "N/A"
            ServiceStatus     = "N/A"
        }
    }
}

# Initialize log data
$global:logData = ""

# Get the directory of the current script
$serversFilePath = Join-Path -Path $scriptDir -ChildPath "servers.txt"

# Output the full path
Log-Message "Servers file path is $serversFilePath"

# Read servers file
$servers = OpenAndReadServersFile -filePath $serversFilePath

# Initialize array to hold report data
$reportData = [System.Collections.ArrayList]@()

# Process each server
foreach ($server in $servers) {
    if (Test-RemoteComputer -Server $server) {
        $session = Get-RemoteSession -Server $server
        
        if ($session) {
            $statusData = Get-TimeKeeperStatus -session $session -server $server

            if ($statusData) {
                $reportData.Add($statusData) | Out-Null
                Log-Message "Collected status for $server"
            }

            # Remove the session
            Remove-PSSession -Session $session
        } else {
            Log-Message "Session creation failed for $server" -isWarning
            $reportData.Add([PSCustomObject]@{
                Server            = $server
                TimeKeeperVersion = "N/A"
                LicenseExpires    = "N/A"
                TKStatus          = "N/A - Session creation failed"
                ServiceName       = "N/A - Session creation failed"
                ServiceStatus     = "N/A - Session creation failed"
            }) | Out-Null
        } 
    } else {
        Log-Message "Connection failed for $server" -isWarning
        $reportData.Add([PSCustomObject]@{
            Server            = $server
            TimeKeeperVersion = "N/A"
            LicenseExpires    = "N/A"
            TKStatus          = "N/A - Connection failed"
            ServiceName       = "N/A - Connection failed"
            ServiceStatus     = "N/A - Connection failed"
        }) | Out-Null
    }
}

# Export report data to CSV file
$csvFilePath = Join-Path -Path $scriptDir -ChildPath "TimeKeeperStatusReport.csv"
$reportData | Export-Csv -Path $csvFilePath -NoTypeInformation

# Format report data as table
$reportTable = $reportData | Format-Table | Out-String
$currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Define email parameters
$emailParams = @{
    From       = $fromEmail
    To         = $toEmail
    Subject    = "Remote TimeKeeper Status Report for Windows Systems - $currentDateTime"
    SmtpServer = $smtpServer
}

# Email body
$emailBody = @"
<html>
<body>
<h2>Remote TimeKeeper Status Report for Windows Systems - $currentDateTime</h2>
<pre>
$reportTable
</pre>
<h3>Log Data:</h3>
<pre>
$global:logData
</pre>
</body>
</html>
"@

# Send email with attachment
Send-MailMessage @emailParams -Body $emailBody -BodyAsHtml -Attachments $csvFilePath

# Output completion message
Log-Message "Report and logs emailed successfully."

