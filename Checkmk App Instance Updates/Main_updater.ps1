

. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\Get-a2rmapp.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\Get-cmkeTag.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\get-cmklabel.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\get-cmklist.ps1"

$cmklist = 'hkgpotlsql02.corp.ad.tullib.com'

foreach ($cmk in $cmklist){
    $cmkapp = get-appa2rm -ComputerName $cmk
    foreach ($app in $cmkapp.ApplicationName){
        Write-Host $app
    }
    $cmklabel = Get-CmkLabel -ComputerName $cmk
    Write-Host $cmklabel
}