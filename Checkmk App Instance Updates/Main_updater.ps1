

. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\Get-a2rmapp.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\Get-cmkeTag.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\get-cmklabel.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\get-cmklist.ps1"

$cmklist =get-cmklist -Verbose

foreach ($cmk in $cmklist){
    $cmklabel = get-cmklabel -ComputerName $cmk -Verbose
    $cmktag = get-cmkeTag -ComputerName $cmk -Verbose
    $cmkapp = get-appa2rm -ComputerName $cmk -Verbose