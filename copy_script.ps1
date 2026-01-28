param(
	[string]$letter,
	[string]$sourceFolder
)

Add-Type -AssemblyName System.Windows.Forms

$configFile = "config.txt"
$logFile = "log.txt"
$tempDir = ".\temp"
$soundError = ".\sounds\Error.wav"
$soundDone = ".\sounds\Done.wav"

if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

function Config($variable) {
    if (-not (Test-Path $configFile)) { return $null }

    foreach ($line in Get-Content -Path $configFile) {
        if ($line -match '=') {
            $parts = $line -split '=', 2
            $name  = $parts[0].Trim()
            $value = $parts[1].Trim()
            if ($name -eq $variable) { return $value }
        }
    }
    return $null
}



# Load config.txt variables
if (Test-Path $configFile) {
    Get-Content -Path $configFile | ForEach-Object {
        if ($_ -match '=') {
            $parts = $_ -split '='
            $name = $parts[0].Trim()
            $value = $parts[1].Trim()
            Set-Variable -Name $name -Value $value
        }
    }
}

$player_err = New-Object System.Media.SoundPlayer $soundError 
$player_done = New-Object System.Media.SoundPlayer $soundDone 
$destinationPath = "${letter}:\" 

# Validate drive letter
if (-not $letter -or $letter.Length -ne 1) {
	Write-Host "Invalid drive." 
	"$(Get-Date) : Invalid drive."  | Add-Content -Path $logFile
	exit 
}

# Validate source
if (-not (Test-Path $sourceFolder)) { 
    Write-Host "Missing SourceFolder ($sourceFolder)" 
    $player_err.PlaySync()
}

# Validate $destination 
if (-not (Test-Path $destinationPath)) { 
    Write-Host "O dia $letter khong ton tai!" 
    $player_err.PlaySync() 
}
try {
    $copyingFile = Join-Path $tempDir "$letter.copying"
    $currentPID = $PID
    Set-Content -Path $copyingFile -Value $PID -ErrorAction Stop
    if (-not (Test-Path $copyingFile)) { 
        New-Item -Path $copyingFile -ItemType File -Force | Out-Null 
    }
	$slot = Get-ChildItem -Path $tempDir -Filter "*.slotcopying" -ErrorAction SilentlyContinue | Select-Object -First 1 
    if ($slot) { 
        Remove-Item -Path $slot.FullName -Force -ErrorAction SilentlyContinue 
    }
    $copyingFiles = Get-ChildItem -Path $tempDir -Filter "*.copying" -ErrorAction SilentlyContinue
    $copying = if ($copyingFiles) { $copyingFiles.Count } else { 0 }

    $slotPath = Join-Path $tempDir "$copying.slotcopying" 
    New-Item -Path $slotPath -ItemType File -Force | Out-Null

    # Try formatting USB if autoFormat=true
    if ($autoFormat -eq $true) {
        
	    $sourceFolderName = Split-Path -Path $sourceFolder -Leaf
	    try { 
		    Format-Volume -DriveLetter $letter -FileSystem FAT32 -NewFileSystemLabel $sourceFolderName -AllocationUnitSize 16384 -Confirm:$false 
	    } catch { 
		    Write-Host "$letter drive is not available." 
		    $player_err.PlaySync()

		    Remove-Item -Path "$letter.copying" -Force

            Remove-Item -Path (Get-ChildItem -Filter "*.slotcopying").FullName -Force
            $copying = (Get-ChildItem -Filter "*.copying").Count
            New-Item -Path "$copying.slotcopying" -ItemType File -Force
		    exit 
	    }
    }

    # Copying $sourceFolder to $letter 
    $shell = New-Object -ComObject "Shell.Application"
	$destination = $shell.NameSpace("$destinationPath")

	$sourceShell = $shell.NameSpace("$sourceFolder")
	$files = $sourceShell.Items()

	$destination.CopyHere($files, 16)  # 16 ensures overwrite without prompts

    # Get folder size in bytes
    $folderSize = (Get-ChildItem -Path $sourceFolder -Recurse -File | Measure-Object -Property Length -Sum).Sum

    # Get all files on the drive and calculate total size
    $drivePath = "$letter`:\"
    $driveFileSize = (Get-ChildItem -Path $drivePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum

    # Calculate difference
    $diff = $driveFileSize - $folderSize

    if($diff -ne 0){
        $player_err.PlaySync()
    } else {
        $player_done.PlaySync() 
    }
    "$(Get-Date) : $letter`: done [ $diff ]"  | Add-Content -Path $logFile
} catch {
    $errMsg = $_.Exception.Message 
    $errStack = $_.Exception.StackTrace 

    $player_err.PlaySync() 
    [System.Windows.Forms.MessageBox]::Show("Error copying to $letter drive.`n$errMsg")
} finally {
    $copyingFile = Join-Path $tempDir "$letter.copying"
    Remove-Item -Path $copyingFile -Force -ErrorAction SilentlyContinue

    $slot = Get-ChildItem -Path $tempDir -Filter "*.slotcopying" -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($slot) { Remove-Item -Path $slot.FullName -Force -ErrorAction SilentlyContinue }

    $copyingFiles = Get-ChildItem -Path $tempDir -Filter "*.copying" -ErrorAction SilentlyContinue 
    $copying = if ($copyingFiles) { $copyingFiles.Count } else { 0 }
    New-Item -Path (Join-Path $tempDir "$copying.slotcopying") -ItemType File -Force | Out-Null

    "$(Get-Date) : $copying copying remain."  | Add-Content -Path $logFile

    # Check if all copy operations are done
    if ($copying -eq 0 -and [bool](Config "autoShutDown")) {
        # Open shutdown_control.ps1:
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File shutdown_control.ps1" -WindowStyle Normal
    }
}