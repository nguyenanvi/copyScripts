Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$logFile = "log.txt"
$configFile = "config.txt"
$prototypePath = "prototype"
$newInit = $false
$runIconPath = (Resolve-Path ".\ico\run.ico").Path
$mainWidth = 390
$viewDriveWidth = 250

# Initialize variables
$sourcePath = $null
$autoShutDown = $false
$autoFormat = $false
$themeBg = "DarkSlateBlue"
$themeFg = "WhiteSmoke"
$checkedBg = "Yellow"
$checkedFg = "Maroon"
$consoleColors = [System.Enum]::GetNames([System.Drawing.KnownColor])

# Get config Variables
function GetConfig {
    if (Test-Path $configFile) {
        $configLines = Get-Content $configFile
        foreach ($line in $configLines) {
            if ($line -match "^sourceFolder\s*=") {
                $script:sourcePath = ($line -split "=")[1].Trim()
            } elseif ($line -match "^autoShutDown\s*=") {
                $script:autoShutDown = ($line -split "=")[1].Trim().ToLower() -eq "true"
            } elseif ($line -match "^autoFormat\s*=") {
                $script:autoFormat = ($line -split "=")[1].Trim().ToLower() -eq "true"
            } elseif ($line -match "^themeBg\s*=") {
                $script:themeBg = ($line -split "=")[1].Trim()
            } elseif ($line -match "^themeFg\s*=") {
                $script:themeFg = ($line -split "=")[1].Trim()
            } elseif ($line -match "^checkedBg\s*=") {
                $script:checkedBg = ($line -split "=")[1].Trim()
            } elseif ($line -match "^checkedFg\s*=") {
                $script:checkedFg = ($line -split "=")[1].Trim()
            }elseif ($line -match "^affectedDrive\s*=") {
                $affectedDriveStr = ($line -split "=")[1].Trim()
                if([string]::IsNullOrWhiteSpace($affectedDriveStr)){
                    $script:affectedDrive = @()
                } else {
                    $script:affectedDrive = $affectedDriveStr -split ","
                }
            }
        }
    } else {
        # [System.Windows.Forms.MessageBox]::Show("Config not found.", "Warning", "OK", "Warning")
    }
}

GetConfig

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Initialization Settings"
$form.Size = New-Object System.Drawing.Size(400, 510)
$form.StartPosition = "Manual"
$monitorWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$x = $monitorWidth - $mainWidth - $form.Width - $viewDriveWidth # 250=240+10 is view_drives windows size
$form.Location = New-Object System.Drawing.Point($x, 10)
$form.BackColor = $themeBg
$form.ForeColor = $themeFg
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# Helper functions
function New-Label($text, $x, $y) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text
    $label.Location = New-Object System.Drawing.Point($x, $y)
    $label.Size = New-Object System.Drawing.Size(180, 20)
    return $label
}
function New-Checkbox($text, $x, $y) {
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $text
    $chk.Location = New-Object System.Drawing.Point($x, $y)
    $chk.Size = New-Object System.Drawing.Size(180, 20)
    return $chk
}
function New-Button($text, $x, $y, $clickHandler) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size(170, 40)
    if ($clickHandler) { $btn.Add_Click($clickHandler) }
    return $btn
}
function New-Submit-Button($text, $x, $y, $width, $clickHandler) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($width, 40)
    if ($clickHandler) { $btn.Add_Click($clickHandler) }
    return $btn
}

# Tab control
$tab = New-Object System.Windows.Forms.TabControl
$tab.Size = New-Object System.Drawing.Size(383, 410)
$tab.Location = New-Object System.Drawing.Point(0, 0)

$tab.Appearance = "FlatButtons" # Tab hiển thị như nút phẳng 
$tab.SizeMode = "Fixed"


$tabGeneral = New-Object System.Windows.Forms.TabPage
$tabGeneral.Text = "General"
$tabGeneral.BackColor = $themeBg
$tabGeneral.ForeColor = $themeFg

$tabColor = New-Object System.Windows.Forms.TabPage
$tabColor.Text = "Color"
$tabColor.BackColor = $themeBg
$tabColor.ForeColor = $themeFg

$tabSound = New-Object System.Windows.Forms.TabPage
$tabSound.Text = "Sound"
$tabSound.BackColor = $themeBg
$tabSound.ForeColor = $themeFg

