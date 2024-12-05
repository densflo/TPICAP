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

# Collect local server information
try {
    # Collect OS Version
    $osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
    $osCommonName = Get-OSCommonName -version $osVersion
    
    # Collect Hotfixes
    $hotfixes = Get-HotFix
    
    # Collect additional system information
    $computerSystem = Get-WmiObject Win32_ComputerSystem
    $processor = Get-WmiObject Win32_Processor
    $diskInfo = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
    
    # Add server information to results
    $results += [PSCustomObject]@{
        Server = $env:COMPUTERNAME
        OSVersion = $osCommonName
        Processor = $processor.Name
        TotalMemory = "{0:N2} GB" -f ($computerSystem.TotalPhysicalMemory / 1GB)
        DiskTotalSpace = "{0:N2} GB" -f ($diskInfo.Size / 1GB)
        DiskFreeSpace = "{0:N2} GB" -f ($diskInfo.FreeSpace / 1GB)
        HotFixID = ""
        Description = ""
        InstalledOn = ""
    }
    
    # Add individual hotfix details
    foreach ($hotfix in $hotfixes) {
        $results += [PSCustomObject]@{
            Server = ""
            OSVersion = ""
            Processor = ""
            TotalMemory = ""
            DiskTotalSpace = ""
            DiskFreeSpace = ""
            HotFixID = $hotfix.HotFixID
            Description = $hotfix.Description
            InstalledOn = $hotfix.InstalledOn
        }
    }
}
catch {
    # Catch any unexpected errors
    $results += [PSCustomObject]@{
        Server = $env:COMPUTERNAME
        OSVersion = "Error"
        Processor = ""
        TotalMemory = ""
        DiskTotalSpace = ""
        DiskFreeSpace = ""
        HotFixID = ""
        Description = $_.Exception.Message
        InstalledOn = ""
    }
}

# Ensure the output directory exists
$outputDir = "C:\Output"
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Generate output filename with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputPath = Join-Path -Path $outputDir -ChildPath "LocalServerInfo_$timestamp.csv"

# Export results to CSV
$results | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Local server information has been saved to $outputPath"
