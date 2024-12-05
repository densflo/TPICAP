function Get-RemoteSession {
    param (   
        [Parameter(Mandatory = $true, ParameterSetName = "Server", HelpMessage = "Server name to connect to.")]
        [String] $Server
    )
    try {
        # Check if credential script exists
        $credScriptPath = "D:\Thycotic\Get-thycoticCredentials.ps1"
        if (-not (Test-Path $credScriptPath)) {
            throw "Credential retrieval script not found at $credScriptPath"
        }

        $cred = & $credScriptPath -server $server
        $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)
        return New-PSSession -ComputerName $server -Credential $psCred -ErrorAction Stop
    }
    catch {
        Write-Error ("Failed to create remote session for {0}. Error: {1}" -f $server, $_.Exception.Message)
        return $null
    }
}

function Get-RemoteUpdates {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Server
    )

    try {
        # Create remote session
        $session = Get-RemoteSession -Server $Server

        if ($session) {
            # Retrieve updates via remote session
            $updates = Invoke-Command -Session $session -ScriptBlock {
                # Use Windows Update PowerShell module
                Import-Module PSWindowsUpdate -ErrorAction Stop
                
                # Get all updates
                Get-WindowsUpdate | Select-Object Title, Description, KB, Size, IsDownloaded, IsInstalled
            }

            # Close the remote session
            Remove-PSSession $session

            # Display updates in a table
            if ($updates) {
                $updates | Format-Table -AutoSize
            }
            else {
                Write-Host "No updates found on $Server" -ForegroundColor Yellow
            }
        }
        else {
            Write-Error "Could not establish remote session to $Server"
        }
    }
    catch {
        Write-Error "Error retrieving updates from $Server : $($_.Exception.Message)"
    }
}

# Example usage
# Get-RemoteUpdates -Server "YourServerName"
