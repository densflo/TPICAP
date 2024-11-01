# Define the action: the PowerShell script to run
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\scripts\logconnections.ps1"

# Define the trigger: every 30 minutes, indefinitely
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration ([TimeSpan]::MaxValue) -Once -At (Get-Date)

# Define the task settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# Create the task
Register-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -TaskName "LogConnectionTask" -Description "Task to run logconnections.ps1 every 30 minutes" -User "SYSTEM" -RunLevel Highest