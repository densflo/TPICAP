# Script to update PowerShell profile

# Display the current profile path
Write-Host "Current PowerShell profile path: $PROFILE"

# Check if the profile exists, if not, create it
if (!(Test-Path -Path $PROFILE)) {
    Write-Host "Profile does not exist. Creating new profile."
    New-Item -ItemType File -Path $PROFILE -Force
} else {
    Write-Host "Profile already exists."
}

# Define the content to be added to the profile
$contentToAdd = @"

# Load all PowerShell functions from the specified directory
`$functionPath = Join-Path `$env:USERPROFILE 'OneDrive - TP ICAP\Documents\Code\Functions'
if (Test-Path `$functionPath) {
    Get-ChildItem -Path `$functionPath -Filter *.ps1 | ForEach-Object {
        . `$_.FullName
    }
    Write-Host "PowerShell functions from `$functionPath have been loaded."
} else {
    Write-Host "Warning: The specified function path (`$functionPath) does not exist."
}
"@

# Add the content to the profile
Add-Content -Path $PROFILE -Value $contentToAdd

Write-Host "PowerShell profile has been updated. Here's the current content of your profile:"
Get-Content -Path $PROFILE

Write-Host "`nTo load the functions in the current session, run: . `$PROFILE"
Write-Host "For future PowerShell sessions, the functions will be loaded automatically."