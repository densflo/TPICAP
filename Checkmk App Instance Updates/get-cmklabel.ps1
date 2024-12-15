function Get-CmkLabel {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    $user = 'automation'
    $pass = 'BYGBHSUBPQUIYPSYVVSV'
    $CurlPath = "curl.exe"
    $uri = "https://cmk-emea/London/check_mk/api/1.0/objects/host_config/$($ComputerName)?effective_attributes=true"

    $Headers = @(
        "Authorization: Bearer $user $pass",
        "accept: application/json"
    )

    Write-Verbose "Getting label for host: $($ComputerName)"
    Write-Verbose "API URI: $($uri)"

    try {
        $response = & $CurlPath -X GET -s -k -H $Headers $uri -w "%{http_code}"
        $statusCode = $response[-3..-1] -join ""
        $returnedJSON = $response[0..($response.Length - 4)]
        
        if ($statusCode -ne "200") {
            Write-Error "Error: HTTP response status code $($statusCode) for host $($ComputerName)"
            return $null
        }
        
        $data = $returnedJSON | ConvertFrom-Json
        $label = $data.extensions.effective_attributes.labels

        Write-Verbose "Raw JSON response: $($returnedJSON)"
        Write-Verbose "Extracted label: $($label)"

        return $label
    }
    catch {
        Write-Error "Error getting label for host $($ComputerName): $($_.Exception.Message)"
        return $null
    }
}
