function Get-RemoteSession {
    param (   
        [Parameter(Mandatory = $true, ParameterSetName = "Server", HelpMessage = "Server name to connect to.")]
        [String] $Server
    )
    try {
        # Check if credential script exists
        $credScriptPath = "D:\Thycotic\Get-thycoticCredentials.ps1"
        if (-not (Test-Path $credScriptPath)) {
            throw "Credential retrieval script not found at $credScriptPath"
        }

        $cred = & $credScriptPath -server $server
        $securePassword = ConvertTo-SecureString $cred.password -AsPlainText -Force
        $psCred = New-Object System.Management.Automation.PSCredential ($cred.username, $securePassword)
        return New-PSSession -ComputerName $server -Credential $psCred -ErrorAction Stop
    }
    catch {
        Write-Error ("Failed to create remote session for {0}. Error: {1}" -f $server, $_.Exception.Message)
        return $null
    }
}

# Initialize an array to store server report
$serverReport = @()

# Read servers from input file
$servers = Get-Content -Path "C:\Input\servers.txt"

# Define required files
$requiredFiles = @(
    "ClusterGroupCheck.ps1",
    "ClusterNodeCheck.ps1", 
    "ClusterResourcesCheck.ps1"
)

# Local source directory
$sourceDir = "C:\Input"

foreach ($server in $servers) {
    Write-Host "Processing server: $server"
    
    try {
        # Establish remote session
        $session = Get-RemoteSession -Server $server
        
        if ($session) {
            # Define the target directory on remote computer
            $targetDir = "C:\ProgramData\checkmk\agent\local"
            
            # Check file statuses on remote computer
            $fileCheck = Invoke-Command -Session $session -ScriptBlock {
                param($targetDir, $requiredFiles)
                
                # Ensure target directory exists
                if (-not (Test-Path $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                }
                
                # Check existing files
                $existingFiles = $requiredFiles | Where-Object { Test-Path (Join-Path $targetDir $_) }
                $missingFiles = $requiredFiles | Where-Object { -not (Test-Path (Join-Path $targetDir $_)) }
                
                # Check and delete ClusterAllEventLog.ps1 if exists
                $eventLogFile = Join-Path $targetDir "ClusterAllEventLog.ps1"
                if (Test-Path $eventLogFile) {
                    Remove-Item $eventLogFile -Force
                    Write-Host "Deleted $eventLogFile"
                }
                
                # Return file statuses
                @{
                    ExistingFiles = $existingFiles
                    MissingFiles = $missingFiles
                }
            } -ArgumentList $targetDir, $requiredFiles
            
            # Copy missing files using -ToSession
            if ($fileCheck.MissingFiles) {
                $fileCheck.MissingFiles | ForEach-Object {
                    $sourcePath = Join-Path $sourceDir $_
                    $destPath = Join-Path $targetDir $_
                    
                    Copy-Item -Path $sourcePath -Destination $destPath -ToSession $session -Force
                    Write-Host "Copied $_ to $destPath on $server"
                }
            }
            
            # Recheck files after potential copy
            $finalCheck = Invoke-Command -Session $session -ScriptBlock {
                param($targetDir, $requiredFiles)
                
                $finalExistingFiles = $requiredFiles | Where-Object { Test-Path (Join-Path $targetDir $_) }
                $finalMissingFiles = $requiredFiles | Where-Object { -not (Test-Path (Join-Path $targetDir $_)) }
                
                @{
                    ExistingFiles = $finalExistingFiles
                    MissingFiles = $finalMissingFiles
                }
            } -ArgumentList $targetDir, $requiredFiles
            
            # Prepare server report
            $serverReport += [PSCustomObject]@{
                ServerName = $server
                ExistingFiles = $finalCheck.ExistingFiles
                MissingFiles = $finalCheck.MissingFiles
                Status = if ($finalCheck.MissingFiles.Count -eq 0) { "Compliant" } else { "Non-Compliant" }
            }
            
            # Close the remote session
            Remove-PSSession $session
        }
        else {
            # If session creation failed, add to report
            $serverReport += [PSCustomObject]@{
                ServerName = $server
                ExistingFiles = @()
                MissingFiles = $requiredFiles
                Status = "Session Failed"
            }
        }
    }
    catch {
        Write-Error "Error processing $server : $($_.Exception.Message)"
        
        # Add to report with error status
        $serverReport += [PSCustomObject]@{
            ServerName = $server
            ExistingFiles = @()
            MissingFiles = $requiredFiles
            Status = "Error: $($_.Exception.Message)"
        }
    }
}

# Generate final report
Write-Host "`nFinal Server Report:"
$serverReport | Format-Table -AutoSize

# Optional: Export report to CSV
$reportPath = "C:\Input\ServerClusterFileReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$serverReport | Export-Csv -Path $reportPath -NoTypeInformation

Write-Host "`nReport exported to: $reportPath"