$tab.Controls.Add($tabGeneral)
$tab.Controls.Add($tabColor)
$tab.Controls.Add($tabSound)
$form.Controls.Add($tab)

# -----------------------
# General Tab Controls
# -----------------------


$btnSelectSource = New-Submit-Button "Select Source Folder" 10 30 350 {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the source folder"
    $dialog.ShowNewFolderButton = $true
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:sourcePath = $dialog.SelectedPath
        $sourcePathName = Split-Path $sourcePath -Leaf
        $lblSelected.Text = "Selected source folder : $sourcePathName"
    }
}
$tabGeneral.Controls.Add($btnSelectSource)

# Label selected folder
if ($sourcePath) { $sourcePathName = Split-Path $sourcePath -Leaf } else { $sourcePathName = "<None>" }
$lblSelected = New-Object System.Windows.Forms.Label
$lblSelected.Text = "Selected source folder: $sourcePathName"
$lblSelected.Location = New-Object System.Drawing.Point(10, 10)
$lblSelected.AutoSize = $true
$tabGeneral.Controls.Add($lblSelected)

# Open folder button (mở vị trí thư mục đang lưu tệp này)
$btnOpenFolder = New-Button "Open Current Folder" 190 330 {
    $pathToOpen = (Get-Location).Path
    Start-Process explorer.exe -ArgumentList $pathToOpen
}
$tabGeneral.Controls.Add($btnOpenFolder)

$lblDrives = New-Label "Copy options:" 10 250

# Auto Format Checkbox
$chkFormat = New-Checkbox "Auto Format USB" 10 270
$chkFormat.Checked = $autoFormat

# Auto Shutdown Checkbox
$chkShutdown = New-Checkbox "Shutdown When Done" 10 295
$chkShutdown.Checked = $autoShutDown

$tabGeneral.Controls.Add($chkShutdown)
$tabGeneral.Controls.Add($chkFormat)
$tabGeneral.Controls.Add($lblDrives)
# Clear Temp Button
$btnClearTemp = New-Button "Clear Temp Files" 190 280 {
    Remove-Item ".\temp\*.copying","*.slotcopying" -Force -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show("Temp files removed.")
}
$tabGeneral.Controls.Add($btnClearTemp)

# Add shortcut Button
$btnAddShortcut = New-Button "Add shortcut to Desktop" 190 230 {
    $desktopPath = [System.Environment]::GetFolderPath("Desktop")
    $wshShell = New-Object -ComObject WScript.Shell

    $checkShortcut = $wshShell.CreateShortcut("$desktopPath\COPITOR.lnk")
    $checkShortcut.TargetPath = (Resolve-Path ".\RUN.cmd").Path
    $checkShortcut.WorkingDirectory = (Get-Location).Path
    $checkShortcut.WindowStyle = 1
    $checkShortcut.Description = "Shortcut to RUN.cmd"
    $checkshortcut.IconLocation = $runIconPath
    $checkShortcut.Save()
    [System.Windows.Forms.MessageBox]::Show("Shortcuts COPITOR.lnk created on desktop.")
}
$tabGeneral.Controls.Add($btnAddShortcut)

# Drive checkboxes grid A-Z
$lblDrives = New-Label "Select drives to copy:" 10 80
$tabGeneral.Controls.Add($lblDrives)

# Panel to hold checkboxes
$drivePanel = New-Object System.Windows.Forms.Panel
$drivePanel.Location = New-Object System.Drawing.Point(10, 100)
$drivePanel.Size = New-Object System.Drawing.Size(400, 200)
$drivePanel.AutoScroll = $true
$tabGeneral.Controls.Add($drivePanel)

