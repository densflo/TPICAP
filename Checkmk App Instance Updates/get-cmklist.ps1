function get-cmklist {
    [CmdletBinding()]
    param (
    
    )
    
    $user = 'automation'
    $pass = 'BYGBHSUBPQUIYPSYVVSV'
    $CurlPath = "curl.exe"
    $uri = "https://cmk-emea/London/check_mk/api/1.0/domain-types/host_config/collections/all"

    $Headers = @(
        "Authorization: Bearer $user $pass",
        "accept: application/json"
    )

    if ($Verbose) {
        Write-Verbose "API URI: $($uri)"
    }

    try {
        $returnedJSON = & $CurlPath -X GET -s -k -H $Headers $uri
        
            Write-Verbose "Raw JSON response: $($returnedJSON)"
        
        
            $data = $returnedJSON | ConvertFrom-Json
        
        return $data.value.id
    }
    catch {
        Write-Error "Error getting data from API: $($_.Exception.Message)"
        return @{}
    }
}
