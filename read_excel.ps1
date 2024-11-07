# Load the Excel COM object
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false

# Open the workbook
$workbook = $excel.Workbooks.Open("C:\Users\d_flores\OneDrive - TP ICAP\2024\October\Phantom Servers.xlsx")

# Select the first worksheet
$worksheet = $workbook.Worksheets.Item(1)

# Get the used range of the worksheet
$usedRange = $worksheet.UsedRange

# Convert the data to a CSV string
$csvString = ""
for ($row = 1; $row -le $usedRange.Rows.Count; $row++) {
    $rowData = @()
    for ($col = 1; $col -le $usedRange.Columns.Count; $col++) {
        $cellValue = $usedRange.Cells.Item($row, $col).Text
        $rowData += """$cellValue"""
    }
    $csvString += $rowData -join "," + "`n"
}

# Save the CSV string to a file
$csvString | Out-File -FilePath "C:\Users\d_flores\Desktop\phantom_servers.csv" -Encoding UTF8

# Close the workbook and quit Excel
$workbook.Close($false)
$excel.Quit()

# Release the COM object
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

Write-Host "Excel file has been converted to CSV: C:\Users\d_flores\Desktop\phantom_servers.csv"