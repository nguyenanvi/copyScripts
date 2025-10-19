Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$prototypePath = ".\prototype.txt"

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
        [System.Windows.Forms.MessageBox]::Show("config.txt not found.")
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

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Drive Monitor & Tools"
$form.Size = New-Object System.Drawing.Size(620, 510)
$form.StartPosition = "CenterScreen"

# Left panel
$leftPanel = New-Object System.Windows.Forms.Panel
$leftPanel.Size = New-Object System.Drawing.Size(190, 460)
$leftPanel.Location = New-Object System.Drawing.Point(10, 10)
$form.Controls.Add($leftPanel)

# Right panel
$rightPanel = New-Object System.Windows.Forms.Panel
$rightPanel.Size = New-Object System.Drawing.Size(570, 460)
$rightPanel.Location = New-Object System.Drawing.Point(200, 10)
$form.Controls.Add($rightPanel)

# --- Left Column Buttons ---

# Label: USB Drives
$usbLabel = New-Object System.Windows.Forms.Label
$usbLabel.Text = "USB Drives:"
$usbLabel.Location = New-Object System.Drawing.Point(10, 10)
$usbLabel.Size = New-Object System.Drawing.Size(180, 20)
$leftPanel.Controls.Add($usbLabel)

# ListBox: USB Drives
$usbPanel = New-Object System.Windows.Forms.Panel
$usbPanel.Location = New-Object System.Drawing.Point(10, 30)
$usbPanel.Size = New-Object System.Drawing.Size(180, 150)
$usbPanel.AutoScroll = $true
$leftPanel.Controls.Add($usbPanel)

# Button: Run CheckDrives.cmd
$btnCheckDrive = New-Object System.Windows.Forms.Button
$btnCheckDrive.Text = "CHECK DRIVE"
$btnCheckDrive.Size = New-Object System.Drawing.Size(180, 40)
$btnCheckDrive.Location = New-Object System.Drawing.Point(10, 350)
$btnCheckDrive.Add_Click({
    # Start-Process ".\check_drives.ps1"
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\check_drives.ps1`""
})
$leftPanel.Controls.Add($btnCheckDrive)



# Button: Run Initialize.cmd
$btnInit = New-Object System.Windows.Forms.Button
$btnInit.Text = "SETTING"
$btnInit.Size = New-Object System.Drawing.Size(180, 40)
$btnInit.Location = New-Object System.Drawing.Point(10, 400)
$btnInit.Add_Click({
    # Start-Process ".\Initialize.cmd"
    Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-NoProfile", "-ExecutionPolicy RemoteSigned", "-File `"$PWD\initialize.ps1`"" -Wait
    Start-Sleep 1
    LoadConfig
    LoadTheme
})
$leftPanel.Controls.Add($btnInit)

# --- Right Column: USB List + Log Viewer ---

# Label: Log Viewer
$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = "Log view:"
$logLabel.Location = New-Object System.Drawing.Point(10, 10)
$logLabel.Size = New-Object System.Drawing.Size(350, 20)
$rightPanel.Controls.Add($logLabel)

# TextBox: log.txt content
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.WordWrap = $true
$logBox.BackColor = [System.Drawing.Color]::FromName($themeBg)
$logBox.ForeColor = [System.Drawing.Color]::FromName($themeFg)
$logBox.Location = New-Object System.Drawing.Point(10, 30)
$logBox.Size = New-Object System.Drawing.Size(350, 360)
$rightPanel.Controls.Add($logBox)

# Button: Clear log.txt
$btnClearLog = New-Object System.Windows.Forms.Button
$btnClearLog.Text = "Clear log.txt"
$btnClearLog.Size = New-Object System.Drawing.Size(350, 40)
$btnClearLog.Location = New-Object System.Drawing.Point(10, 400)
$btnClearLog.Add_Click({
    Set-Content "log.txt" ""
    [System.Windows.Forms.MessageBox]::Show("log.txt cleared.")
})
$rightPanel.Controls.Add($btnClearLog)

# Load theme after add all elements
LoadTheme

# --- Timer: Refresh USB + Log ---

function Get-USBDriveLabels {
    $labels = @()

    Get-WmiObject Win32_LogicalDisk |
    Where-Object { $_.DriveType -eq 2 } |
    ForEach-Object {
        $deviceID = $_.DeviceID.Replace(":", "")
        $volumeName = $_.VolumeName
        $copyingFile = "$deviceID.copying"

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "$deviceID`: $volumeName"
        $label.AutoSize = $true
        $label.Margin = '3,3,3,3'

        if (Test-Path $copyingFile) {
            $label.Font = New-Object System.Drawing.Font("", 9, [System.Drawing.FontStyle]::Bold)
            $label.BackColor = [System.Drawing.Color]::LightGray
        }

        $labels += $label
    }

    return $labels
}


$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    # Update USB list
    $usbPanel.Controls.Clear()
    $drives = Get-USBDriveLabels
    if ($drives.Count -eq 0) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = "No USB drives detected."
        $label.Location = New-Object System.Drawing.Point(10, $y)
        $usbPanel.Controls.Add($label)
    } else {
        foreach ($lbl in $drives) {
            $lbl.Location = New-Object System.Drawing.Point(10, $y)
            $usbPanel.Controls.Add($lbl)
            $y += $lbl.Height + 5
        }
    }

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
$form.Add_FormClosing({ $timer.Stop() })

# Show the form
$form.ShowDialog()