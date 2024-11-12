function Get-RemoteSession {
    param (   
        [Parameter(Mandatory = $true, ParameterSetName = "Server", HelpMessage = "PMS Account.")]
        [String] $Server
    )
    try {
        $cred = D:\Thycotic\Get-thycoticCredentials.ps1 -server $server
        $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)
        return New-PSSession -ComputerName $server -Credential $psCred -ErrorAction Stop
    }
    catch {
        Write-Error ("Failed to create remote session for {0}. Error: {1}" -f $server, $_.Exception.Message)
        return $null
    }
}

# Initialize an array to store server information
$serverResults = @()

# Read servers from input file
$servers = Get-Content 'C:\Input\servers.txt'

# Phase 1: Issue Reboot Commands to All Servers
$rebootSessions = @{}
foreach ($server in $servers) {
    Write-Host ("Preparing reboot for {0}" -f $server)
    $session = Get-RemoteSession -Server $server
    
    if ($null -ne $session) {
        try {
            Invoke-Command -Session $session -ScriptBlock {
                Restart-Computer -Force
            }
            $rebootSessions[$server] = $session
            Write-Host ("Reboot command issued to {0}" -f $server)
        }
        catch {
            Write-Warning ("Failed to issue reboot to {0}: {1}" -f $server, $_.Exception.Message)
        }
    }
}

# Wait 1 minute after issuing reboot commands
Write-Host "Waiting 1 minute for servers to begin rebooting..."
Start-Sleep -Seconds 60

# Phase 2: Collect Server Information
foreach ($server in $servers) {
    Write-Host ("Gathering information for {0}" -f $server)
    
    try {
        # Create a new session to check server status
        $newSession = Get-RemoteSession -Server $server
        
        if ($null -ne $newSession) {
            # Collect server information
            $serverInfo = Invoke-Command -Session $newSession -ScriptBlock {
                $os = Get-CimInstance Win32_OperatingSystem
                @{
                    ServerName = $env:COMPUTERNAME
                    Uptime = (Get-Date) - $os.LastBootUpTime
                    LastRebootTime = $os.LastBootUpTime
                }
            }
            
            # Add to results
            $serverResults += [PSCustomObject]@{
                ServerName = $serverInfo.ServerName
                Uptime = $serverInfo.Uptime
                LastRebootTime = $serverInfo.LastRebootTime
                Status = "Rebooted Successfully"
            }
            
            # Close the session
            $newSession | Remove-PSSession
        }
        else {
            # If cannot connect, add error status
            $serverResults += [PSCustomObject]@{
                ServerName = $server
                Uptime = "Connection Failed"
                LastRebootTime = "N/A"
                Status = "Error"
            }
        }
    }
    catch {
        Write-Error ("Error processing {0}: {1}" -f $server, $_.Exception.Message)
        $serverResults += [PSCustomObject]@{
            ServerName = $server
            Uptime = "Processing Error"
            LastRebootTime = "N/A"
            Status = "Error"
        }
    }
}

# Close any remaining reboot sessions
$rebootSessions.Values | Remove-PSSession

# Display results in a table
Write-Host "`nServer Reboot Summary:"
$serverResults | Format-Table -AutoSize

# Ensure output directory exists
if (-not (Test-Path "C:\Output")) {
    New-Item -ItemType Directory -Path "C:\Output" | Out-Null
}

# Export to CSV for further analysis
$serverResults | Export-Csv -Path "C:\Output\ServerRebootResults.csv" -NoTypeInformation

# Display CSV location
Write-Host "Detailed results exported to C:\Output\ServerRebootResults.csv"
