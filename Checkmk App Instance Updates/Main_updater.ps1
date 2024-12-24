

. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\Get-a2rmapp.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\Get-cmkeTag.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\get-cmklabel.ps1"
. "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Checkmk App Instance Updates\get-cmklist.ps1"
Import-Module "C:\Users\d_flores\OneDrive - TP ICAP\Documents\Code\Chekmk-Powershell\CheckMK-PowerShell\CheckMK.psm1" -Force

#$cmklist = get-cmklist
$cmklist = "LDN1WS7001.corp.ad.tullib.com"
$securepassword = ConvertTo-SecureString "BYGBHSUBPQUIYPSYVVSV" -AsPlainText -Force
$connection = Get-CMKConnection -Hostname "cmk-emea" -Sitename "London" -Username 'automation' -Secret $securepassword

foreach ($cmk in $cmklist){
    $cmkapp = get-appa2rm -ComputerName $cmk
    foreach ($app in $cmkapp.ApplicationName){
        Write-Host $app
    }
    $cmklabel = Get-Cmkhostlabel -ComputerName $cmk -Connection $connection
    Write-Host $cmklabel
}