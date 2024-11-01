function Unlock-User {
    param(
        [Parameter(Mandatory = $true)]
        [string]$domainName,

        [Parameter(Mandatory = $true)]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$cred,

        [int]$daysBack = 7
    )

    $domain = Get-ADDomain $domainName
    $pdc = if ($domainName -eq "ad.tradeblade.com") {"10.91.72.250"} elseif ($domainName -eq "ebdev.tpebroking.com") {"10.90.70.112"} elseif ($domain -eq 'lnholdings.com') {'NJC1WS0007.LNHOLDINGS.COM'} else {"$($domain.PDCEmulator)"}
    Write-Host "PDC for $domainName is $($pdc)"

    $lockout = Get-ADUser -Server $pdc -Credential $cred -Identity $userName -Properties LockedOut

    if ($lockout.LockedOut -eq $true) {
        Write-Host 'Account is locked, unlocking account'

        try {
            Unlock-ADAccount -Identity $userName -Server $pdc -Credential $cred
            Write-Host 'Unlocking Successful'
        }
        catch {
            Write-Host "Unlock failed"
        }

    }
    else {
        Write-Host "User $($userName) is not locked out."
    }

    Write-Host 'Searching for unlock source'
    $space = ($userName -split ' ').Count


    Invoke-Command -ComputerName $pdc -Credential $cred -ScriptBlock {
        $space = $using:space
        $startDate = (Get-Date).AddDays(-$using:daysBack)
        $endDate = Get-Date

        $events = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4740; StartTime = $startDate; EndTime = $endDate } | Where-Object { $_.Properties[0].Value -eq $using:userName }

        if ($events) {
            $output = @()
            foreach ($event in $events) {
                $lockoutSource = $event.Properties[1].Value
                $properties = @{
                    Username         = $event.Properties[0].Value
                    TimeGenerated    = $event.TimeCreated
                    DomainController = $event.MachineName
                    LockoutSource    = $lockoutSource
                }
                $output += New-Object psobject -Property $properties
            }
            $output | Format-Table Username, TimeGenerated, DomainController, LockoutSource -AutoSize

            $uniqueLockoutSources = $output | Select-Object -ExpandProperty LockoutSource -Unique
            foreach ($lockoutSource in $uniqueLockoutSources) {
                $userNameToMatch = $using:userName
                $sessions = quser /server:$lockoutSource 2>&1 | Where-Object { $_ -imatch "^\s*$userNameToMatch\s" } | ForEach-Object {
                        ($_.Trim() -split '\s+')[$space]
                }
Write-host "Script is looking for $userNameToMatch"
Write-Host "Sessions found on $lockoutSource is session $sessions"
                
                foreach ($session in $sessions) {
                        logoff $session /server:$lockoutSource
                        Write-Host "User $($using:userName) has been logged off from $($lockoutSource). Session ID: $($session)."
                    }
                
                if ($sessions -eq $null) {
                    Write-Host "No session found for user $($using:userName) on $($lockoutSource)."
                }
            }
        }
    }
    
}
