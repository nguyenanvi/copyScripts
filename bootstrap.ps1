$repoUrl = "https://github.com/nguyenanvi/copyScript/archive/refs/heads/main.zip"
$zipPath = "$env:TEMP\copyScript.zip"
$extractPath = "$env:TEMP\copyScript"

Invoke-WebRequest -Uri $repoUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Set-Location "$extractPath\copyScript-main"
Start-Process ".\RUN.cmd"
