# Set the path to the directory containing the CSV files
$csvPath = "C:\Temp\NewServerConnections"

# Get all CSV files in the directory
$csvFiles = Get-ChildItem -Path $csvPath -Filter *.csv

# Initialize an empty array to store the merged data
$mergedData = @()

# Loop through each CSV file
foreach ($file in $csvFiles) {
    # Read the CSV file
    $csvContent = Import-Csv -Path $file.FullName

    # Add a new column with the filename
    $csvContent | Add-Member -MemberType NoteProperty -Name "SourceFile" -Value $file.Name

    # Add the data to the merged array
    $mergedData += $csvContent
}

# Export the merged data to a new CSV file
$mergedData | Export-Csv -Path "C:\Temp\NewServerConnections\MergedNewServerConnections.csv" -NoTypeInformation

Write-Host "CSV files have been merged successfully. The merged file is located at C:\Temp\NewServerConnections\MergedNewServerConnections.csv"