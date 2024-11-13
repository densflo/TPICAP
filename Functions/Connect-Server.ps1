function Connect-Server {
    param (  
        [Parameter(Mandatory = $true, HelpMessage = "Server name to connect to.")]
        [String] $ServerName
    )
    try {
        $cred = D:\Thycotic\Get-thycoticCredentials.ps1 -server $ServerName
        $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)
        
        # Directly enter the remote session
        Enter-PSSession -ComputerName $ServerName -Credential $psCred -ErrorAction Stop
    }
    catch {
        Write-Error ("Failed to create remote session for {0}. Error: {1}" -f $ServerName, $_.Exception.Message)
    }
}
