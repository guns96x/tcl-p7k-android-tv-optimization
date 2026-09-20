@echo off
setlocal
cd /d "%~dp0"
title Remote Access Setup

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0enable-remote-access.ps1""' -Verb RunAs}"
if %errorlevel% neq 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0enable-remote-access.ps1"
)
