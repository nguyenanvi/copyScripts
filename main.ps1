Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$prototypePath = ".\prototype"
$tempDir = ".\temp"
$viewDriveWidth = 250  # 250=240+10 is view_drives windows size

$mainRunning = ".\temp\main.running"
if (-not (Test-Path ".\temp")) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

if (Test-Path $mainRunning) {
    $mainPID = Get-Content $mainRunning
    [System.Windows.Forms.MessageBox]::Show("Already running. PID: $mainPID", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit
} else {
    $currentPID = $PID
    Set-Content -Path "$tempDir/main.running" -Value $currentPID
}

function LoadConfig {
    if (Test-Path "config.txt") {
        foreach ($line in Get-Content "config.txt") {
            if ($line -match '=') {
                $parts = $line -split '='
                $name = $parts[0].Trim()
                $value = $parts[1].Trim()
                Set-Variable -Name $name -Value $value -Scope Global
            }
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("config.txt not found. Please open SETTING")
    }
}

function LoadTheme {
    # Apply theme to form
    try {
        if ($form -and $themeBg -and $themeFg) {
            $form.BackColor = [System.Drawing.Color]::FromName($themeBg)
            $form.ForeColor = [System.Drawing.Color]::FromName($themeFg)
            $logBox.BackColor = [System.Drawing.Color]::FromName($themeBg)
            $logBox.ForeColor = [System.Drawing.Color]::FromName($themeFg)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Invalid theme colors in config.txt")
    }
}
    
LoadConfig

Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\view_drives.ps1`""
# Create main form
$monitorWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$form = New-Object System.Windows.Forms.Form
$form.Text = "COPITOR v2.1"
$form.Size = New-Object System.Drawing.Size(390, 510)
$form.StartPosition = "Manual"
$form.FormBorderStyle = 'FixedDialog'
$x = $monitorWidth - $form.Width - $viewDriveWidth
$form.Location = New-Object System.Drawing.Point($x, 10)

# Right panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Size = New-Object System.Drawing.Size(350, 460)
$panel.Location = New-Object System.Drawing.Point(10, 10)
$form.Controls.Add($panel)

# Button: Run CheckDrives.cmd
$btnCheckDrive = New-Object System.Windows.Forms.Button
$btnCheckDrive.Text = "CHECK DRIVE"
$btnCheckDrive.Size = New-Object System.Drawing.Size(171, 40)
$btnCheckDrive.Location = New-Object System.Drawing.Point(0, 410)
$btnCheckDrive.Add_Click({
    # Start-Process ".\check_drives.ps1"
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\check_drives.ps1`""
    # Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\check_drives.ps1`""
})
$panel.Controls.Add($btnCheckDrive)

# Button: Run Initialize.cmd
$btnInit = New-Object System.Windows.Forms.Button
$btnInit.Text = "SETTING"
$btnInit.Size = New-Object System.Drawing.Size(171, 40)
$btnInit.Location = New-Object System.Drawing.Point(179, 410)
$btnInit.Add_Click({
    # Start-Process ".\Initialize.cmd"
    Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\initialize.ps1`"" -Wait
    Start-Sleep 1
    LoadConfig
    LoadTheme
    
    #restart view_drives
    $runningFile = "./temp/view_drives.running"

    if (Test-Path $runningFile) {
        $pidToKill = Get-Content $runningFile
        try {
            Stop-Process -Id $pidToKill -Force
            Write-Host "Process with PID $pidToKill has been terminated."
        } catch {
            Write-Host "Failed to terminate process with PID $pidToKill. Error: $_"
        }

        try {
            Remove-Item $runningFile -Force
            Write-Host "Clean-up complete: '$runningFile' deleted."
        } catch {
            Write-Host "Failed to delete '$runningFile'. Error: $_"
        }
    } else {
        Write-Host "No running file found at '$runningFile'."
    }

    $runningFile = "./temp/view_drives.running"

    Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\view_drives.ps1`""
})
$panel.Controls.Add($btnInit)

# TextBox: log.txt content
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.WordWrap = $true
$logBox.BackColor = [System.Drawing.Color]::FromName($themeBg)
$logBox.ForeColor = [System.Drawing.Color]::FromName($themeFg)
$logBox.Location = New-Object System.Drawing.Point(0, 0)
$logBox.Size = New-Object System.Drawing.Size(350, 350)
$panel.Controls.Add($logBox)

# Button: Clear log.txt
$btnClearLog = New-Object System.Windows.Forms.Button
$btnClearLog.Text = "CLEAR LOG"
$btnClearLog.Size = New-Object System.Drawing.Size(350, 40)
$btnClearLog.Location = New-Object System.Drawing.Point(0, 360)
$btnClearLog.Add_Click({
    Set-Content "log.txt" "<cleared log>"
})
$panel.Controls.Add($btnClearLog)

# Load theme after add all elements
LoadTheme

# --- Timer: Refresh Log ---
 $timer = New-Object System.Windows.Forms.Timer
 $timer.Interval = 3000
 $timer.Add_Tick({
    # Update log.txt
    if (Test-Path "log.txt") {
        try {
            $logBox.Text = Get-Content "log.txt" -Raw
            $logBox.SelectionStart = $logBox.Text.Length
            $logBox.ScrollToCaret()
        } catch {
            $logBox.Text = "Error reading log.txt: $_"
        }
    } else {
        $logBox.Text = "log.txt not found."
    }
})

$timer.Start()
$form.Add_FormClosing({ 
    $timer.Stop()
    Remove-Item $mainRunning -Force -ErrorAction SilentlyContinue
})

# Show the form
$form.ShowDialog()