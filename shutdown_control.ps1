$tempDir = ".\temp"
$shutdownTrigger = Join-Path $tempDir "autoshutdown.enabled"

# shutdown_control.ps1
Write-Host "Shutdown scheduled in 5 minutes."
Write-Host "Press any key to cancel."

shutdown.exe /s /t 300  # Schedule shutdown

$startTime = Get-Date
$timeout = 300
while ((Get-Date) -lt $startTime.AddSeconds($timeout)) {
    if ($Host.UI.RawUI.KeyAvailable) {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Remove-Item $shutdownTrigger -Force -ErrorAction SilentlyContinue
        shutdown.exe /a  # Abort shutdown
        Write-Host "Shutdown aborted."
        break
    }
    Start-Sleep -Milliseconds 100
}