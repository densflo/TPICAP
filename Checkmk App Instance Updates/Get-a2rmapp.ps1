function get-appa2rm {
    param(
        [Parameter(Position=0)]
        [string]$ComputerName = $env:computername
    )

    $CurlPath = "curl.exe"
    $uri = "https://api.a2rm.direct.tpicapcloud.com/host/$($ComputerName)?report=hostcache"
    $user = 'readonly'
    $pass = 'readonly'
    $pair = "$($user):$($pass)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $Headers = "Authorization:Basic $encodedCreds"
    
    Write-Verbose "Making API call to A2RM"
    $returnedJSON = & $CurlPath -X GET -s -k -H $Headers $uri
    
    Write-Verbose "Received JSON: $returnedJSON"
    
    Write-Verbose "Convert the JSON response to a PowerShell object"
    $data = $returnedJSON | ConvertFrom-Json

    Write-Verbose "Extract all application instance names from the Application-Instances"
    $appInstanceNames = foreach ($instance in $data.'Application-Instances') {
        $instance.PSObject.Properties.Name  # Extracts all keys like "Shavlik - EM Prod"
    }

    Write-Verbose "Return a flat list of all application instance names (removes duplicates, optional)"
    $uniqueAppNames = $appInstanceNames | Sort-Object -Unique
    return $uniqueAppNames
}
