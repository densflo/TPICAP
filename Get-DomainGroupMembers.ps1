function Get-DomainGroupMembers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Enter the domain\group name to query")]
        [string]$DomainGroup
    )

    try {
        Write-Host "`n[DEBUG] Processing Domain Group: $DomainGroup" -ForegroundColor Cyan
        
        # Split domain and group name
        $domainParts = $DomainGroup -split '\\'
        if ($domainParts.Count -ne 2) {
            Write-Host "[DEBUG] Invalid format - Skipping: $DomainGroup" -ForegroundColor Yellow
            return "Invalid domain\group format. Use 'DOMAIN\GroupName'."
        }
        $domain = $domainParts[0]
        $groupName = $domainParts[1]

        Write-Host "[DEBUG] Domain: $domain" -ForegroundColor Cyan
        Write-Host "[DEBUG] Group Name: $groupName" -ForegroundColor Cyan


        # Path to Thycotic credential script
        $credScriptPath = "D:\Thycotic\Get-thycoticCredentials.ps1"
        if (-not (Test-Path $credScriptPath)) {
            Write-Host "[DEBUG] Credential script not found: $credScriptPath" -ForegroundColor Red
            return "Credential script not found"
        }
        
        # Retrieve credentials
        $cred = & $credScriptPath -server $domain
        $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)

        # Find PDC for the domain
        Write-Host "[DEBUG] Attempting to find PDC for domain: $domain" -ForegroundColor Cyan
        $pdc = (Get-ADDomainController -Server $domain -Credential $psCred).HostName
        Write-Host "[DEBUG] PDC Found: $pdc" -ForegroundColor Cyan

        # Query group members
        Write-Host "[DEBUG] Querying group members from PDC" -ForegroundColor Cyan
        $groupMembers = $null
        try {
        $groupMembers = Get-ADGroupMember -Identity $groupName -Server $pdc -Credential $psCred -ErrorAction Stop| 
            Select-Object Name, SamAccountName, ObjectClass
        }
        catch {
            Write-Host "[DEBUG] Error occurred: $_" -ForegroundColor Red
            Write-Error "Error retrieving group members: $_"
            $groupName = "Failed to retrieve group members"
        }
        # Return results
        return $groupMembers
    }
    catch {
        Write-Host "[DEBUG] Error occurred: $_" -ForegroundColor Red
        Write-Error "Error retrieving group members: $_"
        return $null
    }
}

# Example usage
# Get-DomainGroupMembers -DomainGroup "CONTOSO\Domain Admins"
