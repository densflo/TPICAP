<#
.SYNOPSIS
    Processes a CSV file by concatenating each row's values with semicolons.

.DESCRIPTION
    This script contains a function that reads an input CSV file, handling multi-line fields,
    concatenates all fields in each row with semicolons, and outputs the result to a new file.
    Each processed line is wrapped in quotes and written as a separate row.

.NOTES
    What it does: Concatenates all fields in each CSV row with semicolons, handling quoted and multi-line fields correctly
    Created: May 18, 2023
    Updated: Current Date
    Written by: Cline
    Directed by: Jeff Flores
#>

function Process-CsvLine {
    param (
        [string]$line
    )
    $fields = @()
    $field = ""
    $inQuotes = $false
    $chars = $line.ToCharArray()

    for ($i = 0; $i -lt $chars.Length; $i++) {
        $char = $chars[$i]
        if ($char -eq '"') {
            if ($inQuotes -and $i+1 -lt $chars.Length -and $chars[$i+1] -eq '"') {
                $field += $char
                $i++  # Skip next quote (escaped quote)
            } else {
                $inQuotes = !$inQuotes
            }
        } elseif ($char -eq ',' -and !$inQuotes) {
            $fields += $field
            $field = ""
        } else {
            $field += $char
        }
    }
    $fields += $field  # Add the last field
    return @{
        Fields = $fields
        IsComplete = !$inQuotes
    }
}

function Process-CsvFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputPath,
        
        [Parameter(Mandatory=$true)]
        [string]$Output
    )

    $ErrorActionPreference = 'Stop'
    try {
        # Determine output path
        if ([System.IO.Path]::IsPathRooted($Output)) {
            $OutputPath = $Output
            $OutputDirectory = [System.IO.Path]::GetDirectoryName($OutputPath)
        } else {
            $OutputPath = Join-Path -Path $PWD -ChildPath $Output
            $OutputDirectory = $PWD
        }

        # Ensure output directory exists
        if (-not (Test-Path -Path $OutputDirectory)) {
            New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
        }

        Write-Host "Attempting to read CSV file: $InputPath"
        
        $reader = [System.IO.StreamReader]::new($InputPath)
        $writer = [System.IO.StreamWriter]::new($OutputPath)
        
        $lineCount = 0
        $currentLine = ""
        while (($line = $reader.ReadLine()) -ne $null) {
            $currentLine += if ($currentLine -ne "") { "`n$line" } else { $line }
            $result = Process-CsvLine $currentLine
            
            if ($result.IsComplete) {
                $processedLine = $result.Fields -join ';'
                $writer.WriteLine("`"$processedLine`"")
                
                if ($lineCount -le 5) {
                    Write-Host "Line $lineCount raw input: $currentLine"
                    Write-Host "Line $lineCount processed: `"$processedLine`" (Fields: $($result.Fields.Count))"
                }
                
                if ($lineCount % 1000 -eq 0 -and $lineCount -ne 0) {
                    Write-Host "Processed $lineCount rows..."
                }
                
                $lineCount++
                $currentLine = ""
            }
        }
        
        Write-Host "Rows processed. Total rows: $lineCount"
        Write-Host "Output written to file: $OutputPath"
        Write-Host 'Operation completed successfully.'

        $outputContent = Get-Content $OutputPath
        if ($outputContent.Count -gt 0) {
            Write-Host "First line of output (header): $($outputContent[0])"
            Write-Host "Last line of output: $($outputContent[-1])"
            Write-Host "Total lines in output: $($outputContent.Count)"
        } else {
            Write-Host "Warning: No output lines were generated."
        }

        # Additional debugging information
        Write-Host "First 5 lines of output:"
        $outputContent | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
    } catch {
        Write-Host 'An error occurred:'
        Write-Host $_.Exception.Message
        Write-Host $_.ScriptStackTrace
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($writer) { $writer.Dispose() }
    }
}

# Example usage:
# Process-CsvFile -InputPath "C:\Temp\critservice.csv" -Output "C:\Temp\Processed\critservice_processed.csv"
# Or, to save in the current directory:
# Process-CsvFile -InputPath "C:\Temp\critservice.csv" -Output "critservice_processed_current.csv"
