Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$logFile = "log.txt"
$configFile = "current.config"
$prototypePath = "prototype"
$langDir = "./lang"
$langFiles = Get-ChildItem -Path $langDir -Filter * | Select-Object -ExpandProperty Name
$newInit = $false
$runIconPath = (Resolve-Path ".\ico\run.ico").Path
$shutdownTrigger = Join-Path $tempDir "autoshutdown.enabled"

# Initialize variables
$sourcePath = $null
$autoShutDown = $false
$autoFormat = $false
$themeBg = "DarkSlateBlue"
$themeFg = "WhiteSmoke"
$checkedBg = "Yellow"
$checkedFg = "Maroon"
$doneBg = "DarkGreen"
$doneFg = "Chartreuse"
$lang = "en-US"
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
            } elseif ($line -match "^doneBg\s*=") {
                $script:doneBg = ($line -split "=")[1].Trim()
            } elseif ($line -match "^doneFg\s*=") {
                $script:doneFg = ($line -split "=")[1].Trim()
            } elseif ($line -match "^affectedDrive\s*=") {
                $affectedDriveStr = ($line -split "=")[1].Trim()
                if([string]::IsNullOrWhiteSpace($affectedDriveStr)){
                    $script:affectedDrive = @()
                } else {
                    $script:affectedDrive = $affectedDriveStr -split ","
                }
            } elseif ($line -match "^lang\s*=") {
                $script:lang = ($line -split "=")[1].Trim()
            }
        }
    }
}

GetConfig

function Load-LanguageFile($culture = $null) {
    if (-not $culture) {
        #$culture = (Get-Culture).Name  #This will make (Load-LanguageFile(null)) fall back to System language
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

$translations = Load-LanguageFile $lang

# Function to log to GUI and file
function Log($text) {
    $translation = Load-LanguageFile $lang
    $timestamp = $(Get-Date)
    if (Test-Path $logFile){
        $line = "$timestamp : $text"
        Add-Content -Path $logFile -Value $line
    } else {
        Set-Content -Path $logFile -Value "$timestamp : ${$translations["msg_log_created"]}" -Encoding UTF8
        Log $text
    }
}

# Write-Host "1. Check the completeness of the script file."
if (Test-Path $prototypePath) {
    $fileNames = Get-Content $prototypePath | Where-Object { $_.Trim() -ne "" }
    $fileMissing = @()
    foreach ($name in $fileNames) {
        $filePath = Join-Path "." $name
        if (-not (Test-Path $filePath)) {
            $fileMissing += "$name`n"
        }
    }
    if ($fileMissing.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show("$($translations["msg_missing_file"])`:`n $fileMissing")
    }

} else {
    [System.Windows.Forms.MessageBox]::Show("$($translations["msg_missing_prototype"])")
}

function New-Header($text, $x, $y) {
    # Create a container panel
    $container = New-Object System.Windows.Forms.Panel
    $container.Location = New-Object System.Drawing.Point(($x+10), $y)
    $container.Size = New-Object System.Drawing.Size(($panel.Width-40), 30)

    # Create the label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $translations[$text]
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $label.Dock = 'Fill'
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    # Create bottom border
    $border = New-Object System.Windows.Forms.Panel
    $border.Dock = 'Bottom'
    $border.Height = 1
    $border.Width = ($width)
    $border.BackColor = $themeFg

    # Add both to container
    $container.Controls.Add($label)
    $container.Controls.Add($border)

    return $container
}
function New-Label($text, $x, $y, $width, $height) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $translations[$text]
    $label.Location = New-Object System.Drawing.Point(($x+10), $y)
    $label.Size = New-Object System.Drawing.Size(($width-10), $height)
    $label.Font = New-Object System.Drawing.Font($label.Font, [System.Drawing.FontStyle]::Bold)
    return $label
}

function New-Checkbox($text, $x, $y, $width, $height) {
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $translations[$text]
    $chk.Location = New-Object System.Drawing.Point($x, $y)
    $chk.Size = New-Object System.Drawing.Size($width, $height)
    $chk.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

    # Align checkbox and text vertically at the top 
    $chk.CheckAlign = [System.Drawing.ContentAlignment]::TopLeft 
    $chk.TextAlign = [System.Drawing.ContentAlignment]::TopLeft
    return $chk
}
function New-Button($text, $x, $y, $width, $height, $clickHandler) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $translations[$text]
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($width, $height)
    if ($clickHandler) { $btn.Add_Click($clickHandler) }
    return $btn
}

