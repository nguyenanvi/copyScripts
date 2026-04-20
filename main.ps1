Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptName = "COPITOR v2.3"

$lang = ""
$logFile = Join-Path (Get-Location) "log.txt"
$configFile = "current.config"
$defaultConfigFile = "default.config"
$tempDir = ".\temp"
$langDir = ".\lang"
$icoDir = ".\ico"
$loadDrivesInfo = Join-Path (Get-Location) "load_drives_info.ps1"
$checkDrives = Join-Path (Get-Location) "check_drives.ps1"
$mainRunning = Join-Path $tempDir "main.running"
$loadDrivesInfoRunning = Join-Path $tempDir "load_drives_info.running"
$drivesInfo = Join-Path $tempDir "drives.info"
$iconPath = Join-Path $icoDir "run.ico"

$scriptPath = (Get-Location).Path + "\copy_script.ps1"

$drivesUpdateStatus = "" #check if the drives Panel still updating
$drives = @()

function LoadConfig {
    $actualId = (Get-WmiObject Win32_ComputerSystemProduct).UUID
    if (Test-Path $configFile){
        foreach ($line in Get-Content $configFile) {
            if ($line -match '=') {
                $parts = $line -split '='
                $name = $parts[0].Trim()
                $value = $parts[1].Trim()
                Set-Variable -Name $name -Value $value -Scope Global
            }
        }
        if ($computerId -ne $actualId) {
            [System.Windows.Forms.MessageBox]::Show("Config does not match this computer. Removing $configFile...`nCurrent id: $actualId`nSaved id: $computerId")
            Remove-Item $configFile -Force
        # } else {
        #     Write-Host "Config matches this computer. Proceeding..."
        }
    } else {
        Copy-Item -Path $defaultConfigFile -Destination $configFile -Force
        $script:lang = "en-US" #by default
        [System.Windows.Forms.MessageBox]::Show("First time configure is needed. Please open Settings")
    }
    
}

function LoadLanguageFile($culture = $null) {
    if (-not $culture) {
        #$culture = (Get-Culture).Name  #This will make (LoadLanguageFile(null)) fall back to System language
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
    # } else {
    #     # Write-Out "something wrong with languages"
    #     # throw "Language file not found: $langFile"
    }
}

LoadConfig
$translations = LoadLanguageFile $lang

# Function to log to GUI and file
function Log($text) {
    $timestamp = $(Get-Date)
    if (Test-Path $logFile){
        $line = "$timestamp : $text"
        Add-Content -Path $logFile -Value $line
    } else {
        $msg = $script:translations["msg_log_created"]
        Set-Content -Path $logFile -Value "" -Encoding UTF8
        Log $msg
        Log $text
    }
}

# Define Win32 API functions 
Add-Type @" 
using System; 
using System.Runtime.InteropServices; 
public class Win32 { 
[DllImport("user32.dll")] 
public static extern bool SetForegroundWindow(IntPtr hWnd); 
[DllImport("user32.dll")] 
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); 
[DllImport("user32.dll")] 
public static extern IntPtr FindWindow(string lpClassName, string lpWindowName); 
} 
"@

function getOnTop($targetPid){
    # Get the main window handle of the process
    $proc = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
    if ($proc -and $proc.MainWindowHandle -ne 0) {
        $hwnd = $proc.MainWindowHandle

        # Restore if minimized (SW_RESTORE = 9)
        [Win32]::ShowWindow($hwnd, 9) | Out-Null

        # Bring to foreground
        [Win32]::SetForegroundWindow($hwnd) | Out-Null

    } else {
        $msg=$translations["msg_get_on_top_failed"]
        Log "$msg ($targetId)"
    }

}

if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}
if (Test-Path $mainRunning) {
    $mainPid = Get-Content $mainRunning
    $msg=$translations["msg_duplicated_process"]
    Log "$msg (PID: $mainPid)"
    getOnTop ($mainPid)
    exit
} else {
    $currentPID = $PID
    Set-Content -Path $mainRunning -Value $currentPID
}

