$repoUrl = "https://github.com/nguyenanvi/copitor/archive/refs/heads/main.zip"
$zipPath = "$env:TEMP\copitor.zip"
$extractPath = "$env:TEMP\copitor"

Invoke-WebRequest -Uri $repoUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Set-Location "$extractPath\copitor-main"
Start-Process ".\RUN.cmd"
