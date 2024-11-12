$itemsToCopy = 'D:\Patches\58e606d0-c342-496a-84c9-dd70aa736f1d___Windows-KB890830-x64-V5.117.exe'
$remotePath = 'C:\Temp\'

function Get-RemoteSession {
    param (   
        [Parameter(Mandatory = $true, ParameterSetName = "Server", HelpMessage = "PMS Account.")]
        [String] $Server
    )
    $cred = D:\Thycotic\Get-thycoticCredentials.ps1 -server $server
    $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)
    return New-PSSession -ComputerName $server -Credential $psCred
}


$servers = get-content 'C:\Input\servers.txt'

foreach ($server in $servers) {
    $session = Get-RemoteSession -Server $server
    Invoke-Command -Session $session -ScriptBlock {
        if ((Test-Path 'C:\Temp') -eq $false) {
            New-Item -Path 'C:\Temp' -ItemType Directory -Force
        }  
    }
    foreach ($item in $itemsToCopy) {
        Copy-Item -Path $item -Destination $remotePath -ToSession $session -Recurse -Force
        Start-Sleep -s 15
    }
    Invoke-Command -Session $session -ScriptBlock {
        Unblock-File -Path 'C:\Temp\58e606d0-c342-496a-84c9-dd70aa736f1d___Windows-KB890830-x64-V5.117.exe' 
       Start-Process -Verb RunAs -FilePath 'C:\Temp\58e606d0-c342-496a-84c9-dd70aa736f1d___Windows-KB890830-x64-V5.117.exe' -ArgumentList '/q' -Wait
    }
}