function RefreshLocalization {
    $script:translations = Load-LanguageFile($lang)
    $form.Text = $translations["form_title"]
    # Label selected folder
    $btnSave.Text = $translations["save_changes"]

    # $copyingHeader.Text = $translations["1_copying"]
    $lblCopyingHeader = $copyingHeader.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] }
    $lblCopyingHeader.Text = $translations["1_copying"]

    $lblSelectSource.Text = $translations["select_source"]
    $btnSelectSource.Text = $translations["select_source_2"]
    $lblDrives.Text = $translations["select_drive_to_copy"]
    foreach ($charCode in 65..90) {
        $letter = [char]$charCode
        $driveCheckboxes[$letter].Text = $translations["$letter"]

    }
    $lblChkBoxes.Text = $translations["copy_options"]
    $chkFormat.Text = $translations["auto_format_usb"]
    $chkShutdown.Text = $translations["shutdown_when_done"]

    # $appearanceHeader.Text = $translations["2_appearance"]
    $lblAppearanceHeader = $appearanceHeader.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] }
    $lblAppearanceHeader.Text = $translations["2_appearance"]

    $lblThemeColor.Text = $translations["THEME_COLOR"]
    $lblThemeBg.Text = $translations["background_color"]
    $lblThemeFg.Text = $translations["foreground_color"]
    $lblCheckedColor.Text = $translations["COPYING_COLOR"]
    $lblCheckedBg.Text = $translations["background_color"]
    $lblCheckedFg.Text = $translations["foreground_color"]
    $lblDoneColor.Text = $translations["DONE_COLOR"]
    $lblDoneBg.Text = $translations["background_color"]
    $lblDoneFg.Text = $translations["foreground_color"]
    # $buggyHeader.Text = $translations["3_buggy_settings"]
    $lblBuggyHeader = $buggyHeader.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] }
    $lblBuggyHeader.Text = $translations["3_buggy_settings"]
    $lblClearTemp.Text = $translations["clear_temp_files_1"]
    $btnClearTemp.Text = $translations["clear_temp_files_2"]
    $lblAddShortcut.Text = $translations["add_shortcut_1"]
    $btnAddShortcut.Text = $translations["add_shortcut_2"]
    $lblOpenFolder.Text = $translations["open_script_folder_1"]
    $btnOpenFolder.Text = $translations["open_script_folder_2"]
    $lblSelectLanguage.Text = $translations["select_language"]
    $lblThemeFg.Text = $translations["foreground_color"]
    $lblThemeFg.Text = $translations["foreground_color"]
    $lblThemeFg.Text = $translations["foreground_color"]

}

