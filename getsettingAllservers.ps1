# Define the function to get DNS settings of remote computers
function Get-RemoteDnsClientSetting {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]] $ComputerName = $env:computername
    )

    begin {}
    process {
        foreach ($Computer in $ComputerName) {
            Write-Verbose "Working on $Computer"
            if (Test-Connection -ComputerName $Computer -Count 1 -ea 0) {
                
                try {
                    $Networks = Get-WmiObject -Class Win32_NetworkAdapterConfiguration `
                                -Filter IPEnabled=TRUE `
                                -ComputerName $Computer `
                                -ErrorAction Stop
                } catch {
                    Write-Verbose "Failed to Query $Computer. Error details: $_"
                    continue
                }
                foreach ($Network in $Networks) {
                    $DNSServers = $Network.DNSServerSearchOrder
                    $NetworkName = $Network.Description
                    If (!$DNSServers) {
                        $PrimaryDNSServer = "Notset"
                        $SecondaryDNSServer = "Notset"
                    } elseif ($DNSServers.count -eq 1) {
                        $PrimaryDNSServer = $DNSServers[0]
                        $SecondaryDNSServer = "Notset"
                    } else {
                        $PrimaryDNSServer = $DNSServers[0]
                        $SecondaryDNSServer = $DNSServers[1]
                    }
                    If ($network.DHCPEnabled) {
                        $IsDHCPEnabled = $true
                    }
                    
                    $OutputObj  = New-Object -Type PSObject
                    $OutputObj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computer.ToUpper()
                    $OutputObj | Add-Member -MemberType NoteProperty -Name PrimaryDNSServers -Value $PrimaryDNSServer
                    $OutputObj | Add-Member -MemberType NoteProperty -Name SecondaryDNSServers -Value $SecondaryDNSServer
                    $OutputObj | Add-Member -MemberType NoteProperty -Name IsDHCPEnabled -Value $IsDHCPEnabled
                    $OutputObj | Add-Member -MemberType NoteProperty -Name NetworkName -Value $NetworkName
                    $OutputObj
                    
                }
            } else {
                Write-Verbose "$Computer not reachable"
            }
        }
    }
    end {}
}

# Get the list of computers authenticated in the past 15 days
$computers = Get-ADComputer -Filter 'OperatingSystem -like "*Server*"' -Properties LastLogonDate | Where-Object {($_.LastLogonDate -gt (Get-Date).AddDays(-15))} | Select-Object -ExpandProperty Name

# Call the function and export the results to a CSV file
Get-RemoteDnsClientSetting -ComputerName $computers | Export-CSV C:\temp\dnssettings.csv -NoTypeInformation
