# Script to install Check MK Agent on multiple servers and generate installation report
$ErrorActionPreference = "Stop"

# Define paths
$serverListPath = "C:\temp\servers.txt"
$installerPath = "C:\Temp\check_mk\check-mk-agent-2.3.0p11.msi"
$remoteInstallerPath = "C:\Temp\check_mk\check-mk-agent-2.3.0p11.msi"
$reportPath = "C:\temp\check_mk_installation_report.csv"

# Initialize results array
$results = @()

# Check if local installer exists
if (-not (Test-Path $installerPath)) {
    Write-Error "Installer not found at $installerPath"
    exit 1
}

# Read server list
try {
    $servers = Get-Content $serverListPath -ErrorAction Stop
} catch {
    Write-Error "Failed to read server list from $serverListPath. Error: $_"
    exit 1
}

# Function to test server connectivity
function Test-ServerConnection {
    param($ServerName)
    Test-WSMan -ComputerName $ServerName -ErrorAction SilentlyContinue
}

foreach ($server in $servers) {
    $result = [PSCustomObject]@{
        ServerName = $server
        Status = "Not Started"
        ErrorMessage = ""
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    Write-Host "Processing server: $server"

    try {
        # Test if server is accessible
        if (-not (Test-ServerConnection -ServerName $server)) {
            throw "Unable to establish PowerShell remoting connection"
        }

        # Create remote session
        $session = New-PSSession -ComputerName $server

        # Check if CheckMkService is running
        $serviceStatus = Invoke-Command -Session $session -ScriptBlock {
            $service = Get-Service -Name "CheckMkService" -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq "Running") {
                return $true
            }
            return $false
        }

        if ($serviceStatus) {
            Write-Host "CheckMkService is already running on $server, skipping installation..."
            $result.Status = "Skipped - Service Already Running"
            continue
        }

        # Check if remote directory exists, if not create it
        Invoke-Command -Session $session -ScriptBlock {
            if (-not (Test-Path "C:\Temp\check_mk")) {
                New-Item -Path "C:\Temp\check_mk" -ItemType Directory -Force
            }
        }

        # Check if file already exists on remote machine
        $fileExists = Invoke-Command -Session $session -ScriptBlock {
            param($path)
            Test-Path $path
        } -ArgumentList $remoteInstallerPath

        # Copy installer only if it doesn't exist
        if (-not $fileExists) {
            Write-Host "Copying installer to $server..."
            Copy-Item -Path $installerPath -Destination $remoteInstallerPath -ToSession $session -Force
        } else {
            Write-Host "Installer already exists on $server, skipping copy..."
        }

        # Execute installation
        $installResult = Invoke-Command -Session $session -ScriptBlock {
            param($installerPath)
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $installerPath, "/quiet", "/norestart" -Wait -PassThru
            return $process.ExitCode
        } -ArgumentList $remoteInstallerPath

        if ($installResult -eq 0) {
            # Verify service is running after installation
            $serviceRunning = Invoke-Command -Session $session -ScriptBlock {
                $service = Get-Service -Name "CheckMkService" -ErrorAction SilentlyContinue
                if ($service -and $service.Status -eq "Running") {
                    return $true
                }
                return $false
            }

            if ($serviceRunning) {
                $result.Status = "Success"
            } else {
                throw "Installation completed but service is not running"
            }
        } else {
            throw "Installation failed with exit code: $installResult"
        }

    } catch {
        $result.Status = "Failed"
        $result.ErrorMessage = $_.Exception.Message
    } finally {
        if ($session) {
            Remove-PSSession -Session $session
        }
        $results += $result
    }
}

# Export results to CSV
try {
    $results | Export-Csv -Path $reportPath -NoTypeInformation -Force
    Write-Host "Installation report generated at: $reportPath"
} catch {
    Write-Error "Failed to generate report. Error: $_"
}
