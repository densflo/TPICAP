# PowerShell Script: Merge-UniqueLogConnections.ps1
# Concatenates CSV log files from C:\logs and records only unique computer names and usernames
# Excludes authentication log files created by logauthentications.ps1

# Define the log directory
$logDirectory = "C:\logs"

# Define the output file path
$outputFile = Join-Path $logDirectory "UniqueConnections_$(Get-Date -Format 'yyyy-MM-dd').csv"

# Ensure the log directory exists
if (-not (Test-Path -Path $logDirectory -PathType Container)) {
    Write-Warning "Log directory $logDirectory does not exist."
    exit
}

# Get all CSV files in the log directory, excluding:
# 1. The output file itself
# 2. Files created by logauthentications.ps1 (starting with ServerLogons_)
$csvFiles = Get-ChildItem -Path $logDirectory -Filter "*.csv" | 
    Where-Object { 
        $_.Name -ne (Split-Path $outputFile -Leaf) -and 
        -not $_.Name.StartsWith("ServerLogons_")
    }

# Check if there are any CSV files to process
if (-not $csvFiles) {
    Write-Host "No CSV files found in $logDirectory to process."
    exit
}

# Import all CSV files and select unique entries based on ComputerName and UserName
$uniqueConnections = $csvFiles | 
    ForEach-Object { Import-Csv $_.FullName } | 
    Select-Object ComputerName, UserName, ShareName, SharePath, ConnectionID, Timestamp | 
    Sort-Object ComputerName, UserName -Unique

# Export unique connections to the output file
$uniqueConnections | Export-Csv -Path $outputFile -NoTypeInformation

# Provide summary information
Write-Host "Processed $($csvFiles.Count) CSV files."
Write-Host "Found $($uniqueConnections.Count) unique connections."
Write-Host "Unique connections saved to $outputFile"
