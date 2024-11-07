function Get-A2RMData {
    <#
    .SYNOPSIS
        Retrieves and displays A2RM CMDB data for a specified computer.
    
    .DESCRIPTION
        This function makes an API call to A2RM to retrieve CMDB data for a specified computer
        and displays it on screen. If no computer name is provided, it uses the local computer.
        Displays both formatted output and raw JSON payload.
    
    .PARAMETER ComputerName
        The name of the computer to lookup. If not specified, uses the local computer name.
    
    .PARAMETER CurlPath
        The path to the curl executable. Default is "curl.exe" which assumes curl is in PATH.
    
    .EXAMPLE
        Get-A2RMData
        Retrieves and displays A2RM data for the local computer
    
    .EXAMPLE
        Get-A2RMData -ComputerName "SERVER01"
        Retrieves and displays A2RM data for SERVER01
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$ComputerName = $env:computername,
        [string]$CurlPath = "curl.exe"
    )

    try {
        # Validate computer name
        if ([string]::IsNullOrEmpty($ComputerName)) {
            throw "Computer name cannot be empty"
        }

        Write-Verbose "Processing for hostname: $ComputerName"

        # Set up API call
        $uri = "https://api.a2rm.direct.tpicapcloud.com/host/$($ComputerName)?report=hostcache"
        $user = 'readonly'
        $pass = 'readonly'
        $pair = "$($user):$($pass)"
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
        $Headers = "Authorization:Basic $encodedCreds"

        Write-Verbose "Making API call to A2RM"
        
        # Make API call
        $returnedJSON = & $CurlPath -X GET -s -k -H $Headers $uri
        if (-not $?) {
            throw "Curl command failed. Check network connection and try running manually for full output."
        }

        Write-Verbose "API call successful"

        # Parse and validate JSON
        $A2RMData = $returnedJSON | ConvertFrom-Json

        # Validate required fields
        if (-not ($A2RMData.'Derived-Environment' -match '[A-Z][A-Z].*')) {
            throw "Invalid response - Missing or invalid Derived-Environment"
        }

        if (-not ($A2RMData.'Hostname' -match '\w')) {
            throw "Invalid response - Missing or invalid Hostname"
        }

        # Format and display the data
        Write-Output "`nA2RM Data for $($A2RMData.Hostname.ToUpper())"
        Write-Output "----------------------------------------"
        
        # Display basic information
        Write-Output "Basic Information:"
        Write-Output "  Hostname: $($A2RMData.Hostname)"
        Write-Output "  Environment: $($A2RMData.'Derived-Environment')"
        Write-Output "  OS Type: $($A2RMData.'OS-Type')"
        Write-Output "  Location: $($A2RMData.Location)"
        Write-Output "  Lifecycle Stage: $($A2RMData.'Lifecycle-Stage')"
        Write-Output "  In Service: $($A2RMData.'In Service')"
        
        # Display Application Instances
        Write-Output "`nApplication Instances:"
        if ($A2RMData.'Application-Instances'.Count -gt 0) {
            foreach ($instance in $A2RMData.'Application-Instances') {
                $appName = $instance.PSObject.Properties.Name
                $appData = $instance.PSObject.Properties.Value
                
                Write-Output "  Application: $appName"
                Write-Output "    Environment: $($appData.Environment)"
                Write-Output "    Region: $($appData.Region)"
                Write-Output "    Service Tier: $($appData.'Service-Tier')"
                Write-Output "    Lifecycle Stage: $($appData.'Lifecycle-Stage')"
                Write-Output "    APM Enabled: $($appData.'APM-Enabled')"
                Write-Output "    Description: $($appData.Description)"
                Write-Output "    Business Owner: $($appData.'Business-Owner')"
                Write-Output "    Technical Owner: $($appData.'Technical-Owner')"
                Write-Output "    Support Owner: $($appData.'Support-Owner')"
                Write-Output "    Support Team: $($appData.'Support-Team')"
                Write-Output ""
            }
        } else {
            Write-Output "  No applications found"
        }
        
        # Display Server Information
        Write-Output "`nServer Information:"
        Write-Output "  Server Hierarchy: $($A2RMData.'Server-Hierarchy')"
        Write-Output "  APM Enabled: $($A2RMData.'APM-Enabled')"
        Write-Output "  DB Server: $($A2RMData.'DB-Server')"
        Write-Output "  AppD Agent Port1: $($A2RMData.'Appd-Agent-Port1')"
        Write-Output "  AppD Agent Port2: $($A2RMData.'Appd-Agent-Port2')"
        
        # Display Tags
        Write-Output "`nTags:"
        Write-Output "  Name: $($A2RMData.'Tag:Name')"
        Write-Output "  Hostname: $($A2RMData.'Tag:Hostname')"
        
        Write-Output "`n----------------------------------------"
        
        # Display full JSON payload
        Write-Output "`nFull JSON Payload:"
        Write-Output $returnedJSON | ConvertFrom-Json | ConvertTo-Json -Depth 10
        
        Write-Output "`n----------------------------------------"
    }
    catch {
        Write-Error $_.Exception.Message
    }
}
