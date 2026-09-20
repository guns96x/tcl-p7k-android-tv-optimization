# 1. Disable account lockout permanently
net accounts /lockoutthreshold:0

# 2. OpenSSH persistence on boot
Set-Service -Name sshd -StartupType Automatic
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\sshd' -Name DelayedAutostart -Value 0
Enable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue

# 3. Disable Sleep & Hibernate on AC power (so Dell stays online 24/7)
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# 4. Stop and Disable Windows Update & Dynamic Updates
Stop-Service wuauserv, bits, dosvc -Force -ErrorAction SilentlyContinue
Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
Set-Service bits -StartupType Disabled -ErrorAction SilentlyContinue
Set-Service dosvc -StartupType Disabled -ErrorAction SilentlyContinue

reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v 'NoAutoUpdate' /t REG_DWORD /d 1 /f
reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' /v 'AUOptions' /t REG_DWORD /d 2 /f
reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v 'DisableDynamicUpdate' /t REG_DWORD /d 1 /f

# 5. Default OpenSSH Shell to PowerShell
New-Item -ItemType Directory -Force -Path 'HKLM:\SOFTWARE\OpenSSH' -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null

Write-Host "=================================================" -ForegroundColor Green
Write-Host "   CONFIGURATION COMPLETE: ACCESS PERSISTENT!    " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Computer Name : $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host "User          : $env:USERNAME" -ForegroundColor Cyan
Write-Host "sshd Status   : $((Get-Service sshd).Status) ($((Get-Service sshd).StartType))" -ForegroundColor Cyan
Write-Host "WinRM Status  : $((Get-Service WinRM).Status) ($((Get-Service WinRM).StartType))" -ForegroundColor Cyan
Write-Host "Windows Update: $((Get-Service wuauserv).StartType)" -ForegroundColor Cyan
Write-Host "Sleep Timeout : 0 min (Never sleeps)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Green
