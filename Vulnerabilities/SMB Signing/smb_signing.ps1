function Get-RemoteSession {
    param (
        [Parameter(Mandatory=$true, ParameterSetName="Server", HelpMessage="PMS Account.")]
        [String] $Server
    )
    Write-Host "Fetching credentials for $Server"
    $cred = D:\Thycotic\Get-thycoticCredentials.ps1 -server $Server
    $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)
    Write-Host "Creating PSSession for $Server"
    return New-PSSession -ComputerName $Server -Credential $psCred
}

$servers = Get-Content 'C:\Input\servers.txt'
$results = @()

Write-Host "Reading servers list and initiating processing"

foreach ($server in $servers) {
    Write-Host "Connecting to $server"
    $session = Get-RemoteSession -Server $server
    
    Write-Host "Executing command on $server"
    $result = Invoke-Command -Session $session -ScriptBlock {
        $registryPath = "HKLM:\System\CurrentControlSet\Services\LanManWorkstation\Parameters"
        $valueName = "RequireSecuritySignature"
        $value = 1
        $type = "DWord"

        Write-Host "Checking registry path on $env:COMPUTERNAME"
        if (Test-Path $registryPath) {
            Write-Host "Registry path exists, updating value"
            Set-ItemProperty -Path $registryPath -Name $valueName -Value $value -Type $type
            $verifyValue = Get-ItemProperty -Path $registryPath -Name $valueName
            if ($verifyValue.RequireSecuritySignature -eq $value) {
                return @{
                    Server = $env:COMPUTERNAME
                    RegistryKey = $valueName
                    Value = $value
                    Type = $type
                    Status = "Written"
                }
            } else {
                return @{
                    Server = $env:COMPUTERNAME
                    RegistryKey = $valueName
                    Value = $null
                    Type = $null
                    Status = "Failed to Write"
                }
            }
        } else {
            return @{
                Server = $env:COMPUTERNAME
                RegistryKey = $null
                Value = $null
                Type = $null
                Status = "Registry path not found"
            }
        }
    }
    Write-Host "Removing PSSession for $server"
    Remove-PSSession $session
    # Add the result to the results array
    $results += $result
}

# Summary Table
Write-Host "Generating Summary Table"
$results | Format-List
