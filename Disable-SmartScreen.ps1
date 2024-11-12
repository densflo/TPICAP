function Disable-SmartScreenOnServers {
    # Create temp directory if it doesn't exist
    if (-not (Test-Path -Path "C:\temp")) {
        New-Item -ItemType Directory -Path "C:\temp" | Out-Null
    }

    # Create input file for server list
    $inputFile = "C:\temp\input.txt"
    New-Item -Path $inputFile -ItemType File -Force | Out-Null

    # Open the file in Notepad
    Start-Process notepad.exe $inputFile

    # Prompt user
    Write-Host "Notepad is open with C:\temp\input.txt"
    Write-Host "Please add server names, one per line, then save and close Notepad."
    
    # Wait for the file to be modified and closed
    $initialContent = Get-Content $inputFile -Raw
    
    do {
        Start-Sleep -Seconds 2
        $currentContent = Get-Content $inputFile -Raw
    } while ($currentContent -eq $initialContent)

    # Read server list
    $servers = Get-Content $inputFile | Where-Object { $_ -ne "" -and $_ -notlike "#*" }

    if ($servers.Count -eq 0) {
        Write-Error "No servers specified in the input file."
        return
    }

    # Disable SmartScreen on specified servers
    $results = @()
    foreach ($server in $servers) {
        try {
            Write-Host "Attempting to disable SmartScreen on $server"
            
            # Invoke command on remote server
            $result = Invoke-Command -ComputerName $server -ScriptBlock {
                try {
                    # Disable SmartScreen for File Explorer
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value 0 -ErrorAction Stop

                    # Disable SmartScreen for Microsoft Edge (if applicable)
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -Value 0 -ErrorAction Stop

                    # Disable SmartScreen in Windows Defender
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Windows Defender SmartScreen" -Name "EnableSmartScreen" -Value 0 -ErrorAction Stop

                    return @{
                        Server = $env:COMPUTERNAME
                        Status = "Success"
                        Message = "SmartScreen disabled successfully"
                    }
                }
                catch {
                    return @{
                        Server = $env:COMPUTERNAME
                        Status = "Failed"
                        Message = $_.Exception.Message
                    }
                }
            }
            
            $results += $result
        }
        catch {
            $results += @{
                Server = $server
                Status = "ConnectionFailed"
                Message = $_.Exception.Message
            }
        }
    }

    # Display results
    Write-Host "`nDisable SmartScreen Results:"
    $results | Format-Table -AutoSize

    # Optional: Export results to a CSV
    $resultsPath = "C:\temp\SmartScreen_DisableResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $results | Export-Csv -Path $resultsPath -NoTypeInformation
    Write-Host "Detailed results exported to $resultsPath"
}

# Uncomment the line below to run the function
# Disable-SmartScreenOnServers
