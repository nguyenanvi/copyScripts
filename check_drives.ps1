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
Log "Checking config files"
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
} else {
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
$drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" -and $_.Root -ne "C:\" }

foreach ($drive in $drives) {
    $driveLetter = $drive.Name
    $driveRoot = $drive.Root
    if (Test-Path $driveRoot) {
        # Log "Found $driveLetter drive."
        if (Test-Path ".\temp\${driveLetter}.copying") {
            Log "Found $driveLetter drive is copying."
        } else {
            Log "Start copy to $driveLetter."
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" -letter $driveLetter -sourceFolder `"$sourceFolder`"" -WindowStyle Hidden
        }
    }
}
if ($autoShutDown -eq $true) {
    [System.Windows.Forms.MessageBox]::Show("Warning: Auto-Shutdown is enabled.", "Warning", "OK", "Warning")
    Log "Warning: Auto-Shutdown is enabled."
    Log "Check your unsaved works before leave the computer."
}
Log "________________________________`n"