@echo off
setlocal

set "file=%CD%\main.ps1"
powershell.exe -NoProfile -Command ^
  "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%file%\"' -WindowStyle Hidden"

exit
