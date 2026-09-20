<# :
@echo off
setlocal
cd /d "%~dp0"
title Remote Access Setup

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
Write-Host "   REMOTE ACCESS AUTO-CONFIGURATION (SSH / WinRM)   " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# 1. OpenSSH Server
Write-Host "`n[1/4] Installing / Starting OpenSSH Server..." -ForegroundColor Yellow
$sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
if (-not $sshd) {
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop | Out-Null
        $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
        Write-Host "OpenSSH Server installed successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Could not install OpenSSH via Windows Update (offline): $($_.Exception.Message)"
    }
}

if ($sshd) {
    try {
        Set-Service -Name sshd -StartupType 'Automatic'
        Start-Service sshd
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null
        Write-Host "OpenSSH Server (sshd) running on port 22." -ForegroundColor Green
    } catch {
        Write-Warning "SSH Service config: $($_.Exception.Message)"
    }
}

# 2. SSH Keys with Universal SIDs
Write-Host "`n[2/4] Configuring SSH Authorized Keys..." -ForegroundColor Yellow
$pubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhRhTLORy80FTJD7WQk95zXXTPGN6cHonAzfmYXqeOj vps-codex"
$adminAuthDir = "$env:ProgramData\ssh"
if (-not (Test-Path $adminAuthDir)) {
    New-Item -ItemType Directory -Force -Path $adminAuthDir | Out-Null
}
$adminAuthFile = "$adminAuthDir\administrators_authorized_keys"
$existing = ""
if (Test-Path $adminAuthFile) {
    $existing = Get-Content -Path $adminAuthFile -Raw -ErrorAction SilentlyContinue
}
if ($existing -notmatch [regex]::Escape($pubKey)) {
    Add-Content -Path $adminAuthFile -Value "`n$pubKey" -Force -Encoding UTF8
}
icacls.exe $adminAuthFile /inheritance:r /grant "*S-1-5-32-544:F" /grant "*S-1-5-18:F" | Out-Null

$userSshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $userSshDir)) {
    New-Item -ItemType Directory -Force -Path $userSshDir | Out-Null
}
$userAuthFile = "$userSshDir\authorized_keys"
Add-Content -Path $userAuthFile -Value "`n$pubKey" -Force -Encoding UTF8 -ErrorAction SilentlyContinue
Write-Host "SSH Keys configured." -ForegroundColor Green

# 3. WinRM
Write-Host "`n[3/4] Enabling WinRM (PowerShell Remoting)..." -ForegroundColor Yellow
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
    Write-Host "WinRM (PowerShell Remoting) enabled." -ForegroundColor Green
} catch {
    Write-Warning "WinRM: $($_.Exception.Message)"
}

# 4. RDP & Firewall
Write-Host "`n[4/4] Enabling Remote Desktop (RDP)..." -ForegroundColor Yellow
try {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    Write-Host "Remote Desktop enabled." -ForegroundColor Green
} catch {}

# Summary
Write-Host "`n=====================================================" -ForegroundColor Green
Write-Host "   DONE! ACCESS IS FULLY OPEN                        " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
$ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.254.*' }).IPAddress
Write-Host "Local IP Address of this computer:" -ForegroundColor Cyan
foreach ($ip in $ips) {
    Write-Host "  -> $ip" -ForegroundColor Yellow
}
Write-Host "=====================================================" -ForegroundColor Green
