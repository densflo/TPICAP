function Get-DomainGroupMembers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Enter the domain\group name to query")]
        [string]$DomainGroup
    )

    try {
        # Split domain and group name
        $domainParts = $DomainGroup -split '\\'
        if ($domainParts.Count -ne 2) {
            throw "Invalid domain\group format. Use 'DOMAIN\GroupName'."
        }
        $domain = $domainParts[0]
        $groupName = $domainParts[1]

        # Path to Thycotic credential script
        $credScriptPath = "D:\Thycotic\Get-thycoticCredentials.ps1"
        
        # Retrieve credentials
        $cred = & $credScriptPath -server $domain
        $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)

        # Find PDC for the domain
        $pdc = (Get-ADDomainController -Domain $domain -Credential $psCred).HostName

        # Query group members
        $groupMembers = Get-ADGroupMember -Identity $groupName -Server $pdc -Credential $psCred | 
            Select-Object Name, SamAccountName, ObjectClass

        # Return results
        return $groupMembers
    }
    catch {
        Write-Error "Error retrieving group members: $_"
        return $null
    }
}

# Example usage
# Get-DomainGroupMembers -DomainGroup "CONTOSO\Domain Admins"
