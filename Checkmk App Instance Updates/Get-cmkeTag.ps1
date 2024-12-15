function Get-CmkEtag {
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

    Write-Verbose "Getting etag for host: $($ComputerName)"
    Write-Verbose "API URI: $($uri)"

    try {
        $returnedJSON = & $CurlPath -X GET -s -k -H $Headers $uri
        Write-Verbose "Raw JSON response: $($returnedJSON)"
        $data = $returnedJSON | ConvertFrom-Json
        
        if ($data.status -ne '200') {
            Write-Verbose "Error retriving json data"
            write-Verbose $returnedJSON
            return "Not_found"
        }
        
        $etag = $data.extensions.effective_attributes.meta_data.updated_at
        Write-Verbose "Extracted ETag: $($etag)"

        return $etag
    }
    catch {
        Write-Error "Error getting etag for host $($ComputerName): $($_.Exception.Message)"
        return $null
    }
}
