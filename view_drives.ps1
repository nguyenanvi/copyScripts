Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$tempDir = ".\temp"
$viewDrivesRunning = ".\temp\view_drives.running"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

if (Test-Path $viewDrivesRunning) {
    $viewDrivesPID= Get-Content $viewDrivesRunning
    [System.Windows.Forms.MessageBox]::Show("Already running. PID: $viewDrivesPID", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit
} else {
    $currentPID = $PID
    Set-Content -Path $viewDrivesRunning -Value $currentPID
}

# Load config.txt
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

# Apply theme
function LoadTheme {
    try {
        if ($form -and $themeBg -and $themeFg) {
            $form.BackColor = [System.Drawing.Color]::FromName($themeBg)
            $form.ForeColor = [System.Drawing.Color]::FromName($themeFg)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Invalid theme colors in config.txt")
    }
}

# Calculate total file size in folder
function Get-FolderSize($path) {
    if (!(Test-Path $path)) { return 0 }
    $size = 0
    Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $size += $_.Length
    }
    return $size
}

# Create drive labels
function Get-USBDriveLabels {
    $labels = @()
    $sourceSize = Get-FolderSize $sourceFolder

    Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 } | ForEach-Object {
        $driveLetter = $_.DeviceID
        $volumeName = $_.VolumeName
        $copyingFile = ".\temp\$($driveLetter.Replace(':','')).copying"
        $usbSize = Get-FolderSize "$driveLetter\"

        $percent = if ($sourceSize -gt 0) {
            [math]::Round(($usbSize / $sourceSize) * 100, 2)
        } else {
            0
        }

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "$driveLetter : $volumeName : $percent%"

        $label.Size = New-Object System.Drawing.Size(160, 20)
        $label.Margin = '3,3,3,3'

        if (Test-Path $copyingFile) {
            $label.BackColor = [System.Drawing.Color]::FromName($checkedBg)
            $label.ForeColor = [System.Drawing.Color]::FromName($checkedFg)
            $label.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        }

        $labels += $label
    }

    return $labels
}

# Refresh panel
function RefreshUSBPanel {
    $usbPanel.Controls.Clear()
    $y = 10
    $drives = Get-USBDriveLabels
    if ($drives.Count -eq 0) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = "No USB drives detected."
        $label.Location = New-Object System.Drawing.Point(10, $y)
        $label.Size = New-Object System.Drawing.Size(160, 20)
        $usbPanel.Controls.Add($label)
    } else {
        foreach ($lbl in $drives) {
            $lbl.Location = New-Object System.Drawing.Point(10, $y)
            $usbPanel.Controls.Add($lbl)
            $y += $lbl.Height + 5
        }
    }
}

# Load config
LoadConfig

# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Drive Monitor & Tools"
$form.Size = New-Object System.Drawing.Size(240, 510)
$form.StartPosition = "Manual"
$form.Location = New-Object System.Drawing.Point(1600, 0)

# Left panel
$leftPanel = New-Object System.Windows.Forms.Panel
$leftPanel.Size = New-Object System.Drawing.Size(200, 460)
$leftPanel.Location = New-Object System.Drawing.Point(10, 10)
$form.Controls.Add($leftPanel)

# Label
$usbLabel = New-Object System.Windows.Forms.Label
$usbLabel.Text = "USB Drives:"
$usbLabel.Location = New-Object System.Drawing.Point(10, 10)
$usbLabel.Size = New-Object System.Drawing.Size(180, 20)
$leftPanel.Controls.Add($usbLabel)

# USB panel
$usbPanel = New-Object System.Windows.Forms.Panel
$usbPanel.Location = New-Object System.Drawing.Point(10, 35)
$usbPanel.Size = New-Object System.Drawing.Size(180, 360)
$usbPanel.AutoScroll = $true
$leftPanel.Controls.Add($usbPanel)

# Refresh button
$refreshBtn = New-Object System.Windows.Forms.Button
$refreshBtn.Text = "Refresh"
$refreshBtn.Size = New-Object System.Drawing.Size(180, 30)
$refreshBtn.Location = New-Object System.Drawing.Point(10, 400)
$refreshBtn.Add_Click({ RefreshUSBPanel })
$leftPanel.Controls.Add($refreshBtn)

# Apply theme
LoadTheme

# Timer
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    $form.Invoke([System.Windows.Forms.MethodInvoker]{ RefreshUSBPanel })
})
$timer.Start()
$form.Add_FormClosing({ 
    $timer.Stop() 
    Remove-Item $viewDrivesRunning -Force -ErrorAction SilentlyContinue
})

# Show form
$form.ShowDialog()