function LoadTheme {
    if ($form -and $themeBg -and $themeFg) {
        # Apply theme
        $form.BackColor = [System.Drawing.Color]::FromName($themeBg)
        $form.ForeColor = [System.Drawing.Color]::FromName($themeFg)
        $btnCheckDrive.BackColor = [System.Drawing.Color]::FromName($themeFg)
        $btnCheckDrive.ForeColor = [System.Drawing.Color]::FromName($themeBg)
        $logBox.BackColor = [System.Drawing.Color]::FromName($themeBg)
        $logBox.ForeColor = [System.Drawing.Color]::FromName($themeFg)
    }
}

function CloseLoadDrivesInfo {
    if(Test-Path $loadDrivesInfoRunning){
        $ldiPid = Get-Content $loadDrivesInfoRunning
        Stop-Process -Id $ldiPid -Force
        Remove-Item $loadDrivesInfoRunning -Force -ErrorAction SilentlyContinue
        # $str=$translations["msg_close_load_drives_info"]
        # Log "$str (PID: $lriPid)"
    }
}
function LoadDrivesInfo {
    $argument = "-NoProfile -ExecutionPolicy Bypass -File `"$loadDrivesInfo`" "
    Start-Process powershell.exe -ArgumentList $argument -WindowStyle Hidden
    # Log $translations["msg_load_drives_info"]
}

# Create drive labels
$oldDrivesInfoContent = @()
$drivesInfoDiff #flag = true to refresh USB drives list, false will not refresh

function getDrives {
    #if the $driveLetter is in $drives
    if ([string]::IsNullOrWhiteSpace($affectedDrive)) {
        return @()
    } else {
        $drives = $affectedDrive -split ','
        return $drives
    }
}
function Get-USBDriveLabels {
    $labels = @()

    if (Test-Path $drivesInfo){
        $drivesInfoContent = Get-Content $drivesInfo

        # Initialize old content as array
        if (($drivesInfoContent -join "`n") -eq $script:oldDrivesInfoContent) {
            # Log "same"
            $script:drivesInfoDiff = $false
        } else {
            # Log "diff"
            $script:drivesInfoDiff = $true
            $script:oldDrivesInfoContent = $drivesInfoContent -join "`n"
        }

        if ($drivesInfoContent.Count -ge 2) {
            $totalDrives = $drivesInfoContent[-2]
        }

        $script:drivesUpdateStatus = $drivesInfoContent | Select-Object -Last 1
        $lines = $drivesInfoContent | Select-Object -SkipLast 2

        $totalDriveLabel.Text = "$totalDrives"
        if ($drivesUpdateStatus -eq "2_stopped_updating") {
            $label.BackColor = [System.Drawing.Color]::FromArgb(60, 100, 100, 100) 
        }

        # $labels += $totalLinePanel

        foreach($line in $lines){
            $linePanel = New-Object System.Windows.Forms.Panel
            $linePanel.Size = New-Object System.Drawing.Size(200, 27)
            
            $lineArr = $line -split "&"
            $letter = $lineArr[0]
            $state = $lineArr[1]
            $driveName = $lineArr[2]
            if ($lineArr.Length -eq 5){
                $drivePercent = $lineArr[3]
                $driveTotalSpace = $lineArr[4]
            } else {
                $drivePercent = "0"
                $driveTotalSpace = "0.00 GB"
            }
            
            $insertedFile = Join-Path $tempDir "$letter.inserted"
            $removedFile = Join-Path $tempDir "$letter.removed"

            if (Test-Path $insertedFile) {
                $linePanel.add_Paint({
                    param($ssender, $e)
                    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::LightGreen, 2)
                    $e.Graphics.DrawLine($pen, 0, 0, 0, $ssender.Height)
                    $pen.Dispose()
                })
            } elseif (Test-Path $removedFile) {
                $linePanel.add_Paint({
                    param($ssender, $e)
                    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 2)
                    $e.Graphics.DrawLine($pen, 0, 0, 0, $ssender.Height)
                    $pen.Dispose()
                })
                Remove-Item -Path $removedFile -Force -ErrorAction SilentlyContinue
            }

            $lblPercentProgess = New-Object System.Windows.Forms.Label
            $lblPercentProgess.Size = New-Object System.Drawing.Size([int]([math]::Round(2*($drivePercent))), 7)

            # $lblPercentProgess.Anchor = "Top,Left"
            $lblPercentProgess.AutoEllipsis = $true
            $lblPercentProgess.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            
            $lblPercentProgess.Location = New-Object System.Drawing.Point(0, 20)
            $lblPercentProgess.ForeColor = [System.Drawing.Color]::FromName($themeBg)
            $lblPercentProgess.BackColor = [System.Drawing.Color]::FromName($themeFg)
            $lblPercentProgess.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $linePanel.Controls.Add($lblPercentProgess)

            $totalSpaceLabel = New-Object System.Windows.Forms.Label
            $totalSpaceLabel.Text = $driveTotalSpace
            $totalSpaceLabel.Size = New-Object System.Drawing.Size(60, 20)
            
            $totalSpaceLabel.Location = New-Object System.Drawing.Point(140, 0)
            $totalSpaceLabel.ForeColor = [System.Drawing.Color]::FromName($themeFg)
            $totalSpaceLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $totalSpaceLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
            $linePanel.Controls.Add($totalSpaceLabel)

            $driveLabel = New-Object System.Windows.Forms.Label
            $driveLabel.Text = $driveName
            $driveLabel.AutoEllipsis = $true
            $driveLabel.Size = New-Object System.Drawing.Size(140, 20)
            $driveLabel.Location = New-Object System.Drawing.Point(0, 0)
            $driveLabel.ForeColor = [System.Drawing.Color]::FromName($themeFg)
            $driveLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $linePanel.Controls.Add($driveLabel)
            
            if ($state -eq "1") {
                #state: idle
                # $lblPercentProgess.Text = "$($script:translations['usb_state_1'])" + [char]0x2016
                $driveLabel.Text = "$($driveLabel.Text) - $($script:translations['usb_state_1'])"
                $lblPercentProgess.BackColor = [System.Drawing.Color]::FromName($themeFg)
                $lblPercentProgess.ForeColor = [System.Drawing.Color]::FromName($themeBg)

            } elseif ($state -eq "2") {
                #state: copying
                # $lblPercentProgess.Text = "$($script:translations['usb_state_2'])" + [char]0x2026
                $driveLabel.Text = "$($driveLabel.Text) - $($script:translations['usb_state_2'])"

                $linePanel.BackColor = [System.Drawing.Color]::FromName($checkedBg)
                $lblPercentProgess.BackColor = [System.Drawing.Color]::FromName($checkedFg)
                $lblPercentProgess.ForeColor = [System.Drawing.Color]::FromName($checkedBg)
                $totalSpaceLabel.ForeColor = [System.Drawing.Color]::FromName($checkedFg)
                $driveLabel.ForeColor = [System.Drawing.Color]::FromName($checkedFg)
            } elseif ($state -eq "3"){
                #state: done
                $lblPercentProgess.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
                # $lblPercentProgess.Text = "$($script:translations['usb_state_3'])" + [char]0x2713
                $driveLabel.Text = "$($driveLabel.Text) - $($script:translations['usb_state_3'])"

                $linePanel.BackColor = [System.Drawing.Color]::FromName($doneBg)
                $lblPercentProgess.BackColor = [System.Drawing.Color]::FromName($doneFg)
                $lblPercentProgess.ForeColor = [System.Drawing.Color]::FromName($doneBg)
                $totalSpaceLabel.ForeColor = [System.Drawing.Color]::FromName($doneFg)
                $driveLabel.ForeColor = [System.Drawing.Color]::FromName($doneFg)
            }

            # $labels += $label
            $labels += $linePanel
        }
    }
    return $labels
}

