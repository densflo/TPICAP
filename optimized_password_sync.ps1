# Configuration
$config = @{
    ServerListPath = "D:\IvantiRestAPI\ServerList.txt"
    SecretServer = "https://tss.secretservercloud.eu"
    RuleName = "ivanti_020321"
    OnboardingKey = "f7a6XRu8BLcH28EbVbFFW7q+kfPYXgyrmeNj4Ttys40="
    ConfigPath = "D:\thycotic"
    SmtpServer = "smtprelay.corp.ad.tullib.com"
    FromEmail = "svtautomation@tpicap.com"
    ToEmail = @("dennisjeffrey.flores@tpicap.com", "winteladministrators@tpicap.com")
}

# Improved logging function
function Add-Log {
    param (
        [string]$Message,
        [string]$LogLevel = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$LogLevel] - $Message"
    
    Write-Host $logMessage
    $script:logData.Add($logMessage)
}

# Error handling function
function Handle-Error {
    param (
        [string]$ErrorMessage,
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    Add-Log $ErrorMessage "ERROR"
    if ($ErrorRecord) {
        Add-Log $ErrorRecord.Exception.Message "ERROR"
    }
}

# Function to check account lock status
function Check-AccountLockStatus {
    param (
        [string]$Server,
        [object]$Secret,
        [object]$Session
    )

    try {
        $name = Get-TssSecretField -TssSession $Session -Id $Secret.SecretId -Slug username
        $domain = Get-TssSecretField -TssSession $Session -Id $Secret.SecretId -Slug domain
        $password = Get-TssSecretField -TssSession $Session -Id $Secret.SecretId -Slug password

        Add-Log "Checking lock status for account: $name"

        # Determine PDC
        $pdc = switch ($domain) {
            "ad.tradeblade.com" { "10.91.72.250" }
            "ebdev.tpebroking.com" { "10.90.70.112" }
            "lnholdings.com" { "UK1CVDC04.lnholdings.com" }
            default { (Get-ADDomain $domain).PDCEmulator }
        }
        Add-Log "PDC for $domain is $pdc"

        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential -ArgumentList "$domain\$name", $securePassword
        
        $lockout = Get-ADUser -Server $pdc -Credential $cred -Identity $name -Properties LockedOut -ErrorAction Stop
        if ($lockout.LockedOut) {
            Add-Log "$name is locked out. Please unlock it and try again." "WARNING"
            return [PSCustomObject]@{
                Server = $Server
                Username = "*** $name"
                Status = "Locked out"
                IsLocked = $true
            }
        }
        Add-Log "$name is not locked out."
        return [PSCustomObject]@{
            Server = $Server
            Username = "*** $name"
            Status = "Not locked"
            IsLocked = $false
            Domain = $domain
            Name = $name
            Password = $password
        }
    } catch {
        Handle-Error "Error checking lock status for $name on server $Server" $_
        return [PSCustomObject]@{
            Server = $Server
            Username = "*** $name"
            Status = "Check failed"
            IsLocked = $true
        }
    }
}

# Function to update credentials
function Update-Credentials {
    param (
        [string]$Server,
        [object]$AccountInfo,
        [object]$Ivanticreds
    )

    try {
        $ivantiAccount = $Ivanticreds.value | Where-Object { $_.Name -eq "*** $($AccountInfo.Name)" }
        if (-not $ivantiAccount) {
            Add-Log "No matching Ivanti account found for $($AccountInfo.Name)" "WARNING"
            return [PSCustomObject]@{
                Server = $Server
                Username = "*** $($AccountInfo.Name)"
                Status = "No matching Ivanti account"
            }
        }

        $credentialUrl = "https://$($Server):3121/st/console/api/v1.0/credentials/{$($ivantiAccount.id)}"
        $credentialBody = @{
            name = "*** $($AccountInfo.Name)"
            password = @{ ClearText = $AccountInfo.Password }
            username = "$($AccountInfo.Domain)\$($AccountInfo.Name)"
        } | ConvertTo-Json -Depth 99

        Invoke-RestMethod -Method Put -UseDefaultCredentials -Uri $credentialUrl -Body $credentialBody -ContentType "application/json" -ErrorAction Stop

        Add-Log "Successfully updated password for $($AccountInfo.Name) on server $Server."
        return [PSCustomObject]@{
            Server = $Server
            Username = "*** $($AccountInfo.Name)"
            Status = "Updated"
        }
    } catch {
        Handle-Error "Error updating password for $($AccountInfo.Name) on server $Server" $_
        return [PSCustomObject]@{
            Server = $Server
            Username = "*** $($AccountInfo.Name)"
            Status = "Update failed"
        }
    }
}

# Initialize variables
$script:logData = [System.Collections.Generic.List[string]]::new()
$reportData = [System.Collections.Generic.List[PSCustomObject]]::new()

# Main script execution
try {
    # Import required module
    Import-Module Thycotic.SecretServer -Force
    Add-Log "Thycotic.SecretServer module imported successfully."

    # Read server list
    $ServerList = Get-Content $config.ServerListPath -ErrorAction Stop
    Add-Log "Server list read successfully from $($config.ServerListPath)"

    # Initialize Thycotic SDK client
    Initialize-TssSdkClient `
        -SecretServer $config.SecretServer `
        -RuleName $config.RuleName `
        -Onboardingkey $config.OnboardingKey `
        -ConfigPath $config.ConfigPath `
        -Force
    Add-Log "Thycotic SDK client initialized."

    # Establish session with Secret Server
    $session = New-TssSession -SecretServer $config.SecretServer -ConfigPath $config.ConfigPath -UseSdkClient 
    Add-Log "Session established with Secret Server."
    $secrets = Search-TssSecret -TssSession $session 
    Add-Log "Secrets retrieved successfully."

    # First pass: Check account lock status
    $accountStatus = @{}
    foreach ($server in $ServerList) {
        Add-Log "Checking accounts on server: $server"
        $accountStatus[$server] = @()
        foreach ($secret in $secrets) {
            $status = Check-AccountLockStatus -Server $server -Secret $secret -Session $session
            $accountStatus[$server] += $status
            $reportData.Add($status)
        }
    }

    # Second pass: Update credentials for unlocked accounts
    foreach ($server in $ServerList) {
        Add-Log "Updating credentials on server: $server"
        # Retrieve credentials from Ivanti
        $APIcredentials = "https://$($server):3121/st/console/api/v1.0/credentials"
        try {
            $Ivanticreds = Invoke-RestMethod -Uri $APIcredentials -UseDefaultCredentials -ErrorAction Stop
            Add-Log "Retrieved Ivanti credentials for server: $server"
        } catch {
            Handle-Error "Error retrieving Ivanti credentials for server: $server" $_
            continue
        }

        foreach ($account in $accountStatus[$server]) {
            if (-not $account.IsLocked) {
                $updateResult = Update-Credentials -Server $server -AccountInfo $account -Ivanticreds $Ivanticreds
                $reportData.Add($updateResult)
            }
        }
    }

    # Generate report
    $reportTable = $reportData | Format-Table -AutoSize | Out-String
    $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Prepare and send email
    $emailParams = @{
        From       = $config.FromEmail
        To         = $config.ToEmail
        Subject    = "Password Synchronization Results - $currentDateTime"
        SmtpServer = $config.SmtpServer
        Body       = @"
<html>
<body>
<h2>Shavlik Password Synchronization Results - $currentDateTime</h2>
<pre>
$reportTable
</pre>
<h3>Log Data:</h3>
<pre>
$($script:logData -join "`n")
</pre>
</body>
</html>
"@
        BodyAsHtml = $true
    }

    Send-MailMessage @emailParams
    Add-Log "Report and logs emailed successfully."

} catch {
    Handle-Error "An error occurred during script execution" $_
} finally {
    Add-Log "Script execution completed."
}
