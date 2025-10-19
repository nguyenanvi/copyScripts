param(
	[string]$letter,
	[string]$sourceFolder
)

Add-Type -AssemblyName System.Windows.Forms

$configFile = "config.txt"
$logFile = "log.txt"
$soundError = ".\sounds\Error.wav"
$soundDone = ".\sounds\Done.wav"

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
#Write-Host "Driveletter: $letter"
if (-not $letter -or $letter.Length -ne 1) {
	Write-Host "O dia khong hop le, hoac thieu Tham so" 
	"$(Get-Date) : O dia khong hop le, hoac thieu Tham so"  | Add-Content -Path $logFile
	exit 
}

# Validate source
#Write-Host "Source: $sourceFolder"
if (-not (Test-Path $sourceFolder)) { 
    Write-Host "$sourceFolder khong ton tai!" 
    $player_err.PlaySync()
}

# Validate $destination 
#Write-Host "DestinationPath: $destinationPath"
if (-not (Test-Path $destinationPath)) { 
    Write-Host "O dia $letter khong ton tai!" 
    $player_err.PlaySync() 
}
try {
    #Write-Host "Creating new $letter.copying"
    New-Item -Path "$letter.copying" -ItemType File -Force
	
    Remove-Item -Path (Get-ChildItem -Filter "*.slotcopying").FullName -Force
    $copying = (Get-ChildItem -Filter "*.copying").Count
    New-Item -Path "$copying.slotcopying" -ItemType File -Force

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

	#Write-Host "Files copied successfully."

    # Get folder size in bytes
    $folderSize = (Get-ChildItem -Path $sourceFolder -Recurse -File | Measure-Object -Property Length -Sum).Sum

    # Get all files on the drive and calculate total size
    $drivePath = "$letter`:\"
    $driveFileSize = (Get-ChildItem -Path $drivePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum

    # Calculate difference
    $diff = $driveFileSize - $folderSize

    # Display results
    #Write-Host "Folder size: $folderSize bytes"
    #Write-Host "Total size of all files on $letter`: $driveFileSize bytes"
    #Write-Host "Difference (Drive files - Folder): $diff bytes"

    if($diff -ne 0){
        $player_err.PlaySync()
        [System.Windows.Forms.MessageBox]::Show("Copied to $letter drive. But something wrong [diff: $diff]")
    } else {
        $player_done.PlaySync() 
	    "$(Get-Date) : [ $letter ]`: [ $diff ]"  | Add-Content -Path $logFile
    }
} catch {
    [System.Windows.Forms.MessageBox]::Show("Error copying to $letter drive.")
	$player_err.PlaySync() 
} finally {
    Remove-Item -Path "$letter.copying" -Force
	
    Remove-Item -Path (Get-ChildItem -Filter "*.slotcopying").FullName -Force
    $copying = (Get-ChildItem -Filter "*.copying").Count
    New-Item -Path "$copying.slotcopying" -ItemType File -Force
    "$(Get-Date) : $copying copying remain."  | Add-Content -Path $logFile
}

# Check if all copy operations are done
if ($copying -eq 0 -and $autoShutDown -eq $true) {
    # Open shutdown_control.ps1:
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File shutdown_control.ps1" -WindowStyle Normal
}
