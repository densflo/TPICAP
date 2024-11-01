function Get-A2RMData {
    <#
    .SYNOPSIS
        Retrieves A2RM CMDB data for a specified server.
    
    .DESCRIPTION
        This function queries the A2RM API to get CMDB data for a given server using PowerShell's native web request capabilities.
    
    .PARAMETER ServerName
        The name of the server to query. If not provided, uses local computer name.
    
    .EXAMPLE
        Get-A2RMData -ServerName "SERVER01"
        
    .EXAMPLE
        Get-A2RMData    # Uses local computer name
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$ServerName = $env:computername
    )

    ## Check if hostname is valid
    if ([string]::IsNullOrWhiteSpace($ServerName)) {
        Write-Error "Server name cannot be empty"
        return
    }

    ## Creds are default values as data is world readable but the protocol requires creds
    $user = 'readonly'
    $pass = 'readonly'
    
    ## Create credential object for authentication
    $securePass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($user, $securePass)

    ## Build the URI
    $uri = "https://api.a2rm.direct.tpicapcloud.com/host/$($ServerName)?report=hostcache"

    try {
        # Ignore SSL certificate validation
        if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
            $certCallback = @"
                using System;
                using System.Net;
                using System.Net.Security;
                using System.Security.Cryptography.X509Certificates;
                public class ServerCertificateValidationCallback
                {
                    public static void Ignore()
                    {
                        ServicePointManager.ServerCertificateValidationCallback += 
                            delegate
                            (
                                Object obj, 
                                X509Certificate certificate, 
                                X509Chain chain, 
                                SslPolicyErrors errors
                            )
                            {
                                return true;
                            };
                    }
                }
"@
            Add-Type $certCallback
        }
        [ServerCertificateValidationCallback]::Ignore()

        # Make the web request
        $response = Invoke-RestMethod -Uri $uri -Credential $cred -Method Get -ContentType "application/json"
    }
    catch {
        Write-Error "Failed to retrieve data from A2RM API: $_"
        return
    }

    ## Validate the returned data
    if (-not ($response.'Derived-Environment' -match '[A-Z][A-Z].*')) {
        Write-Error "Invalid response - Missing Derived Environment or unexpected value"
        return
    }

    if (-not ($response.'Hostname' -match '\w')) {
        Write-Error "Invalid response - Missing Hostname"
        return
    }

    ## Display the results
    Write-Host "Server Details for: $ServerName" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Derived Environment: $($response.'Derived-Environment')"
    Write-Host "Hostname: $($response.'Hostname')"
    
    ## Return the full object for pipeline usage
    return $response
}
