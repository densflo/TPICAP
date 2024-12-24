function Set-CmkLabels {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [string]$eTag
        [Parameter(Mandatory = $true)]
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
        $returnedJSON = & $CurlPath -X GET -s -k -H $Headers $uri
        Write-Verbose "Raw JSON response: $($returnedJSON)"
        $data = $returnedJSON | ConvertFrom-Json
        Write-Verbose $data
        $label = $data.extensions.effective_attributes.labels
        return $label
    }
    catch {
        Write-Error "Error getting label for host $($ComputerName): $($_.Exception.Message)"
        return $null
    }
}
