Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = "current.config"
$tempDir = ".\temp"
$langDir = ".\lang"
$logFile = "log.txt"
$loadDriveInfoRunning = Join-Path $tempDir "load_drives_info.running"
$completedFile = Join-Path $tempDir "$letter.completed"
$drivesInfo = Join-Path $tempDir "drives.info"

$tickRate = 1000 #miliseconds
$limit = 180 #times = 3m after 0slotcopying shutdown this script.

$count = 0

# Create form 
$form = New-Object System.Windows.Forms.Form 
$form.Text = "USB Drive Monitor"
$form.Width = 100
$form.Height = 100

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

    # OPTIONAL: Get drives
    if ([string]::IsNullOrWhiteSpace($affectedDrive)) {
        $drives = @()
    } else {
        $drives = $affectedDrive -split ','
    }
    $checkConfig = $true
} else {
    $checkConfig = $false
}

function LoadLocalization($culture = $null) {
    if (-not $culture) {
        #$culture = (Get-Culture).Name  #This will make (LoadLocalization(null)) fall back to System language
        $culture = "en-US"
    }

    $langFile = Join-Path $langDir "${culture}"
    if (Test-Path $langFile) {
        $translations = @{}
        Get-Content $langFile -Encoding UTF8 | ForEach-Object {
            $parts = $_ -split '='
            if ($parts.Count -eq 2) {
                $translations[$parts[0]] = $parts[1]
            }
        }
        return $translations
    }


    $langFile = Join-Path $langDir "${culture}"
    if (Test-Path $langFile) {
        $translations = @{}
        Get-Content $langFile | ForEach-Object {
            $parts = $_ -split '='
            if ($parts.Count -eq 2) {
                $translations[$parts[0]] = $parts[1]
            }
        }
        return $translations
    } else {
        # throw "Language file not found: $langFile"
    }
}

$translations = LoadLocalization $lang

# Function to log to GUI and file
function Log($text) {
    $timestamp = $(Get-Date)
    if (Test-Path $logFile){
        $line = "$timestamp : $text"
        Add-Content -Path $logFile -Value $line
    } else {
        Set-Content -Path $logFile -Value "$timestamp : ${$translations["msg_log_created"]}" -Encoding UTF8
        Log $text
    }
}

if ($checkConfig -eq $false) {
    Log $translations["msg_check_config_err"]
    exit
}

if (-not (Test-Path $loadDriveInfoRunning)) {
    $currentPID = $PID
    Set-Content -Path $loadDriveInfoRunning -Value $currentPID
}

function Update-Status( $textFile, $content) {
    if (Test-Path $textFile) {
        # Read all lines
        $lines = Get-Content $textFile

        if ($lines.Count -gt 0) {
            # Remove the last line
            $lines = $lines[0..($lines.Count - 2)]
        }

        # Add the marker line
        $lines += $content

        # Write back to file
        Set-Content -Path $textFile -Value $lines
    }
}

function Get-FolderSize($path) {
if (-not (Test-Path $path)) { return 0 }
    return (Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
}

function RefreshUsbInfo {
    $lines = @();
    $copyingDrives = 0
    foreach ($letter in $drives) {
        $driveInfo = Get-PSDrive -Name $letter -ErrorAction SilentlyContinue
        $completedFile = Join-Path $tempDir "$letter.completed"
        $infoFile = Join-Path $tempDir "$letter.info"
        $copyingFile = Join-Path $tempDir "$letter.copying"
        # $progressFile = Join-Path $tempDir "$letter.progress"

        # $state:
        # 1: idle (for default)
        # 2: copying
        # 3: completed
        if(Test-Path $copyingFile){
            $state = 2
            $copyingDrives += 1
        }elseif (Test-Path $completedFile){
            $state = 3
        } else{
            $state = 1
        }
        if ($driveInfo) {
            $drive = New-Object System.IO.DriveInfo($driveInfo.Root)
            $volumeName = $drive.VolumeLabel
            $usbSize = Get-FolderSize "$letter`:`\"

            if(Test-Path $infoFile){
                foreach ($line in Get-Content $infoFile) {
                    if ($line -match '=') {
                        $parts = $line -split '='
                        $name = $parts[0].Trim()
                        $value = $parts[1].Trim()
                        Set-Variable -Name $name -Value $value -Scope Global
                    }
                }
                # content of $infoFile will look like this (v2.2):
                # scriptSourceFolder=Full:\path\to\sourceFolder
                # scriptSourceSize=7590331225
                # scriptTotalSpace=8044675072

                #calculate percent
                $percent = if ($scriptSourceSize -gt 0) {
                    [math]::Round(($usbSize / $scriptSourceSize) * 100, 2)
                } else {
                    0
                }
                if ($percent -lt 100){
                    if (Test-Path $completedFile){Remove-Item -Path $completedFile -Force}
                }
                # Set-Content -Path $progessFile -Value $progess

            } else {
                $percent = 0
            }
            $totalSpace = [math]::Round($drive.TotalSize / 1GB, 2)
            # $totalSpace = [math]::Round(($driveInfo.Used + $driveInfo.Free) / 1GB, 2)

            $line = "$letter&$state&$volumeName `($letter`:`)&$percent&$totalSpace GB"
        } else {
            if (Test-Path $completedFile){Remove-Item -Path $completedFile -Force}
            $line = "$letter&$state&$($translations["DISCONNECTED"]) ($letter`:)"
        }
        
        $lines += $line
    }
    #remove all old slotcopying files to re-calculate
    $slotcopyingFiles = Get-ChildItem -Path $tempDir -Filter "*.slotcopying" -ErrorAction SilentlyContinue | Select-Object -First 1

	if ($slotcopyingFiles) { 
        Remove-Item -Path $slotcopyingFiles.FullName -Force -ErrorAction SilentlyContinue 
    }

    New-Item -Path (Join-Path $tempDir "$copyingDrives.slotcopying") -ItemType File -Force | Out-Null
    if ($copyingDrives -eq 0) {
        $script:count += 1
        if ($script:count -ge $limit) {
            if ($autoShutDown -eq "True") {
                Log "Auto shut down when done is triggered."
                # Open shutdown_control.ps1:
                Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File shutdown_control.ps1" -WindowStyle Normal
            }
            CloseForm $form
        }
    } else {
        $script:count = 0
        # $count in script will always reset until there is no copying-drive
    }

    if ($copyingDrives -gt 1){
        $lines += "$copyingDrives $($translations["drives_are_copying"])"
    } else {
        $lines += "$copyingDrives $($translations["drive_is_copying"])"
    }
    $lines += "1_still_updating"
    Set-Content -Path $drivesInfo -Value $lines -Encoding "UTF8"

    # Check if all copy operations are done
}

Function CloseForm {
    param (
        [System.Windows.Forms.Form] $form
    )
    if ($form -and -not $form.IsDisposed) {
        $form.Close()   # Triggers FormClosing event  
    }

    [System.Windows.Forms.Application]::Exit()
    exit
}

# Timer
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $tickRate
$timer.Add_Tick({
    RefreshUsbInfo
})
$timer.Start() 

# Cleanup on close 
$form.Add_FormClosing({ 
    $timer.Stop() 
    Remove-Item $loadDriveInfoRunning -Force -ErrorAction SilentlyContinue 
    # Remove-Item $drivesInfo -Force -ErrorAction SilentlyContinue 
    Update-Status $drivesInfo "2_stopped_updating"

}) 
# Start timer and show form 
$form.ShowDialog()