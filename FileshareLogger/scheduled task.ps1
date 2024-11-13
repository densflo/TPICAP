# Scheduled Task Script for Logconnections.ps1

# Define the full path to the script
$scriptPath = "C:\Scripts\FileshareLogger\Logconnections.ps1"

# Ensure the script directory exists
$scriptDirectory = Split-Path $scriptPath -Parent
if (-not (Test-Path -Path $scriptDirectory -PathType Container)) {
    New-Item -Path $scriptDirectory -ItemType Directory -Force | Out-Null
}

# Create a scheduled task to run the script
$taskName = "Log Server Connections"
$description = "Logs new server connections every 30 minutes"

# Remove existing task if it exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create new scheduled task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

# Create a trigger that runs every 30 minutes
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)

# Use SYSTEM account to ensure it runs regardless of user login
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Description $description

Register-ScheduledTask -TaskName $taskName -InputObject $task

Write-Host "Scheduled task '$taskName' has been created to run Logconnections.ps1 every 30 minutes."
Write-Host "Script location: $scriptPath"
