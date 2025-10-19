@echo off
setlocal

set "file=%CD%\main.ps1"
powershell.exe -WindowStyle Hidden -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Scope Process; & '%file%'"
powershell.exe -File "%file%"

exit