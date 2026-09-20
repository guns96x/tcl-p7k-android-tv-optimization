<# :
@echo off
setlocal
cd /d "%~dp0"
title Auto Setup: Stop Updates & Enable Full Access

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -LiteralPath '%~f0' -Raw))"
echo.
pause
exit /b
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   ЗУПИНКА ОНОВЛЕНЬ ТА ВІДКРИТТЯ ПОВНОГО ДОСТУПУ    " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. Зупинка та вимкнення Windows Update і динамічних оновлень
Write-Host "`n[1/5] Зупинка Windows Update та блокування Dynamic Update..." -ForegroundColor Yellow
try {
    Stop-Service wuauserv, bits, dosvc -Force -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoUpdate" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v "DisableDynamicUpdate" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "AUOptions" /t REG_DWORD /d 2 /f | Out-Null
    Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "Windows Update та динамічні оновлення успішно ВИМКНЕНО!" -ForegroundColor Green
} catch {
    Write-Warning "Помилка блокування оновлень: $($_.Exception.Message)"
}

# 2. Зняття мережевого блокування порожнього пароля (LimitBlankPasswordUse = 0)
Write-Host "`n[2/5] Дозвіл мережевого доходу для облікового запису Admin..." -ForegroundColor Yellow
try {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d 1 /f | Out-Null
    # Також задаємо простий пароль 12345 на випадок, якщо потрібен для RDP
    net user Admin 12345 | Out-Null
    Write-Host "Мережевий доступ дозволено! Пароль для Admin задано: 12345" -ForegroundColor Green
} catch {
    Write-Warning "Помилка Lsa: $($_.Exception.Message)"
}

# 3. Встановлення та запуск OpenSSH Server (тепер без конкуренції з Windows Update)
Write-Host "`n[3/5] Активація OpenSSH Server..." -ForegroundColor Yellow
$sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
if (-not $sshd) {
    try {
        Start-Service wuauserv -ErrorAction SilentlyContinue
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop | Out-Null
        $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "OpenSSH Server інсталяція: $($_.Exception.Message)"
    } finally {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    }
}
if ($sshd) {
    Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service sshd -ErrorAction SilentlyContinue
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Profile Any -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Службу OpenSSH (порт 22) запущено назавжди!" -ForegroundColor Green
}

# 4. WinRM та RDP з повним відкриттям портів
Write-Host "`n[4/5] Перевірка WinRM та RDP..." -ForegroundColor Yellow
Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction SilentlyContinue
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
New-NetFirewallRule -Name 'WinRM-HTTP-In-TCP' -DisplayName 'WinRM (HTTP-In)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 5985 -Profile Any -ErrorAction SilentlyContinue | Out-Null

# 5. Підсумок
Write-Host "`n=====================================================" -ForegroundColor Green
Write-Host "   ГОТОВО! ПОВНИЙ ДОСТУП ВІДКРИТО НАЗАВЖДИ!         " -ForegroundColor Green
Write-Host "   ОНОВЛЕННЯ WINDOWS ПОВНІСТЮ ВИМКНЕНО!             " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
$ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.254.*' }).IPAddress
Write-Host "Локальна IP-адреса Dell:" -ForegroundColor Cyan
foreach ($ip in $ips) {
    Write-Host "  -> $ip" -ForegroundColor Yellow
}
Write-Host "Користувач: Admin | Пароль: 12345" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Green
