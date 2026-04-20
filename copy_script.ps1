param(
	[string]$letter,
	[string]$sourceFolder
)

Add-Type -AssemblyName System.Windows.Forms

$configFile = "current.config"
$logFile = "log.txt"
$tempDir = ".\temp"
$copyingFile = Join-Path $tempDir "$letter.copying"
$insertedFile = Join-Path $tempDir "$letter.inserted"
$infoFile = Join-Path $tempDir "$letter.info"
$completedFile = Join-Path $tempDir "$letter.completed"
$soundError = Join-Path $env:windir "Media\Windows Hardware Fail.wav"
$soundDone  = Join-Path $env:windir "Media\Windows Print complete.wav"

if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

if (Test-Path $copyingFile) {
    exit
}

# Function to log to GUI and file
function Log($text) {
    $timestamp = $(Get-Date)
    $line = "$timestamp : $text"
    Add-Content -Path "log.txt" -Value $line
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

# Load current.config variables
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

$player_err  = New-Object System.Media.SoundPlayer $soundError
$player_done = New-Object System.Media.SoundPlayer $soundDone
$destinationPath = "${letter}:\" 

# Validate drive letter
if (-not $letter -or $letter.Length -ne 1) {
	Log "$letter`: Invalid drive." 
	"$(Get-Date) : Invalid drive."  | Add-Content -Path $logFile
	exit 
}

if (-not (Test-Path "$letter`:\")){
    Log "$letter`: disconnected"
    exit
}

# Validate source
if (-not (Test-Path $sourceFolder)) { 
    Log "$letter - SourceFolder ($sourceFolder) is invalid" 
    $player_err.PlaySync()
}

try {
    $currentPID = $PID
    Set-Content -Path $copyingFile -Value $PID -ErrorAction Stop
    Remove-Item -Path $completedFile -Force
    Remove-Item -Path $insertedFile -Force -ErrorAction SilentlyContinue
    
    function Get-FolderSize($path) {
        if (-not (Test-Path $path)) { return 0 }
        return (Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum
    }
    $driveInfo = Get-PSDrive -Name $letter -ErrorAction SilentlyContinue
    if ($null -eq $driveInfo) {
        $player_err.PlaySync()
    }
    $sourceSize = Get-FolderSize $sourceFolder
    $freeSpace  = $driveInfo.Free
    $totalSpace = $driveInfo.Used + $driveInfo.Free

    $info = @"
scriptSourceFolder=$sourceFolder
scriptSourceSize=$sourceSize
scriptTotalSpace=$totalSpace
"@
    Set-Content -Path $infoFile -Value $info

    # Try formatting USB if autoFormat=true
    if ($autoFormat -eq $true) {
        $sourceFolderName = Split-Path -Path $sourceFolder -Leaf
        try { 
            Format-Volume -DriveLetter $letter -FileSystem FAT32 -NewFileSystemLabel $sourceFolderName -AllocationUnitSize 16384 -Confirm:$false 
        } catch { 
            Log "$letter drive is not available to format." 
            $player_err.PlaySync()
            Remove-Item -Path "$letter.copying" -Force
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
        Set-Content -Path $completedFile -Value $(Get-Date)
        $player_done.PlaySync() 
    }
    "$(Get-Date) : $letter`: copy done - $diff"  | Add-Content -Path $logFile
} catch {
    $errMsg = $_.Exception.Message 
    $errStack = $_.Exception.StackTrace 

    $player_err.PlaySync() 
    $msg = "$letter`: Error copying:`n$errMsg"
    # [System.Windows.Forms.MessageBox]::Show($msg)
    Log $msg
} finally {
    Remove-Item -Path $copyingFile -Force -ErrorAction SilentlyContinue
}