# If shortcut not valid, automatically create it to Desktop
$wshShell = New-Object -ComObject WScript.Shell
$newShortcut = $wshShell.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "$scriptName.lnk"))
$newShortcut.TargetPath = (Resolve-Path ".\RUN.cmd").Path
$newShortcut.WorkingDirectory = (Get-Location).Path
$newShortcut.WindowStyle = 1
$newShortcut.Description = "Shortcut to RUN.cmd"
$newShortcut.IconLocation = (Resolve-Path ".\ico\run.ico").Path
$newShortcut.Save()

LoadTheme
CloseLoadDrivesInfo
LoadDrivesInfo
######################

[System.Windows.Forms.MessageBox]::Show($script:translations["msg_welcome"])


# Create main form
$monitorWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$form = New-Object System.Windows.Forms.Form
$form.Text = "COPITOR v2.3"
$form.ClientSize = New-Object System.Drawing.Size(640, 520)
$form.StartPosition = "Manual"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $true   # optional, you can keep or remove

$x = $monitorWidth - $form.Width
$form.Location = New-Object System.Drawing.Point($x, 10)

if (Test-Path $iconPath) { 
    $form.Icon = New-Object System.Drawing.Icon($iconPath) 
} else { 
    $msg=$translations["msg_icon_file_missing"]
    Log "$msg ($iconPath)"
}

