$repoUrl = "https://github.com/nguyenanvi/copyScripts/archive/refs/heads/main.zip"
$zipPath = "$env:TEMP\copyScripts.zip"
$extractPath = "$env:TEMP\copyScripts"

Invoke-WebRequest -Uri $repoUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Set-Location "$extractPath\copyScripts-main"
Start-Process ".\RUN.cmd"
