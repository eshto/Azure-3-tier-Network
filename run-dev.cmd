@echo off
set ACTION=%1
if "%ACTION%"=="" set ACTION=plan
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" -Environment dev -Action %ACTION%
