Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$logFile = "log.txt"
$configFile= "config.txt"
$prototypePath = "prototype"
$newInit = $false # whether config.txt is defined or not ($false => config is exist)
$runIconPath = (Resolve-Path ".\ico\run.ico").Path

# Initialize variables
$sourcePath = $null
$autoShutDown = $false
$autoFormat = $false
$themeBg = "DarkSlateGray"
$themeFg = "Snow"
$checkedBg = "White"
$checkedFg = "Black"
$consoleColors = [System.Enum]::GetNames([System.Drawing.KnownColor])

# Get config Variables
function GetConfig{
    Write-Host "`nCheck the configuration."
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
            }
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Config not found.", "Warning", "OK", "Warning")
    }
}

GetConfig

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Initialization Settings"
$form.Size = New-Object System.Drawing.Size(410, 410)
$form.StartPosition = "Manual"
$form.Location = New-Object System.Drawing.Point(570, 0)
$form.BackColor = $themeBg
$form.ForeColor = $themeFg

# Helper: Create label
function New-Label($text, $x, $y) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text
    $label.Location = New-Object System.Drawing.Point($x, $y)
    $label.Size = New-Object System.Drawing.Size(110, 20)
    return $label
}

# Helper: Create checkbox
function New-Checkbox($text, $x, $y) {
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $text
    $chk.Location = New-Object System.Drawing.Point($x, $y)
    $chk.Size = New-Object System.Drawing.Size(200, 20)
    return $chk
}

# Helper: Create button
function New-Button($text, $x, $y, $clickHandler) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size(200, 30)
    $btn.Add_Click($clickHandler)
    return $btn
}

# Helper: Create submit button
function New-Submit-Button($text, $x, $y, $clickHandler) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size(350, 40)
    $btn.Add_Click($clickHandler)
    return $btn
}

# Source Folder Selection
$form.Controls.Add((New-Button "Select Source Folder" 20 20 {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the source folder"
    $dialog.ShowNewFolderButton = $true

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        
        $script:sourcePath = $dialog.SelectedPath  # Use script scope to persist
        $sourcePathName = Split-Path $sourcePath -Leaf
        $selectedLabel.Text = "Selected : $sourcePathName"
    } 
}))

# Label: selected folder
if ($sourcePath){
    $sourcePathName = Split-Path $sourcePath -Leaf
} else {
    $sourcePathName = "Not selected"
}
$selectedLabel = New-Object System.Windows.Forms.Label
$selectedLabel.Text = "Selected : $sourcePathName"
$selectedLabel.Location = New-Object System.Drawing.Point(20, 60)
$selectedLabel.AutoSize = $true
$form.Controls.Add($selectedLabel)

# Auto Format Checkbox
$chkFormat = New-Checkbox "Auto Format USB" 20 90
$chkFormat.Checked = $autoFormat
$form.Controls.Add($chkFormat)

# Auto Shutdown Checkbox
$chkShutdown = New-Checkbox "Shutdown When Done" 20 110
$chkShutdown.Checked = $autoShutDown
$form.Controls.Add($chkShutdown)

# Sound Settings
$form.Controls.Add((New-Button "Select Error Sound" 20 150 {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "WAV files (*.wav)|*.wav"
    if ($dialog.ShowDialog() -eq "OK") {
        Copy-Item $dialog.FileName -Destination "./sounds/Error.wav" -Force
        [System.Windows.Forms.MessageBox]::Show("Error.wav saved.")
    }
}))

$form.Controls.Add((New-Button "Select Done Sound" 20 190 {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "WAV files (*.wav)|*.wav"
    if ($dialog.ShowDialog() -eq "OK") {
        Copy-Item $dialog.FileName -Destination "./sounds/Done.wav" -Force
        [System.Windows.Forms.MessageBox]::Show("Done.wav saved.")
    }
}))


# Clear Temp Button
$form.Controls.Add((New-Button "Clear Temp Files" 20 230 {
    Remove-Item ".\temp\*.copying","*.slotcopying" -Force -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show("Temp files removed.")
}))

# Add shortcut Button
$form.Controls.Add((New-Button "Add shortcut to Desktop" 20 270 {
    $desktopPath = [System.Environment]::GetFolderPath("Desktop")
    $wshShell = New-Object -ComObject WScript.Shell

    # Shortcut for CheckDrives.cmd
    $checkShortcut = $wshShell.CreateShortcut("$desktopPath\COPITOR.lnk")
    $checkShortcut.TargetPath = (Resolve-Path ".\RUN.cmd").Path
    $checkShortcut.WorkingDirectory = (Get-Location).Path
    $checkShortcut.WindowStyle = 1
    $checkShortcut.Description = "Shortcut to RUN.cmd"
    $checkshortcut.IconLocation = $runIconPath
    $checkShortcut.Save()

    [System.Windows.Forms.MessageBox]::Show("Shortcuts COPITOR.lnk created on desktop.")
}))

