# Requires -RunAsAdministrator
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   НАЛАШТУВАННЯ ВІДДАЛЕНОГО ДОСТУПУ (SSH + WinRM)   " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. OpenSSH Server
Write-Host "`n[1/4] Перевірка та встановлення OpenSSH Server..." -ForegroundColor Yellow
try {
    $sshCap = Get-WindowsCapability -Online -Name OpenSSH.Server*
    if ($sshCap.State -ne 'Installed') {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop
        Write-Host "OpenSSH Server успішно встановлено." -ForegroundColor Green
    } else {
        Write-Host "OpenSSH Server уже встановлено." -ForegroundColor Green
    }
} catch {
    Write-Host "Попередження під час встановлення OpenSSH Server: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2. Configure and Start sshd service
Write-Host "`n[2/4] Запуск та автозавантаження служби SSH..." -ForegroundColor Yellow
try {
    Set-Service -Name sshd -StartupType 'Automatic'
    Start-Service sshd
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Службу sshd запущено." -ForegroundColor Green
} catch {
    Write-Host "Помилка запуску sshd: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Add authorized public key
Write-Host "`n[3/4] Додавання відкритого ключа для безпарольного входу..." -ForegroundColor Yellow
$pubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhRhTLORy80FTJD7WQk95zXXTPGN6cHonAzfmYXqeOj vps-codex"

# For Administrators group:
$adminAuthFile = "$env:ProgramData\ssh\administrators_authorized_keys"
New-Item -ItemType Directory -Force -Path "$env:ProgramData\ssh" | Out-Null
Set-Content -Path $adminAuthFile -Value $pubKey -Force -Encoding UTF8
icacls.exe $adminAuthFile /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null

# For Admin user profile:
$userSshDir = "$env:USERPROFILE\.ssh"
$userAuthFile = "$userSshDir\authorized_keys"
New-Item -ItemType Directory -Force -Path $userSshDir | Out-Null
Set-Content -Path $userAuthFile -Value $pubKey -Force -Encoding UTF8
icacls.exe $userAuthFile /inheritance:r /grant "$($env:USERNAME):F" /grant "SYSTEM:F" | Out-Null
Write-Host "Ключ успішно записано та захищено правами доступу." -ForegroundColor Green

# 4. Enable WinRM (PowerShell Remoting) as fallback
Write-Host "`n[4/4] Активація PowerShell Remoting (WinRM)..." -ForegroundColor Yellow
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction SilentlyContinue
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force -ErrorAction SilentlyContinue
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force -ErrorAction SilentlyContinue
    Write-Host "PowerShell Remoting активовано." -ForegroundColor Green
} catch {
    Write-Host "Попередження WinRM: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 5. Enable Remote Desktop (RDP)
try {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    Write-Host "Віддалений робочий стіл (RDP) увімкнено." -ForegroundColor Green
} catch {}

# Output IP Addresses
Write-Host "`n=====================================================" -ForegroundColor Green
Write-Host "   ГОТОВО! ДОСТУП ВІДКРИТО                          " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
$ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.254.*' }).IPAddress
Write-Host "Локальна IP-адреса цього комп'ютера:" -ForegroundColor Cyan
foreach ($ip in $ips) {
    Write-Host "  -> $ip" -ForegroundColor Yellow
}
Write-Host "`nНапишіть цю IP-адресу в чат своєму асистенту!" -ForegroundColor White
Write-Host "=====================================================" -ForegroundColor Green