# Determine system drive letter (without colon)
$systemDriveLetter = $env:SystemDrive.TrimEnd('\').TrimEnd(':')
if ($systemDriveLetter -match "^[A-Za-z]$") {
    $systemDriveLetter = $systemDriveLetter.ToUpper()
} else {
    $systemDriveLetter = "C"
}

# Create checkboxes A..Z in grid (4 columns)
$cols = 5
$colWidth = 75
$rowHeight = 24
$startX = 0
$startY = 0
$index = 0
$driveCheckboxes = @{}

foreach ($charCode in 65..90) {
    $letter = [char]$charCode
    $col = $index % $cols
    $row = [math]::Floor($index / $cols)
    $x = $startX + ($col * $colWidth)
    $y = $startY + ($row * $rowHeight)
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $letter
    $chk.Location = New-Object System.Drawing.Point($x, $y)
    $chk.Size = New-Object System.Drawing.Size(60, 20)
    $chk.Checked = $false
    # Disable and uncheck system drive
    if ($letter -eq $systemDriveLetter) {
        $chk.Enabled = $false
    } elseif ($affectedDrive.Count -gt 0 -and $affectedDrive -contains $letter){
        $chk.Checked = $true
    }
    $drivePanel.Controls.Add($chk)
    $driveCheckboxes[$letter] = $chk
    $index++
}

# -----------------------
# Color Tab Controls
# -----------------------
$tabColor.Controls.Add((New-Label "THEME COLOR" 10 10))
$tabColor.Controls.Add((New-Label "Background color:" 10 40))
$bgCombo1 = New-Object System.Windows.Forms.ComboBox
$bgCombo1.Location = New-Object System.Drawing.Point(10, 60)
$bgCombo1.Size = New-Object System.Drawing.Size(160, 22)
$bgCombo1.DropDownStyle = 'DropDownList'
$bgCombo1.Items.AddRange($consoleColors)
$bgCombo1.SelectedItem = $themeBg
$bgCombo1.Add_SelectedIndexChanged({
    $selectedBg = $bgCombo1.SelectedItem
    if ($selectedBg) { 
        $tabGeneral.BackColor = [System.Drawing.Color]::FromName($selectedBg) 
        $tabColor.BackColor = [System.Drawing.Color]::FromName($selectedBg) 
        $tabSound.BackColor = [System.Drawing.Color]::FromName($selectedBg) 
    }
})
$tabColor.Controls.Add($bgCombo1)

$tabColor.Controls.Add((New-Label "Foreground color:" 200 40))
$txCombo1 = New-Object System.Windows.Forms.ComboBox
$txCombo1.Location = New-Object System.Drawing.Point(200, 60)
$txCombo1.Size = New-Object System.Drawing.Size(160, 22)
$txCombo1.DropDownStyle = 'DropDownList'
$txCombo1.Items.AddRange($consoleColors)
$txCombo1.SelectedItem = $themeFg
$txCombo1.Add_SelectedIndexChanged({
    $selectedFg = $txCombo1.SelectedItem
    if ($selectedFg) { 
        $tabGeneral.ForeColor = [System.Drawing.Color]::FromName($selectedFg) 
        $tabColor.ForeColor = [System.Drawing.Color]::FromName($selectedFg) 
        $tabSound.ForeColor = [System.Drawing.Color]::FromName($selectedFg) 
    }
})
$tabColor.Controls.Add($txCombo1)

# Checked color preview
$checkedLabel = New-Object System.Windows.Forms.Label
$checkedLabel.Text = "CHECKED COLOR"
$checkedLabel.Location = New-Object System.Drawing.Point(10, 110)
$checkedLabel.Size = New-Object System.Drawing.Size(140, 24)
$checkedLabel.BackColor = $checkedBg
$checkedLabel.ForeColor = $checkedFg
$tabColor.Controls.Add($checkedLabel)

$tabColor.Controls.Add((New-Label "Background color:" 10 140))
$bgCombo2 = New-Object System.Windows.Forms.ComboBox
$bgCombo2.Location = New-Object System.Drawing.Point(10, 160)
$bgCombo2.Size = New-Object System.Drawing.Size(160, 22)
$bgCombo2.DropDownStyle = 'DropDownList'
$bgCombo2.Items.AddRange($consoleColors)
$bgCombo2.SelectedItem = $checkedBg
$bgCombo2.Add_SelectedIndexChanged({
    $selectedBg = $bgCombo2.SelectedItem
    if ($selectedBg) { $checkedLabel.BackColor = [System.Drawing.Color]::FromName($selectedBg) }
})
$tabColor.Controls.Add($bgCombo2)

$tabColor.Controls.Add((New-Label "Foreground color:" 200 140))
$txCombo2 = New-Object System.Windows.Forms.ComboBox
$txCombo2.Location = New-Object System.Drawing.Point(200, 160)
$txCombo2.Size = New-Object System.Drawing.Size(160, 22)
$txCombo2.DropDownStyle = 'DropDownList'
$txCombo2.Items.AddRange($consoleColors)
$txCombo2.SelectedItem = $themeFg
$txCombo2.Add_SelectedIndexChanged({
    $selectedFg = $txCombo2.SelectedItem
    if ($selectedFg) { $checkedLabel.ForeColor = [System.Drawing.Color]::FromName($selectedFg) }
})
$tabColor.Controls.Add($txCombo2)

# -----------------------
# Sound Tab Controls
# -----------------------
$btnSelectErrorSound = New-Button "Select Error Sound" 10 10 {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "WAV files (*.wav)|*.wav"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Copy-Item $dialog.FileName -Destination "./sounds/Error.wav" -Force
        [System.Windows.Forms.MessageBox]::Show("Error.wav saved.")
    }
}
$tabSound.Controls.Add($btnSelectErrorSound)

