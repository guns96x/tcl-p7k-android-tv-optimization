[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Автоматичний самопідйом до прав Адміністратора (UAC Self-Elevation)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Запит прав Адміністратора (UAC)..." -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } catch {
        Write-Host "Потрібно дозволити права Адміністратора для налаштування!" -ForegroundColor Red
        Read-Host "Натисніть Enter для виходу..."
    }
    exit
}

# 2. Логування у файл
$logPath = "C:\remote-access.log"
try { Start-Transcript -Path $logPath -Append -Force } catch {}

try {
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "   НАЛАШТУВАННЯ ВІДДАЛЕНОГО ДОСТУПУ (SSH / WinRM / RDP)" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan

    # Крок 1: OpenSSH Server
    Write-Host "`n[1/4] Перевірка та запуск OpenSSH Server..." -ForegroundColor Yellow
    $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if (-not $sshd) {
        Write-Host "OpenSSH не знайдено в службах. Спроба інсталяції через Windows Update / Capability..." -ForegroundColor Yellow
        try {
            Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop | Out-Null
            $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
            Write-Host "OpenSSH Server успішно інстальовано." -ForegroundColor Green
        } catch {
            Write-Warning "Не вдалося завантажити OpenSSH Server (відсутній інтернет або Windows Update). Помилка: $($_.Exception.Message)"
        }
    }

    if ($sshd) {
        try {
            Set-Service -Name sshd -StartupType 'Automatic'
            Start-Service sshd
            New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Службу OpenSSH (sshd) активовано та запущено на порті 22!" -ForegroundColor Green
        } catch {
            Write-Warning "Помилка налаштування служби sshd: $($_.Exception.Message)"
        }
    } else {
        Write-Host "OpenSSH наразі недоступний офлайн. Буде активовано вбудований WinRM та RDP." -ForegroundColor Yellow
    }

    # Крок 2: Авторизація SSH-ключа за універсальним SID (працює на будь-якій мові Windows)
    Write-Host "`n[2/4] Додавання відкритого ключа для безпарольного входу..." -ForegroundColor Yellow
    $pubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhRhTLORy80FTJD7WQk95zXXTPGN6cHonAzfmYXqeOj vps-codex"
    
    $sshDir = "$env:ProgramData\ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    }
    $authFile = "$sshDir\administrators_authorized_keys"
    
    $existing = ""
    if (Test-Path $authFile) {
        $existing = Get-Content -Path $authFile -Raw -ErrorAction SilentlyContinue
    }
    if ($existing -notmatch [regex]::Escape($pubKey)) {
        Add-Content -Path $authFile -Value "`n$pubKey" -Force -Encoding UTF8
    }
    
    # Використовуємо універсальні SID: *S-1-5-32-544 (Адміністратори), *S-1-5-18 (SYSTEM)
    icacls.exe $authFile /inheritance:r /grant "*S-1-5-32-544:F" /grant "*S-1-5-18:F" | Out-Null
    Write-Host "Ключ записано та захищено правами доступу." -ForegroundColor Green

    # Крок 3: PowerShell Remoting (WinRM) - вбудований, працює без інтернету
    Write-Host "`n[3/4] Активація PowerShell Remoting (WinRM)..." -ForegroundColor Yellow
    try {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
        Write-Host "PowerShell Remoting (WinRM) успішно увімкнено!" -ForegroundColor Green
    } catch {
        Write-Warning "Помилка ввімкнення WinRM: $($_.Exception.Message)"
    }

    # Крок 4: Віддалений робочий стіл (RDP)
    Write-Host "`n[4/4] Активація Віддаленого робочого столу (RDP)..." -ForegroundColor Yellow
    try {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Write-Host "Віддалений робочий стіл (RDP) активовано на порті 3389!" -ForegroundColor Green
    } catch {
        Write-Warning "Помилка налаштування RDP: $($_.Exception.Message)"
    }

    # Результат
    Write-Host "`n=====================================================" -ForegroundColor Green
    Write-Host "   ГОТОВО! ДОСТУП ВІДКРИТО                          " -ForegroundColor Green
    Write-Host "=====================================================" -ForegroundColor Green
    $ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.254.*' }).IPAddress
    Write-Host "Локальна IP-адреса цього комп'ютера:" -ForegroundColor Cyan
    foreach ($ip in $ips) {
        Write-Host "  -> $ip" -ForegroundColor Yellow
    }
    Write-Host "`nНапишіть цю IP-адресу своєму асистенту в чат!" -ForegroundColor White
    Write-Host "=====================================================" -ForegroundColor Green

} catch {
    Write-Host "`nКритична помилка: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    try { Stop-Transcript } catch {}
    Write-Host "`nЛог збережено у файл: $logPath" -ForegroundColor Gray
    Read-Host "`nНатисніть клавішу Enter, щоб закрити вікно..."
}
