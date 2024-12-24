function get-appa2rm {
    param(
        [Parameter(Position=0)]
        [string]$ComputerName = $env:computername
    )

    # Extract hostname if FQDN is provided
    if ($ComputerName -match '\.') {
        $Hostname = $ComputerName.Split('.')[0]
    } else {
        $Hostname = $ComputerName
    }

    $CurlPath = "curl.exe"
    $uri = "https://api.a2rm.direct.tpicapcloud.com/host/$($Hostname)?report=hostcache"
    $user = 'readonly'
    $pass = 'readonly'
    $pair = "$($user):$($pass)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $Headers = "Authorization:Basic $encodedCreds"
    
    Write-Verbose "Making API call to A2RM"
    $returnedJSON = & $CurlPath -X GET -s -k -H $Headers $uri
    
    Write-Verbose "Convert the JSON response to a PowerShell object"
    $data = $returnedJSON | ConvertFrom-Json

    Write-Verbose "Extract application instances and all their properties"
    $appInfo = foreach ($instance in $data.'Application-Instances') {
        $appName = $instance.PSObject.Properties.Name
        $appDetails = $instance.$appName
        
        [PSCustomObject]@{
            ApplicationName = $appName
            APMEnabled = $appDetails.'APM-Enabled'
            Environment = $appDetails.Environment
            Region = $appDetails.Region
            Description = $appDetails.Description
            ServiceTier = $appDetails.'Service-Tier'
            BusinessOwner = $appDetails.'Business-Owner'
            TechnicalOwner = $appDetails.'Technical-Owner'
            SupportOwner = $appDetails.'Support-Owner'
            SupportTeam = $appDetails.'Support-Team'
            LifecycleStage = $appDetails.'Lifecycle-Stage'
        }
    }

    return $appInfo
}
