function Get-RemoteSession {

 

param (   
    [Parameter(Mandatory=$true, ParameterSetName="Server", HelpMessage="PMS Account.")]
    [String] $Server
)

 

    $cred = D:\Thycotic\Get-thycoticCredentials.ps1 -server $server
    $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)
    return New-PSSession -ComputerName $server -Credential $psCred
}