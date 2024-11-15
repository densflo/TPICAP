<#
.SYNOPSIS
    Generates a comprehensive report of OS versions and installed hotfixes across multiple servers.

.DESCRIPTION
    This script performs the following key tasks:
    - Reads a list of server names from an input file (C:\Input\servers.txt)
    - Establishes remote PowerShell sessions to each server
    - Collects server OS version information
    - Retrieves a list of installed hotfixes for each server
    - Exports the collected information to a CSV report at C:\Output\ServerHotfixReport.csv

.PREREQUISITES
    - PowerShell 5.1 or later
    - Administrative privileges on target servers
    - Thycotic credential retrieval script located at D:\Thycotic\Get-thycoticCredentials.ps1
    - Input file C:\Input\servers.txt containing a list of server names (one per line)
    - Network connectivity to all listed servers
    - Appropriate credentials to establish remote sessions

.PARAMETER None
    This script does not accept direct parameters. Server list is read from the input file.

.OUTPUTS
    CSV file at C:\Output\ServerHotfixReport.csv with the following columns:
    - Server: Name of the server
    - OSVersion: Common name of the Windows Server version
    - HotFixID: Unique identifier for each installed hotfix
    - Description: Description of the hotfix
    - InstalledOn: Date the hotfix was installed

.EXAMPLE
    .\ServerHotfixReport.ps1
    Runs the script and generates the hotfix report for all servers listed in the input file.

.NOTES
    - Requires remote PowerShell session capabilities
    - Uses Thycotic for credential management
    - Handles connection failures and logs them in the output
#>

function Get-RemoteSession {
    param (  
        [Parameter(Mandatory = $true, HelpMessage = "Server name to connect to")]
        [String] $Server
    )
    try {
        # Modify the credential retrieval to match your specific Thycotic script
        $cred = & D:\Thycotic\Get-thycoticCredentials.ps1 -server $server
        $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)
        
        # Create and return the remote session
        $session = New-PSSession -ComputerName $server -Credential $psCred -ErrorAction Stop
        return $session
    }
    catch {
        Write-Error ("Failed to create remote session for {0}. Error: {1}" -f $server, $_.Exception.Message)
        return $null
    }
}

# Function to get the common name of the OS version
function Get-OSCommonName {
    param (
        [string]$version
    )
    switch ($version) {
        {$_ -like "10.0.20348*"} { return "Windows Server 2022" }
        {$_ -like "10.0.17763*"} { return "Windows Server 2019" }
        {$_ -like "10.0.14393*"} { return "Windows Server 2016" }
        {$_ -like "6.3.9600*"}   { return "Windows Server 2012 R2" }
        {$_ -like "6.2.9200*"}   { return "Windows Server 2012" }
        {$_ -like "6.1.7601*"}   { return "Windows Server 2008 R2" }
        default { return "Unknown OS Version" }
    }
}

# Initialize an array to store the results
$results = @()

# Read the list of servers from input file
$servers = Get-Content -Path "C:\Input\servers.txt"

# Process each server
foreach ($server in $servers) {
    Write-Host "Processing server: $server"
    
    try {
        # Establish remote session
        $session = Get-RemoteSession -Server $server
        
        if ($session) {
            # Collect server information using Invoke-Command
            $serverInfo = Invoke-Command -Session $session -ScriptBlock {
                # Collect OS Version
                $osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
                $osCommonName = & { 
                    switch ($osVersion) {
                        {$_ -like "10.0.20348*"} { "Windows Server 2022" }
                        {$_ -like "10.0.17763*"} { "Windows Server 2019" }
                        {$_ -like "10.0.14393*"} { "Windows Server 2016" }
                        {$_ -like "6.3.9600*"}   { "Windows Server 2012 R2" }
                        {$_ -like "6.2.9200*"}   { "Windows Server 2012" }
                        {$_ -like "6.1.7601*"}   { "Windows Server 2008 R2" }
                        default { "Unknown OS Version" }
                    }
                }
                
                # Collect Hotfixes
                $hotfixes = Get-HotFix
                
                return @{
                    OSVersion = $osCommonName
                    Hotfixes = $hotfixes
                }
            }
            
            # Add server information to results
            $results += [PSCustomObject]@{
                Server      = $server
                OSVersion   = $serverInfo.OSVersion
                HotFixID    = ""
                Description = ""
                InstalledOn = ""
            }
            
            # Add individual hotfix details
            foreach ($hotfix in $serverInfo.Hotfixes) {
                $results += [PSCustomObject]@{
                    Server      = ""
                    OSVersion   = ""
                    HotFixID    = $hotfix.HotFixID
                    Description = $hotfix.Description
                    InstalledOn = $hotfix.InstalledOn
                }
            }
            
            # Close the remote session
            Remove-PSSession $session
        }
        else {
            # If session creation failed, add an error entry
            $results += [PSCustomObject]@{
                Server      = $server
                OSVersion   = "Connection Failed"
                HotFixID    = ""
                Description = "Unable to establish remote session"
                InstalledOn = ""
            }
        }
    }
    catch {
        # Catch any unexpected errors
        $results += [PSCustomObject]@{
            Server      = $server
            OSVersion   = "Error"
            HotFixID    = ""
            Description = $_.Exception.Message
            InstalledOn = ""
        }
    }
}

# Ensure the output directory exists
$outputPath = "C:\Output\ServerHotfixReport.csv"
$outputDir = Split-Path -Parent $outputPath
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Export results to CSV
$results | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Server hotfix report has been saved to $outputPath"