function Save-Configuration {
    $computerId = (Get-WmiObject Win32_ComputerSystemProduct).UUID
    $autoFormat = $chkFormat.Checked
    $autoShutDown = $chkShutdown.Checked

    if ($autoShutDown -eq $true) {
        New-Item $shutdownTrigger -ItemType File -Force | Out-Null

    } else {
        Remove-Item $shutdownTrigger -Force -ErrorAction SilentlyContinue
    }

    # Colors: prefer selected items, fallback to existing variables
    $themeBg = if ($bgCombo1.SelectedItem) { $bgCombo1.SelectedItem } else { $form.BackColor.Name }
    $themeFg = if ($fgCombo1.SelectedItem) { $fgCombo1.SelectedItem } else { $form.ForeColor.Name }
    $checkedBg = if ($bgCombo2.SelectedItem) { $bgCombo2.SelectedItem } else { $checkedLabel.BackColor.Name }
    $checkedFg = if ($fgCombo2.SelectedItem) { $fgCombo2.SelectedItem } else { $checkedLabel.ForeColor.Name }
    $doneBg = if ($bgCombo3.SelectedItem) { $bgCombo3.SelectedItem } else { $checkedLabel.BackColor.Name }
    $doneFg = if ($fgCombo3.SelectedItem) { $fgCombo3.SelectedItem } else { $checkedLabel.ForeColor.Name }

    # If requested, collect checked drives and append affectedDrive line
    $checkedLettersRaw = @()
    foreach ($kv in $driveCheckboxes.GetEnumerator()) {
        $letter = $kv.Key
        $chk = $kv.Value
        if ($chk.Checked) { $checkedLettersRaw += $letter }
    }
    $checkedLetters = @() 
    foreach ($charCode in 65..90) { 
        $letter = [char]$charCode 
        if ($checkedLettersRaw -contains $letter) { 
            $checkedLetters += $letter 
        } 
    }
    if ($checkedLetters.Count -gt 0) {
        $affectedDrive = ($checkedLetters -join ",")
    } else {
        $affectedDrive = ""
    }
    $selectedLanguage=$selectLanguage.SelectedItem

    $configContent = @"
computerId=$computerId
sourceFolder=$sourcePath
autoFormat=$autoFormat
autoShutDown=$autoShutDown
themeBg=$themeBg
themeFg=$themeFg
checkedBg=$checkedBg
checkedFg=$checkedFg
doneBg=$doneBg
doneFg=$doneFg
affectedDrive=$affectedDrive
lang=$selectedLanguage
"@

    # Replace config file
    Remove-Item $configFile -Force -ErrorAction SilentlyContinue
    New-Item $configFile -Force -Value $configContent | Out-Null

    $script:translations = Load-LanguageFile $selectedLanguage
    $script:lang = $selectedLanguage
    RefreshLocalization

    Log "$($translations["msg_config_saved"])`n"
    Log "________________________________`n"

    $form.BackColor = $themeBg
    $form.ForeColor = $themeFg
}

GetConfig
$script:translations = Load-LanguageFile($lang)


# DEFINE SOME CONSTANTS
$bthSaveHeight = 40
$mainWidth = 640
$monitorWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = $translations["form_title"]
$form.ClientSize = New-Object System.Drawing.Size(400, 500)
$form.StartPosition = "Manual"
$x = $monitorWidth - $mainWidth - $form.Width
$form.Location = New-Object System.Drawing.Point($x, 10)
$form.BackColor = $themeBg
$form.ForeColor = $themeFg
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# SAVE CHANGE BUTTON
$btnSave = New-Button "save_changes" 10 450 363 40 {
    Save-Configuration
}
$form.Controls.Add($btnSave)

$decorPanel = New-Object System.Windows.Forms.Panel
$decorPanel.Size = New-Object System.Drawing.Size(17, 80)
$decorPanel.Location = New-Object System.Drawing.Point(383, 420)
$decorPanel.BackColor = "Control"
$form.Controls.Add($decorPanel)

# Create the MAIN panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Location = New-Object System.Drawing.Point(0, 10)
$panel.Size = New-Object System.Drawing.Size(400, 430)
$panel.AutoScroll = $true
$form.Controls.Add($panel)
# 1st column :243 ;     2nd column: 100

$copyingHeader = New-Header "1_copying" 0 10
$panel.Controls.Add($copyingHeader)

# Label selected folder
if ($sourcePath) { 
    $sourcePathName = Split-Path $sourcePath -Leaf 
} else { 
    $sourcePathName = "$($translations["none"])"
}
$lblSelectSource = New-Label "select_source" 0 50 243 20
$panel.Controls.Add($lblSelectSource)

$lblSelectedSource = New-Label "" 0 70 363 20
$panel.Controls.Add($lblSelectedSource)
$lblSelectedSource.Text = "($script:sourcePath)"
# $sourcePathName is folder name
# Btn select source Folder
$btnSelectSource = New-Button "select_source_2" 270 50 100 20 {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the source folder"
    $dialog.ShowNewFolderButton = $true
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:sourcePath = $dialog.SelectedPath
        $lblSelectedSource.Text = "Selected: $script:sourcePath"
    }
}
$btnSelectSource.Text = $translations["select_source_2"]
$panel.Controls.Add($btnSelectSource)

