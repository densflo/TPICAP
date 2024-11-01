function OpenAndReadServersFile {
    param (
        [String] $filePath = "C:\temp\servers.txt"
    )
    
    Write-Host "Starting to open and read servers file..."
    Add-Content -Path $logFile -Value "[INFO] Starting to open and read servers file..."

    if (-not (Test-Path $filePath)) {
        Write-Host "File not found, creating new file..."
        Add-Content -Path $logFile -Value "[INFO] File not found, creating new file..."
        New-Item -ItemType File -Path $filePath -Force | Out-Null
    } else {
        Write-Host "File exists, opening in Notepad..."
        Add-Content -Path $logFile -Value "[INFO] File exists, opening in Notepad..."
    }

    # Launch and wait for Notepad to exit
    $notepadProcess = Start-Process -FilePath notepad.exe -ArgumentList $filePath -PassThru
    Write-Host "Notepad launched, waiting for close..."
    Add-Content -Path $logFile -Value "[INFO] Notepad launched, waiting for close..."
    $notepadProcess.WaitForExit()

    Write-Host "Notepad closed. Reading content from file..."
    Add-Content -Path $logFile -Value "[INFO] Notepad closed. Reading content from file..."
    return Get-Content -Path $filePath
}

function Send-Email {
    param (
        [String] $subject,
        [String] $body
    )
    Send-MailMessage @emailParams -Subject $subject -Body $body
}


function Get-RemoteSession {
    param (
        [String] $Server
    )
    Write-Host "Getting remote session for $Server..."
    Add-Content -Path $logFile -Value "[INFO] Getting remote session for $Server..."
    
        try {
            $creds = & "D:\Thycotic\Get-thycoticCredentials_V2.ps1" -server $Server
            Write-Host "Using credentials for $($creds.Username) on $server password: $($creds.Password)"
            Add-Content -Path $logFile -Value "[INFO] Using credentials for $($creds.Username) on $server"
            $securePassword = ConvertTo-SecureString $creds.Password -AsPlainText -Force
            $psCred = New-Object System.Management.Automation.PSCredential ($creds.Username, $securePassword)
            $session = New-PSSession -ComputerName $Server -Credential $psCred -ErrorAction Stop
            return $session
        } catch {
            Write-Host "Error: $_"
            Add-Content -Path $logFile -Value "[ERROR] Error: $_"
        }
    
    return $null
}

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
$global:logData = ""

# Read the list of servers
$servers = OpenAndReadServersFile


foreach ($server in $servers) {
    $session = Get-RemoteSession -Server $server
    if ($session) {

        # Get the DNS servers
        $dnsServers = Invoke-Command -Session $session -ScriptBlock {
            Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 } | ForEach-Object { $_.ServerAddresses }
        } -ArgumentList $server

        # Get the domain
        $domain = Invoke-Command -Session $session -ScriptBlock {
            Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
        } -ArgumentList $server

        # Output the results
        Write-Output "DNS Servers:"
        $dnsServers | ForEach-Object { Write-Output $_ }

        Write-Output "`nDomain:"
        Write-Output $domain

        Log-Message "Remote session for $server successful"
    } else {
        Log-Message "Remote session for $server failed" -isError
    }
}
