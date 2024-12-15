$verbose = $false

. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\Get-a2rmapp.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\Get-cmkeTag.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\get-cmklabel.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\get-cmklist.ps1"

$user = 'automation'
$pass = 'BYGBHSUBPQUIYPSYVVSV'
$CurlPath = "curl.exe"
$uri = "https://cmk-emea/London/check_mk/api/1.0/domain-types/host_config/collections/all"

$Headers = @(
    "Authorization: Bearer $user $pass",
    "accept: application/json"
)

if ($verbose) {
    Write-Verbose "API URI: $($uri)"
}

try {
    $returnedJSON = & $CurlPath -X GET -s -k -H $Headers $uri
    if ($verbose) {
        Write-Verbose "Raw JSON response: $($returnedJSON)"
    }
    
    Write-Host "Returned JSON: $($returnedJSON)"
    try {
        $data = $returnedJSON | ConvertFrom-Json
    }
    catch {
        Write-Error "Error converting JSON response: $($_.Exception.Message)"
        return @{}
    }
    
    
    return $data.value.id
}
catch {
    Write-Error "Error getting data from API: $($_.Exception.Message)"
    return @{}
}
