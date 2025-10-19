# shutdown_control.ps1
Write-Host "Shutdown scheduled in 5 minutes. Press any key within 10 seconds to cancel..."

shutdown.exe /s /t 300  # Schedule shutdown

 Write-Host "`Tat ca cac o dia da sao chep xong."
Write-Host "Vui long kiem tra cac cua so dang mo truoc khi tat may."
Write-Host "Nhan phim bat ky de tat ngay, hoac cho 10 giay..."

$startTime = Get-Date
$timeout = 300
while ((Get-Date) -lt $startTime.AddSeconds($timeout)) {
    if ($Host.UI.RawUI.KeyAvailable) {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        shutdown.exe /a  # Abort shutdown
        Write-Host "Shutdown aborted."
        break
    }
    Start-Sleep -Milliseconds 100
}