Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$langDir = ".\lang"
$initPath = "initialize.ps1"
$configPath = "current.config"
$scriptPath = (Get-Location).Path + "\copy_script.ps1"
$logPath = "log.txt"
$tempDir = ".\temp"
$shutdownTrigger = Join-Path $tempDir "autoshutdown.enabled"



# Function to log to GUI and file
function Log($text) {
    $timestamp = $(Get-Date)
    $line = "$timestamp : $text"
    Add-Content -Path $logPath -Value $line
}

# Run logic
Log $translations["btn_check_drives"]
$player_ding  = New-Object System.Media.SoundPlayer (Join-Path $env:windir "Media\Windows Message Nudge.wav")
$player_ding.PlaySync()

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
    #Log "Found current.config. Variables are loaded." 
} else {
    [System.Windows.Forms.MessageBox]::Show("Config file not found. Setting is needed.", "Error", "OK", "Error")
    exit
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

# Source Folder validate
if (-not $sourceFolder -or -not (Test-Path $sourceFolder)) {
    [System.Windows.Forms.MessageBox]::Show($translations["msg_invalid_source_folder"], "Error", "OK", "Error")
    exit
} else {
    Log "$($translations["msg_now_copying"]): $(Split-Path $sourceFolder -Leaf)"
}

# Get drives
if ([string]::IsNullOrWhiteSpace($affectedDrive)) {
    $drives = @()
} else {
    $drives = $affectedDrive -split ','
}
foreach ($driveLetter in $drives) {
    $driveRoot = "$driveLetter`:\"
    if (Test-Path ".\temp\${driveLetter}.copying") {
        $msg=$translations["msg_copying"]
        Log "$driveLetter`: $msg."
    } elseif (Test-Path ".\temp\${driveLetter}.completed") {
        $msg=$translations["msg_done"]
        Log "$driveLetter`: $msg."
    } else {
        $msg=$translations["msg_start_script"]
        Log "$driveLetter`: $msg."
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" -letter $driveLetter -sourceFolder `"$sourceFolder`"" -WindowStyle Hidden
        # Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" -letter $driveLetter -sourceFolder `"$sourceFolder`""
    }
}
Log "________________________________`n"