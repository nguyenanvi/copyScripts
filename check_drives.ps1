Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$initPath = "initialize.ps1"
$configPath = "config.txt"
$scriptPath = (Get-Location).Path + "\copy_script.ps1"
$logPath = "log.txt"


# Function to log to GUI and file
function Log($text) {
    $timestamp = $(Get-Date)
    $line = "$timestamp : $text"
    Add-Content -Path "log.txt" -Value $line
}

# Read config
if (Test-Path $configPath) {
    Get-Content -Path $configPath | ForEach-Object {
        if ($_ -match '=') {
            $parts = $_ -split '='
            $name = $parts[0].Trim()
            $value = $parts[1].Trim()
            Set-Variable -Name $name -Value $value -Scope Global
        }
    }
    #Log "Found config.txt. Variables are loaded." 
    Log "Checking config files - OK"
} else {
    Log "Checking config files - Missing"
    [System.Windows.Forms.MessageBox]::Show("Config file not found. Setting is needed.", "Error", "OK", "Error")
    exit
}

# Run logic
Log "`nCHECKING DRIVES"
# Source Folder validate
if (-not $sourceFolder -or -not (Test-Path $sourceFolder)) {
    [System.Windows.Forms.MessageBox]::Show("Invalid Source Folder. Setting is needed.", "Error", "OK", "Error")
    exit
}

# Get drives
if ([string]::IsNullOrWhiteSpace($affectedDrive)) {
    $drives = @()
} else {
    $drives = $affectedDrive -split ','
}
foreach ($driveLetter in $drives) {
    $driveRoot = "$driveLetter`:\"
    if (Test-Path $driveRoot) {
        # Log "Found $driveLetter drive."
        if (Test-Path ".\temp\${driveLetter}.copying") {
            Log "$driveLetter`: copying."
        } else {
            Log "$driveLetter`: start script."
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" -letter $driveLetter -sourceFolder `"$sourceFolder`"" -WindowStyle Hidden
            # Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" -letter $driveLetter -sourceFolder `"$sourceFolder`""
        }
    } else {
        Log "$driveLetter`: empty"
    }
}
if ($autoShutDown -eq $true) {
    Log "Warning: Auto-Shutdown is enabled."
    Log "Check your unsaved works"
    Log "before leave the computer."
}
Log "________________________________`n"