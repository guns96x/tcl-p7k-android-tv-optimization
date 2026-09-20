@echo off
chcp 65001 >nul
title Setup Remote Access (SSH / WinRM)
cd /d "%~dp0"

:: Check for Administrative privileges and elevate if needed
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Запит прав Адміністратора...
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

if exist "%~dp0scripts\enable-remote-access.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\enable-remote-access.ps1"
) else (
    if exist "%~dp0enable-remote-access.ps1" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0enable-remote-access.ps1"
    ) else (
        echo [ПОМИЛКА] Файл enable-remote-access.ps1 не знайдено!
    )
)

echo.
pause