# Display Settings
$form.Controls.Add((New-Label "THEME COLOR" 260 20))
$form.Controls.Add((New-Label "Background color:" 260 40))
$bgCombo1 = New-Object System.Windows.Forms.ComboBox
$bgCombo1.Location = New-Object System.Drawing.Point(260, 60)
$bgCombo1.Size = New-Object System.Drawing.Size(110, 20)
$bgCombo1.DropDownStyle = 'DropDownList'
$bgCombo1.Items.AddRange($consoleColors)
$bgCombo1.SelectedItem = $themeBg
# Background color change
$bgCombo1.Add_SelectedIndexChanged({
    $selectedBg = $bgCombo1.SelectedItem
    if ($selectedBg) {
        $form.BackColor = [System.Drawing.Color]::FromName($selectedBg)
    }
})
$form.Controls.Add($bgCombo1)

$form.Controls.Add((New-Label "Foreground color:" 260 90))
$txCombo1 = New-Object System.Windows.Forms.ComboBox
$txCombo1.Location = New-Object System.Drawing.Point(260, 110)
$txCombo1.Size = New-Object System.Drawing.Size(110, 20)
$txCombo1.DropDownStyle = 'DropDownList'
$txCombo1.Items.AddRange($consoleColors)
$txCombo1.SelectedItem = $themeFg
# Foreground color change
$txCombo1.Add_SelectedIndexChanged({
    $selectedFg = $txCombo1.SelectedItem
    if ($selectedFg) {
        $form.ForeColor = [System.Drawing.Color]::FromName($selectedFg)
    }
})
$form.Controls.Add($txCombo1)

# Display Settings
$checkedLabel = New-Object System.Windows.Forms.Label
$checkedLabel.Text = "CHECKED COLOR"
$checkedLabel.Location = New-Object System.Drawing.Point(260, 150)
$checkedLabel.Size = New-Object System.Drawing.Size(110, 20)
$checkedLabel.BackColor = $checkedBg
$checkedLabel.ForeColor = $checkedFg

$form.Controls.Add($checkedLabel)
$form.Controls.Add((New-Label "Background color:" 260 170))
$bgCombo2 = New-Object System.Windows.Forms.ComboBox
$bgCombo2.Location = New-Object System.Drawing.Point(260, 190)
$bgCombo2.Size = New-Object System.Drawing.Size(110, 20)
$bgCombo2.DropDownStyle = 'DropDownList'
$bgCombo2.Items.AddRange($consoleColors)
$bgCombo2.SelectedItem = $checkedBg
# Background color change
$bgCombo2.Add_SelectedIndexChanged({
    $selectedBg = $bgCombo2.SelectedItem
    if ($selectedBg) {
        $checkedLabel.BackColor = [System.Drawing.Color]::FromName($selectedBg)
    }
})
$form.Controls.Add($bgCombo2)

$form.Controls.Add((New-Label "Foreground color:" 260 220))
$txCombo2 = New-Object System.Windows.Forms.ComboBox
$txCombo2.Location = New-Object System.Drawing.Point(260, 240)
$txCombo2.Size = New-Object System.Drawing.Size(110, 20)
$txCombo2.DropDownStyle = 'DropDownList'
$txCombo2.Items.AddRange($consoleColors)
$txCombo2.SelectedItem = $themeFg
# Foreground color change
$txCombo2.Add_SelectedIndexChanged({
    $selectedFg = $txCombo2.SelectedItem
    if ($selectedFg) {
        $checkedLabel.ForeColor = [System.Drawing.Color]::FromName($selectedFg)
    }
})
$form.Controls.Add($txCombo2)

# Check the completeness of the script file
Write-Host "1. Check the completeness of the script file."

$checkCompleteness=$true
if (Test-Path $prototypePath) {
    # Write-Host "prototype.txt found. Checking listed files...`n"

    $fileNames = Get-Content $prototypePath | Where-Object { $_.Trim() -ne "" }
    foreach ($name in $fileNames) {
        $filePath = Join-Path "." $name
        if (Test-Path $filePath) {
            # Write-Host "File exists: $name"
        } else {
            [System.Windows.Forms.MessageBox]::Show("Missing file: $name")
        }
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("prototype.txt not found. Skipping file check.")
}
if (-not (Test-Path "./sounds")) {
    New-Item -ItemType Directory -Path "./sounds" | Out-Null
}

# Save Config Button
$form.Controls.Add((New-Submit-Button "Save Configuration" 20 310 {
    $autoFormat = $chkFormat.Checked
    $autoShutDown = $chkShutdown.Checked
    $themeBg = $bgCombo1.SelectedItem
    $themeFg = $txCombo1.SelectedItem
    $checkedBg = $bgCombo2.SelectedItem
    $checkedFg = $txCombo2.SelectedItem
    
    $configContent = @"
sourceFolder=$sourcePath
autoFormat=$autoFormat
autoShutDown=$autoShutDown
themeBg=$themeBg
themeFg=$themeFg
checkedBg = $checkedBg
checkedFg = $checkedFg
"@
    [System.Windows.Forms.MessageBox]::show("$configContent")
    Remove-Item $configFile -Force -ErrorAction SilentlyContinue
    New-Item $configFile -Force -Value $configContent
    Add-Content "log.txt" "$(Get-Date): Configuration saved."
    Add-Content "log.txt" "________________________________`n"
    [System.Windows.Forms.MessageBox]::Show("Configuration saved.")
}))

# Run the form
$form.ShowDialog()

exit