# DRIVE CHECKBOXES PANEL
# Determine system drive letter (without colon)
$systemDriveLetter = $env:SystemDrive.TrimEnd('\').TrimEnd(':')
if ($systemDriveLetter -match "^[A-Za-z]$") {
    $systemDriveLetter = $systemDriveLetter.ToUpper()
} else {
    $systemDriveLetter = "C"
}

$lblDrives = New-Label "select_drive_to_copy" 0 100 363 20
$panel.Controls.Add($lblDrives)

$drivePanel = New-Object System.Windows.Forms.Panel
$drivePanel.Location = New-Object System.Drawing.Point(20, 120)
$drivePanel.Size = New-Object System.Drawing.Size(363, 100)
$drivePanel.AutoScroll = $true
$panel.Controls.Add($drivePanel)

# Create Drive checkboxes A..Z in grid
$cols = 7
$rows = 4
# make $cols * $rows always greater than 26

$rowHeight = 25
# $colWidth = [math]::Round(($drivePanel.Width / $cols), 0) # $colWidth = 56
$colWidth = 51

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
    $chk = New-CheckBox "$($letter)" $x $y $colWidth 20

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

$lblChkBoxes = New-Label "copy_options" 0 230 340 20
$panel.Controls.Add($lblChkBoxes)

# Auto Format Checkbox
$chkFormat = New-Checkbox "auto_format_usb" 20 250 160 40
$chkFormat.Checked = $autoFormat
$panel.Controls.Add($chkFormat)

# Auto Shutdown Checkbox
$chkShutdown = New-Checkbox "shutdown_when_done" 185 250 170 40
$chkShutdown.Checked = $autoShutDown
$panel.Controls.Add($chkShutdown)

##################
$appearanceHeader = New-Header "2_appearance" 0 290
$panel.Controls.Add($appearanceHeader)

##################
$lblThemePanel = New-Object System.Windows.Forms.Panel
$lblThemePanel.Location = New-Object System.Drawing.Point(0, 320)
$lblThemePanel.Size = New-Object System.Drawing.Size(383, 85)
$lblThemePanel.BackColor = $themeBg
$lblThemePanel.ForeColor = $themeFg
$panel.Controls.Add($lblThemePanel)

$lblThemeColor = New-Label "THEME_COLOR" 0 10 120 40
$lblThemePanel.Controls.Add($lblThemeColor)

$lblThemeBg = New-Label "background_color" 150 10 110 20
$lblThemePanel.Controls.Add($lblThemeBg)

$bgCombo1 = New-Object System.Windows.Forms.ComboBox
$bgCombo1.Location = New-Object System.Drawing.Point(270, 10)
$bgCombo1.Size = New-Object System.Drawing.Size(100, 20)
$bgCombo1.DropDownStyle = 'DropDownList'
$chk.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$bgCombo1.Items.AddRange($consoleColors)
$bgCombo1.SelectedItem = $themeBg
$bgCombo1.Add_SelectedIndexChanged({
    $selectedBg = $bgCombo1.SelectedItem
    if ($selectedBg) { 
        $lblThemePanel.BackColor = [System.Drawing.Color]::FromName($selectedBg) 
    }
})
$lblThemePanel.Controls.Add($bgCombo1)

$lblThemeFg = New-Label "foreground_color" 150 50 110 20
$lblThemePanel.Controls.Add($lblThemeFg)

$fgCombo1 = New-Object System.Windows.Forms.ComboBox
$fgCombo1.Location = New-Object System.Drawing.Point(270, 50)
$fgCombo1.Size = New-Object System.Drawing.Size(100, 20)
$fgCombo1.DropDownStyle = 'DropDownList'
$fgCombo1.Items.AddRange($consoleColors)
$fgCombo1.SelectedItem = $themeFg
$fgCombo1.Add_SelectedIndexChanged({
    $selectedFg = $fgCombo1.SelectedItem
    $lblThemePanel.ForeColor = [System.Drawing.Color]::FromName($selectedFg) 
})
$lblThemePanel.Controls.Add($fgCombo1)

#####################
$lblCheckedPanel = New-Object System.Windows.Forms.Panel
$lblCheckedPanel.Location = New-Object System.Drawing.Point(0, 405)
$lblCheckedPanel.Size = New-Object System.Drawing.Size(383, 85)
$lblCheckedPanel.BackColor = $checkedBg
$lblCheckedPanel.ForeColor = $checkedFg
$panel.Controls.Add($lblCheckedPanel)

$lblCheckedColor = New-Label "COPYING_COLOR" 0 10 120 40
$lblCheckedPanel.Controls.Add($lblCheckedColor)

$lblCheckedBg = New-Label "background_color" 150 10 110 20
$lblCheckedPanel.Controls.Add($lblCheckedBg)

$bgCombo2 = New-Object System.Windows.Forms.ComboBox
$bgCombo2.Location = New-Object System.Drawing.Point(270, 10)
$bgCombo2.Size = New-Object System.Drawing.Size(100, 20)
$bgCombo2.DropDownStyle = 'DropDownList'
$bgCombo2.Items.AddRange($consoleColors)
$bgCombo2.SelectedItem = $checkedBg
$bgCombo2.Add_SelectedIndexChanged({
    $selectedBg = $bgCombo2.SelectedItem
    if ($selectedBg) { 
        $lblCheckedPanel.BackColor = [System.Drawing.Color]::FromName($selectedBg) 
    }
})
$lblCheckedPanel.Controls.Add($bgCombo2)

$lblCheckedFg = New-Label "foreground_color" 150 50 110 20
$lblCheckedPanel.Controls.Add($lblCheckedFg)

$fgCombo2 = New-Object System.Windows.Forms.ComboBox
$fgCombo2.Location = New-Object System.Drawing.Point(270, 50)
$fgCombo2.Size = New-Object System.Drawing.Size(100, 20)
$fgCombo2.DropDownStyle = 'DropDownList'
$fgCombo2.Items.AddRange($consoleColors)
$fgCombo2.SelectedItem = $checkedFg
$fgCombo2.Add_SelectedIndexChanged({
    $selectedFg = $fgCombo2.SelectedItem
    $lblCheckedPanel.ForeColor = [System.Drawing.Color]::FromName($selectedFg) 
})
$lblCheckedPanel.Controls.Add($fgCombo2)

#####################
$lblDonePanel = New-Object System.Windows.Forms.Panel
$lblDonePanel.Location = New-Object System.Drawing.Point(0, 490)
$lblDonePanel.Size = New-Object System.Drawing.Size(383, 85)
$lblDonePanel.BackColor = $doneBg
$lblDonePanel.ForeColor = $doneFg
$panel.Controls.Add($lblDonePanel)

$lblDoneColor = New-Label "DONE_COLOR" 0 10 120 40
$lblDonePanel.Controls.Add($lblDoneColor)

$lblDoneBg = New-Label "background_color" 150 10 110 20
$lblDonePanel.Controls.Add($lblDoneBg)

$bgCombo3 = New-Object System.Windows.Forms.ComboBox
$bgCombo3.Location = New-Object System.Drawing.Point(270, 10)
$bgCombo3.Size = New-Object System.Drawing.Size(100, 20)
$bgCombo3.DropDownStyle = 'DropDownList'
$bgCombo3.Items.AddRange($consoleColors)
$bgCombo3.SelectedItem = $doneBg
$bgCombo3.Add_SelectedIndexChanged({
    $selectedBg = $bgCombo3.SelectedItem
    if ($selectedBg) { 
        $lblDonePanel.BackColor = [System.Drawing.Color]::FromName($selectedBg) 
    }
})
$lblDonePanel.Controls.Add($bgCombo3)

$lblDoneFg = New-Label "foreground_color" 150 50 110 20
$lblDonePanel.Controls.Add($lblDoneFg)

$fgCombo3 = New-Object System.Windows.Forms.ComboBox
$fgCombo3.Location = New-Object System.Drawing.Point(270, 50)
$fgCombo3.Size = New-Object System.Drawing.Size(100, 20)
$fgCombo3.DropDownStyle = 'DropDownList'
$fgCombo3.Items.AddRange($consoleColors)
$fgCombo3.SelectedItem = $doneFg
$fgCombo3.Add_SelectedIndexChanged({
    $selectedFg = $fgCombo3.SelectedItem
    $lblDonePanel.ForeColor = [System.Drawing.Color]::FromName($selectedFg) 
})
$lblDonePanel.Controls.Add($fgCombo3)

#####################

$buggyHeader = New-Header "3_buggy_settings" 0 590
$panel.Controls.Add($buggyHeader)

$lblClearTemp = New-Label "clear_temp_files_1" 0 630 243 20
$panel.Controls.Add($lblClearTemp)

# CLEAR TEMP BTN
$btnClearTemp = New-Button "clear_temp_files_2"  270 630 100 20 {
    Remove-Item ".\temp\*.copying",".\temp\*.slotcopying",".\temp\*.info" -Force -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show($translations["msg_temp_files_removed"])
}
$panel.Controls.Add($btnClearTemp)

#ADD SHORTCUT BTN
$lblAddShortcut = New-Label "add_shortcut_1" 0 660 243 20
$panel.Controls.Add($lblAddShortcut)

$btnAddShortcut = New-Button "add_shortcut_2" 270 660 100 20 {
    $desktopPath = [System.Environment]::GetFolderPath("Desktop")
    $wshShell = New-Object -ComObject WScript.Shell

    $checkShortcut = $wshShell.CreateShortcut("$desktopPath\COPITOR.lnk")
    $checkShortcut.TargetPath = (Resolve-Path ".\RUN.cmd").Path
    $checkShortcut.WorkingDirectory = (Get-Location).Path
    $checkShortcut.WindowStyle = 1
    $checkShortcut.Description = "Shortcut to RUN.cmd"
    $checkshortcut.IconLocation = $runIconPath
    $checkShortcut.Save()
    [System.Windows.Forms.MessageBox]::Show($translations["msg_shortcut_added"])
}
$panel.Controls.Add($btnAddShortcut)

# OPEN COPITOR's FOLDER BTN
$lblOpenFolder = New-Label "open_script_folder_1" 0 690 243 20
$panel.Controls.Add($lblOpenFolder)

$btnOpenFolder = New-Button "open_script_folder_2" 270 690 100 20{
    $pathToOpen = (Get-Location).Path
    Start-Process explorer.exe -ArgumentList $pathToOpen
}
$panel.Controls.Add($btnOpenFolder)

# LANGUAGE SETTINGs
$lblSelectLanguage = New-Label "select_language" 0 720 243 20
$panel.Controls.Add($lblSelectLanguage)

$selectLanguage = New-Object System.Windows.Forms.ComboBox
$selectLanguage.Location = New-Object System.Drawing.Point(270,720)
$selectLanguage.Size     = New-Object System.Drawing.Size(100,20)
$selectLanguage.DropDownStyle = "DropDownList"
$selectLanguage.Items.AddRange($langFiles)
$selectLanguage.SelectedItem = $lang
$selectLanguage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

# Optional: set default selection to current culture if available
# $currentCulture = (Get-Culture).Name
# if ($langFiles -contains $currentCulture) {
#     $selectLanguage.SelectedItem = $currentCulture
# } else {
#     $selectLanguage.SelectedIndex = 0
# }

# Handle selection change
$selectLanguage.Add_SelectedIndexChanged({
    $selectedLangFile = Join-Path $langDir $selectLanguage.SelectedItem
    $translations = Load-LanguageFile $selectLanguage.SelectedItem
    $lblSelectLanguage.Text = $translations["select_language"]
})

$panel.Controls.Add($selectLanguage)

$panel.Controls.Add((New-Label "" 0 750 243 20))
# Run the form
$form.ShowDialog()

exit
