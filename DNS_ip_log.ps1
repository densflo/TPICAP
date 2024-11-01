function Get-DNSDebugLog {
    <#
    .SYNOPSIS
    This cmdlet parses a Windows DNS Debug log and resolves IP addresses to FQDNs.
    .DESCRIPTION
    Parses the DNS debug file and converts IP addresses to FQDNs in the output.
    .EXAMPLE
    Get-DNSDebugLog -DNSLog ".\Something.log" | Export-Csv .\ProperlyFormatedLog.csv
    Turns the debug file into a CSV file with FQDNs instead of IPs.
    .PARAMETER DNSLog
    Path to the DNS log or DNS log data.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Fullname')]
        [string] $DNSLog = 'StringMode'
    )

    BEGIN { }
    PROCESS {
        $TheReverseRegExString = '\(\d\)in-addr\(\d\)arpa\(\d\)'
        ReturnDNSLogLines -DNSLog $DNSLog | ForEach-Object {
            if ($_ -match '^\d\d|^\d/\d' -and $_ -notlike '*EVENT*' -and $_ -notlike '* Note: *') {
                # Initialize variables
                $Date = $Time = $DateTime = $Protocol = $Client = $SendReceive = $QueryType = $RecordType = $Query = $Result = $null
                
                $Date = ($_ -split ' ')[0]
                # Check log time format and set properties
                if ($_ -match ':\d\d AM|:\d\d  PM') {
                    $Time = ($_ -split ' ')[1,2] -join ' '
                    $Protocol = ($_ -split ' ')[7]
                    $Client = ($_ -split ' ')[9]
                    $SendReceive = ($_ -split ' ')[8]
                    $RecordType = (($_ -split ']')[1] -split ' ')[1]
                    $Query = ($_.Substring(110)) -replace '\s' -replace '\(\d?\d\)', '.' -replace '^\.' -replace "\.$"
                    $Result = (((($_ -split '\[')[1]).Substring(9)) -split ']')[0] -replace ' '
                } elseif ($_ -match '^\d\d\d\d\d\d\d\d \d\d:') {
                    $Date = $Date.Substring(0,4) + '-' + $Date.Substring(4,2) + '-' + $Date.Substring(6,2)
                    $Time = ($_ -split ' ')[1]
                    $Protocol = ($_ -split ' ')[6]
                    $Client = ($_ -split ' ')[8]
                    $SendReceive = ($_ -split ' ')[7]
                    $RecordType = (($_ -split ']')[1] -split ' ')[1]
                    $Query = ($_.Substring(110)) -replace '\s' -replace '\(\d?\d\)', '.' -replace '^\.' -replace "\.$"
                    $Result = (((($_ -split '\[')[1]).Substring(9)) -split ']')[0] -replace ' '
                } else {
                    $Time = ($_ -split ' ')[1]
                    $Protocol = ($_ -split ' ')[6]
                    $Client = ($_ -split ' ')[8]
                    $SendReceive = ($_ -split ' ')[7]
                    $RecordType = (($_ -split ']')[1] -split ' ')[1]
                    $Query = ($_.Substring(110)) -replace '\s' -replace '\(\d?\d\)', '.' -replace '^\.' -replace "\.$"
                    $Result = (((($_ -split '\[')[1]).Substring(9)) -split ']')[0] -replace ' '
                }

                $DateTime = Get-Date "$Date $Time" -Format 'yyyy-MM-dd HH:mm:ss'

                if ($_ -match $TheReverseRegExString) {
                    $QueryType = 'Reverse'
                } else {
                    $QueryType = 'Forward'
                }

                # Resolve Client IP to FQDN
                try {
                    $ClientFQDN = [System.Net.Dns]::GetHostEntry($Client).HostName
                } catch {
                    $ClientFQDN = $Client  # If resolution fails, keep the IP
                }

                # Construct the output object
                $returnObj = [PSCustomObject]@{
                    Date         = $DateTime
                    QueryType    = $QueryType
                    Client       = $ClientFQDN
                    SendReceive  = $SendReceive
                    Protocol     = $Protocol
                    RecordType   = $RecordType
                    Query        = $Query
                    Results      = $Result
                }

                if ($returnObj.Query -ne $null) {
                    Write-Output $returnObj
                }
            }
        }
    }
    END { }
}

function ReturnDNSLogLines {
    param(
        $DNSLog
    )
    $PathCorrect = try { Test-Path $DNSLog -ErrorAction Stop } catch { $false }
    if ($DNSLog -match '^\d\d|^\d/\d' -and $DNSLog -notlike '*EVENT*' -and $PathCorrect -ne $true) {
        $DNSLog
    } elseif ($PathCorrect -eq $true) {
        Get-Content $DNSLog | ForEach-Object { $_ }
    }
}

# Example usage:
# Get-DNSDebugLog -DNSLog ".\dns_debug.log" | Export-Csv .\ProperlyFormatedLog.csv -NoTypeInformation