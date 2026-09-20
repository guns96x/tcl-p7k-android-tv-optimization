@echo off
setlocal
cd /d "%~dp0"
title Remote Access Configuration

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo [1/5] Stopping Windows Update and disabling Dynamic Update...
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
net stop dosvc /y >nul 2>&1
sc config wuauserv start= disabled >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoUpdate" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v "DisableDynamicUpdate" /t REG_DWORD /d 1 /f >nul 2>&1

echo [2/5] Enabling network logon and setting Admin password...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d 1 /f >nul 2>&1
net user Admin 12345 >nul 2>&1

echo [3/5] Starting and configuring OpenSSH Server...
sc config wuauserv start= auto >nul 2>&1
net start wuauserv >nul 2>&1
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" >nul 2>&1
sc config wuauserv start= disabled >nul 2>&1
net stop wuauserv /y >nul 2>&1
sc config sshd start= auto >nul 2>&1
net start sshd >nul 2>&1
netsh advfirewall firewall add rule name="OpenSSH-Server-In-TCP" dir=in action=allow protocol=TCP localport=22 profile=any >nul 2>&1

echo [4/5] Enabling WinRM and RDP...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Enable-PSRemoting -Force -SkipNetworkProfileCheck; Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force" >nul 2>&1
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server" /v "fDenyTSConnections" /t REG_DWORD /d 0 /f >nul 2>&1
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes >nul 2>&1
netsh advfirewall firewall add rule name="WinRM-HTTP-In-TCP" dir=in action=allow protocol=TCP localport=5985 profile=any >nul 2>&1

echo.
echo =====================================================
echo    SUCCESS! REMOTE ACCESS AND CONTROLS CONFIGURED
echo =====================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.254.*' }).IPAddress; foreach ($ip in $ips) { Write-Host ('  IP -> ' + $ip) -ForegroundColor Yellow }"
echo    Username: Admin
echo    Password: 12345
echo =====================================================
echo.
pause
