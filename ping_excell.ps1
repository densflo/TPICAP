# Create Excel COM Object
$Excel = New-Object -ComObject Excel.Application
$Excel.Visible = $false
$Workbook = $Excel.Workbooks.Open("C:\temp\input.xlsx")
$Worksheet = $Workbook.Sheets.Item(1)

# Get the number of rows used
$RowMax = $Worksheet.UsedRange.Rows.Count

# Loop over each row in Column A
For ($Row = 1; $Row -le $RowMax; $Row++) {
    # Read the server name from Column A
    $ServerName = $Worksheet.Cells.Item($Row,1).Text
    if ($ServerName -and $ServerName.Trim() -ne "") {
        Write-Host "Processing server: $ServerName"
        Try {
            # Set a timeout for DNS resolution (5 seconds)
            $task = Start-Job -ScriptBlock {
                param($ServerName)
                [System.Net.Dns]::GetHostEntry($ServerName)
            } -ArgumentList $ServerName

            $result = Wait-Job $task -Timeout 5

            if ($result) {
                $HostEntry = Receive-Job $task
                $ResolvedName = $HostEntry.HostName
                if ($ResolvedName.Contains(".")) {
                    # If resolved to FQDN, write FQDN to Column B
                    $Worksheet.Cells.Item($Row,2).Value = $ResolvedName
                } else {
                    # If resolved to short name, write IP address(es) to Column B
                    $IPAddresses = $HostEntry.AddressList | ForEach-Object { $_.IPAddressToString }
                    $Worksheet.Cells.Item($Row,2).Value = ($IPAddresses -join ", ")
                }
            } else {
                $Worksheet.Cells.Item($Row,2).Value = "resolution timed out"
            }
            Remove-Job $task -Force
        }
        Catch {
            # If resolution fails, write 'not resolvable' to Column B
            $Worksheet.Cells.Item($Row,2).Value = "not resolvable"
        }
    } else {
        # If the cell is empty, leave Column B empty
        $Worksheet.Cells.Item($Row,2).Value = ""
    }
}

# Save and close the workbook
$Workbook.Save()
$Workbook.Close()
$Excel.Quit()

# Release COM objects to free up memory
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($Worksheet) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($Workbook) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel) | Out-Null

# Minimal garbage collection
[gc]::Collect()

Write-Host "DNS lookup completed and results have been written to C:\temp\input.xlsx."