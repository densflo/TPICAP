<#
.SYNOPSIS
    Combines multiple CSV files from ServerLogons directory with source file tracking.

.DESCRIPTION
    This script combines all CSV files from C:\Share\ServerLogons directory into a single CSV file,
    adding a 'SourceFile' column to track which file each row originated from.

.NOTES
    File Name      : combine_csvs.ps1
    Author        : Claude Sonnet
    Directed By   : Jeff Flores
    Creation Date : October 23, 2024
    Purpose       : Consolidate server logon CSV files with source tracking
    
.OUTPUTS
    Creates a combined CSV file named 'ServerLogons_Combined_YYYY-MM-DD.csv' in the script's directory
#>

# Get current date for filename
$date = Get-Date -Format "yyyy-MM-dd"
$outputFile = "ServerLogons_Combined_$date.csv"

# Get all CSV files from the directory
$csvFiles = Get-ChildItem -Path "C:\Share\ServerLogons\*.csv"

# Create an empty array to store all data
$combinedData = @()

# Process each CSV file
foreach ($file in $csvFiles) {
    # Read the CSV content
    $data = Import-Csv -Path $file.FullName
    
    # Add a new column with the source filename
    $data | Add-Member -MemberType NoteProperty -Name "SourceFile" -Value $file.Name
    
    # Add the processed data to our combined array
    $combinedData += $data
}

# Export the combined data to a new CSV file
$combinedData | Export-Csv -Path ".\$outputFile" -NoTypeInformation

Write-Host "Files combined successfully into: $outputFile"
