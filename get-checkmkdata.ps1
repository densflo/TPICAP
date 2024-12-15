$user = 'automation''automation'
$HOSTNAME = 'LDN1WS7001.corp.ad.tullib.com'
$pass = 'BYGBHSUBPQUIYPSYVVSV'
$CurlPath = "curl.exe"
$uri = "https://cmk-emea/London/check_mk/api/1.0/objects/host_config/$($HOSTNAME)?effective_attributes=true"

# Correct header formatting
$Headers = @(
    "Authorization: Bearer $user $pass",
    "accept: application/json"
)

$returnedJSON = & $CurlPath -X GET -s -k -H $Headers $uri
$data = $returnedJSON | ConvertFrom-Json
$data