$btnSelectDoneSound = New-Button "Select Done Sound" 10 50 {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "WAV files (*.wav)|*.wav"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Copy-Item $dialog.FileName -Destination "./sounds/Done.wav" -Force
        [System.Windows.Forms.MessageBox]::Show("Done.wav saved.")
    }
}
$tabSound.Controls.Add($btnSelectDoneSound)

# Ensure sounds folder exists
if (-not (Test-Path "./sounds")) { New-Item -ItemType Directory -Path "./sounds" | Out-Null }

# -----------------------
# Prototype completeness check (unchanged)
# -----------------------
Write-Host "1. Check the completeness of the script file."
if (Test-Path $prototypePath) {
    $fileNames = Get-Content $prototypePath | Where-Object { $_.Trim() -ne "" }
    foreach ($name in $fileNames) {
        $filePath = Join-Path "." $name
        if (-not (Test-Path $filePath)) {
            [System.Windows.Forms.MessageBox]::Show("Missing file: $name")
        }
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("prototype.txt not found. Skipping file check.")
}

# -----------------------
# Save Changes handlers for each tab
# -----------------------

# Common save routine (collects UI values and writes config)
function Save-Configuration {
    param($saveDrives)

    $autoFormat = $chkFormat.Checked
    $autoShutDown = $chkShutdown.Checked

    # Colors: prefer selected items, fallback to existing variables
    $themeBg = if ($bgCombo1.SelectedItem) { $bgCombo1.SelectedItem } else { $form.BackColor.Name }
    $themeFg = if ($txCombo1.SelectedItem) { $txCombo1.SelectedItem } else { $form.ForeColor.Name }
    $checkedBg = if ($bgCombo2.SelectedItem) { $bgCombo2.SelectedItem } else { $checkedLabel.BackColor.Name }
    $checkedFg = if ($txCombo2.SelectedItem) { $txCombo2.SelectedItem } else { $checkedLabel.ForeColor.Name }
    # If requested, collect checked drives and append affectedDrive line
    if ($saveDrives) {
        $checkedLetters = @()
        foreach ($kv in $driveCheckboxes.GetEnumerator()) {
            $letter = $kv.Key
            $chk = $kv.Value
            if ($chk.Checked) { $checkedLetters += $letter }
        }
        # $affected = ""
        if ($checkedLetters.Count -gt 0) {
            # $affected = "affectedDrive = " + ($checkedLetters -join ",")
            $listCheckedDrive = ($checkedLetters -join ",")
        } else {
            # $affected = ""
            $listCheckedDrive = ""
        }
        # Add-Content $configFile $affected
    }

    $configContent = @"
sourceFolder=$sourcePath
autoFormat=$autoFormat
autoShutDown=$autoShutDown
themeBg=$themeBg
themeFg=$themeFg
checkedBg=$checkedBg
checkedFg=$checkedFg
affectedDrive=$listCheckedDrive
"@

    # Replace config file
    Remove-Item $configFile -Force -ErrorAction SilentlyContinue
    New-Item $configFile -Force -Value $configContent | Out-Null

    Add-Content $logFile "$(Get-Date): Configuration saved.`n"
    Add-Content $logFile "$(Get-Date): ________________________________`n"
}

# Save Changes button on General tab (also saves drive selections)
$btnSaveGeneral = New-Submit-Button "Save Changes" 10 420 360 {
    Save-Configuration -saveDrives $true
}
$form.Controls.Add($btnSaveGeneral)

# Run the form
$form.ShowDialog()

exit