# TextBox: log.txt content
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.WordWrap = $true
$logBox.BackColor = [System.Drawing.Color]::FromName($themeBg)
$logBox.ForeColor = [System.Drawing.Color]::FromName($themeFg)
$logBox.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$logBox.Size = New-Object System.Drawing.Size(410, 430)
$logBox.Location = New-Object System.Drawing.Point(220, 10)
$form.Controls.Add($logBox)

# Button: Run CheckDrives.cmd
$btnCheckDrive = New-Object System.Windows.Forms.Button
$btnCheckDrive.Text = $translations["btn_check_drives"]
$btnCheckDrive.Size = New-Object System.Drawing.Size(200, 40)
$btnCheckDrive.Location = New-Object System.Drawing.Point(430, 450)
$btnCheckDrive.Add_Click({
    # Start-Process ".\check_drives.ps1"
    & $checkDrives
    CloseLoadDrivesInfo
    LoadDrivesInfo
    # Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$checkDrives`""
    # Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\check_drives.ps1`""
})
$btnCheckDrive.FlatStyle = 'Flat'
$btnCheckDrive.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnCheckDrive)

$totalLinePanel = New-Object System.Windows.Forms.Panel
$totalLinePanel.Location = New-Object System.Drawing.Point(10, 10)
$totalLinePanel.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($totalLinePanel)

# Copying counter label:
$totalDriveLabel = New-Object System.Windows.Forms.Label
$totalDriveLabel.Size = New-Object System.Drawing.Size(130, 20)
$totalDriveLabel.Location = New-Object System.Drawing.Point(0, 0)
$totalDriveLabel.BackColor = [System.Drawing.Color]::FromName($themeFg)
$totalDriveLabel.ForeColor = [System.Drawing.Color]::FromName($themeBg)
$totalDriveLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$totalLinePanel.Controls.Add($totalDriveLabel)

$refreshBtn = New-Object System.Windows.Forms.Button
$refreshBtn.Text = $translations["btn_refresh"]
$refreshBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$refreshBtn.Size = New-Object System.Drawing.Size(65, 20)
$refreshBtn.Location = New-Object System.Drawing.Point(135, 0)
$refreshBtn.Add_Click({
    Log $translations["btn_refresh"]
    UpdateLog
    RefreshUSBPanel
    CloseLoadDrivesInfo
    LoadDrivesInfo
}) 
$refreshBtn.BackColor = [System.Drawing.Color]::FromName($themeBg)
$refreshBtn.ForeColor = [System.Drawing.Color]::FromName($themeFg)
if ($drivesUpdateStatus -eq "2_stopped_updating") {
    $totalLinePanel.BackColor = [System.Drawing.Color]::FromArgb(60, 100, 100, 100) 
}
$refreshBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$totalLinePanel.Controls.Add($refreshBtn)

# USB panel
$usbPanel = New-Object System.Windows.Forms.Panel
$usbPanel.Location = New-Object System.Drawing.Point(10, 40)
$usbPanel.Size = New-Object System.Drawing.Size(230, 400)
$usbPanel.AutoScroll = $true

$form.Controls.Add($usbPanel)

# Button: Settings
$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = $translations["btn_settings"]
$btnSettings.Size = New-Object System.Drawing.Size(200, 40)
$btnSettings.Location = New-Object System.Drawing.Point(10, 450)

$btnSettings.Add_Click({
    CloseLoadDrivesInfo
    Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\settings.ps1`"" -Wait
    LoadConfig
    $script:translations = LoadLanguageFile $lang
    ReloadFormLanguage
    LoadTheme
    # Float on top
    $mainPid = $PID
    getOnTop($mainPid)
    UpdateLog
    LoadDrivesInfo
})
$btnSettings.FlatStyle = 'Flat'
$form.Controls.Add($btnSettings)

# Button: Clear log.txt
$btnClearLog = New-Object System.Windows.Forms.Button
$btnClearLog.Text = $translations["btn_clear_log"]
$btnClearLog.Size = New-Object System.Drawing.Size(200, 40)
$btnClearLog.Location = New-Object System.Drawing.Point(220, 450)

$btnClearLog.Add_Click({
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue
    Log $translations["msg_log_cleared"]
})
$btnClearLog.FlatStyle = 'Flat'
$form.Controls.Add($btnClearLog)

# Add to form
# $form.Controls.Add($btnUSB)

# Credit panel
$creditPanel = New-Object System.Windows.Forms.LinkLabel
$creditPanel.Location = New-Object System.Drawing.Point(0, 500)
$creditPanel.Size = New-Object System.Drawing.Size(640, 20)
$creditPanel.BackColor = "Black"
$creditPanel.LinkColor = [System.Drawing.Color]::White
$creditPanel.ActiveLinkColor = [System.Drawing.Color]::White 
$creditPanel.VisitedLinkColor = [System.Drawing.Color]::White
$creditPanel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$creditPanel.Padding = New-Object System.Windows.Forms.Padding(10,0,10,0)
$creditPanel.Text = "@nguyenanvi"
$creditPanel.Tag = "https://www.github.com/nguyenanvi"
$creditPanel.Add_LinkClicked({ 
    Start-Process $creditPanel.Tag 
})
$form.Controls.Add($creditPanel)

# Refresh panel
function RefreshUSBPanel {
    $drives = Get-USBDriveLabels

    if ($script:drivesInfoDiff -eq $true){
        $usbPanel.Controls.Clear()
        $y = 0
        if ($drives.Count -eq 0) {
            $label = New-Object System.Windows.Forms.Label
            $label.Text = $translations["lbl_loading_drives"]
            $label.Location = New-Object System.Drawing.Point(0, $y)
            $label.Size = New-Object System.Drawing.Size(200, 20)
            $usbPanel.Controls.Add($label)
        } else {
            foreach ($lbl in $drives) {
                $lbl.Location = New-Object System.Drawing.Point(0, $y)
                $usbPanel.Controls.Add($lbl)
                $y += $lbl.Height + 10
            }
        }
    }
}

function UpdateLog {
    if (Test-Path $logFile) {
        try {
            $logBox.Text = Get-Content "log.txt" -Raw
            $logBox.SelectionStart = $logBox.Text.Length
            $logBox.ScrollToCaret()
        } catch {
            $msg=$translations["msg_error_reading_log"]
            $logBox.Text = "$msg : $_"
        }
    } else {
        $logBox.Text = $translations["msg_log_missing"]
    }
} 

#initialLoad
UpdateLog
LoadTheme

# --- Watcher: Refresh Log ---
# Create a FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = Split-Path $logFile
$watcher.Filter = (Split-Path $logFile -Leaf)
$watcher.NotifyFilter = [System.IO.NotifyFilters]'LastWrite, Size, FileName'

# Event handler for file changes
$onChanged = Register-ObjectEvent $watcher Changed -Action {
    # Ensure we call the function in the UI thread
    $form.Invoke([Action]{ UpdateLog })
}

# Start watching
$watcher.EnableRaisingEvents = $true

# --- Timer: Refresh USB list ---
$tick = 2100 #miliseconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $tick
$timer.Add_Tick({
    $form.Invoke(
        [System.Windows.Forms.MethodInvoker]{ 
            RefreshUSBPanel 
        }
    )
})

$timer.Start()
$form.Add_FormClosing({ 

    # Cleanup UpdateLog watcher
    Unregister-Event -SourceIdentifier $onChanged.Name
    $watcher.Dispose()

    # Cleanup updateUSB drives list timer
    $timer.Stop()
    try {
        Remove-Item $mainRunning -Force -ErrorAction SilentlyContinue
    } catch {
        Log $translations["msg_cleaning_up_failed"]
    }
})
function ReloadFormLanguage {
    $refreshBtn.Text = $translations["btn_refresh"]
    $btnCheckDrive.Text = $translations["btn_check_drives"]
    $btnSettings.Text = $translations["btn_settings"]
    $btnClearLog.Text = $translations["btn_clear_log"]
    $label.Text = $translations["lbl_loading_drives"]
    $logBox.Text = $translations["msg_log_missing"]


}

Register-WmiEvent -Class Win32_VolumeChangeEvent -Action {
    $evt = $Event.SourceEventArgs.NewEvent
    if ($null -eq $evt) {
        Log "WmiEvent: Event received but no details available."
        return
    }

    $eventType = $evt.EventType
    $driveName = $evt.DriveName
    $driveLabel = $driveName.TrimEnd('\').TrimEnd(':')

    # Log "EventType: $eventType, Drive: $driveName"
    $insertedFile = Join-Path $tempDir "$driveLabel.inserted"
    $removedFile = Join-Path $tempDir "$driveLabel.removed"

    switch ($eventType) {
        # 1 { Log "Configuration changed: $driveName" }
        2 { 
            # Log "Drive inserted: $driveName"
            $msg = $translations["msg_inserted"]
            Log "$driveLabel $msg"
            New-Item -Path $insertedFile -ItemType File -Force | Out-Null 
            Remove-Item -Path $removedFile -Force -ErrorAction SilentlyContinue
            
            if ($autoCopyWhenPluggedIn -eq "True") {
                #do run automatically
                foreach ($driveLetter in getDrives) {
                    if ($driveLabel -eq $driveLetter) {
                        $msg=$translations["msg_start_script"]
                        Log "$driveLetter`: $msg."
                        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" -letter $driveLetter -sourceFolder `"$sourceFolder`"" -WindowStyle Hidden
                        # Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" -letter $driveLetter -sourceFolder `"$sourceFolder`""
                    }
                }
            }

        }
        3 { 
            # Log "Drive removed: $driveName" 
            $msg = $translations["msg_removed"]
            Log "$driveLabel $msg"
            New-Item -Path $removedFile -ItemType File -Force | Out-Null 
            Remove-Item -Path $insertedFile -Force -ErrorAction SilentlyContinue 
        }
        # 4 { Log "Docking event" }
        # 5 { Log "Undocking event" }
        default { Log "Unknown event type: $eventType" }
    }
}
# Show the form
$form.ShowDialog()