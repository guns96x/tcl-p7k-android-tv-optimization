<#
.SYNOPSIS
    Apply selected TCL P7K settings with a device-specific rollback snapshot.
.DESCRIPTION
    Requires an online G10 device. Skips absent or already disabled packages.
    Saves original values before changing anything. Does not touch accessibility,
    peripheral updates, Google Movies, Netflix, voice search, or TV inputs.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceIp,
    [string]$BackupDirectory = (Join-Path $PSScriptRoot '..\state'),
    [string]$AdbPath
)

$ErrorActionPreference = 'Stop'
$sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if ($AdbPath) { $adb = (Resolve-Path -LiteralPath $AdbPath -ErrorAction Stop).Path }
elseif (Test-Path -LiteralPath $sdkAdb) { $adb = $sdkAdb }
else { $adb = (Get-Command adb -ErrorAction Stop).Source }
function Invoke-TvShell {
    param([string]$Command)
    $output = & $adb -s $DeviceIp shell $Command 2>&1
    if ($LASTEXITCODE -ne 0 -or $output -match '^(Error|Failure):') {
        throw "ADB command failed: $Command :: $($output -join ' ')"
    }
    return ($output -join "`n").Trim()
}

& $adb connect $DeviceIp | Out-Null
if ($LASTEXITCODE -ne 0 -or (Invoke-TvShell 'getprop ro.product.device') -ne 'G10') {
    throw "ADB target $DeviceIp is unavailable or is not a TCL G10."
}
$fingerprint = Invoke-TvShell 'getprop ro.build.fingerprint'
$serial = Invoke-TvShell 'getprop ro.serialno'

# Keep the scope narrow. These features can matter to a particular household:
# TalkBack, HearAid, game bar, peripheral updates, agreements, and Google Movies.
$packages = @(
    'com.google.android.apps.tv.dreamx', 'com.android.dreams.basic',
    'tv.samba.ssm.ui', 'com.tcl.logkit', 'com.tcl.usercenter',
    'com.google.android.feedback', 'com.tcl.smartlink.core',
    'com.tcl.tv.tclhome_passive', 'com.tcl.channelplus',
    'com.tcl.smartalexa', 'com.tcl.dashboard', 'com.tcl.messagebox',
    'com.tcl.suspension', 'com.tcl.waterfall.overseas',
    'com.tcl.magiconnectfree', 'com.tcl.browser', 'com.tcl.esticker',
    'com.tcl.exhibit', 'com.tcl.ocean.instructions', 'com.tcl.repairguide',
    'com.tcl.t_solo', 'com.tcl.interactive', 'com.tcl.partnercustomizer',
    'com.android.printspooler', 'com.google.android.play.games'
)
$options = @(
    @{ Tool='settings'; Scope='secure'; Name='screensaver_enabled'; Value='0' },
    @{ Tool='settings'; Scope='secure'; Name='screensaver_activate_on_sleep'; Value='0' },
    @{ Tool='settings'; Scope='secure'; Name='screensaver_activate_on_dock'; Value='0' },
    @{ Tool='settings'; Scope='global'; Name='send_action_app_error'; Value='0' },
    @{ Tool='settings'; Scope='secure'; Name='send_action_app_error'; Value='0' },
    @{ Tool='settings'; Scope='secure'; Name='ad_personalization_enabled'; Value='0' },
    @{ Tool='settings'; Scope='secure'; Name='limit_ad_tracking'; Value='1' },
    @{ Tool='device_config'; Scope='privacy'; Name='privacy_sandbox_enabled'; Value='false' },
    @{ Tool='device_config'; Scope='privacy'; Name='privacy_sandbox_ad_measurement_enabled'; Value='false' },
    @{ Tool='device_config'; Scope='activity_manager'; Name='max_cached_processes'; Value='8' },
    @{ Tool='device_config'; Scope='activity_manager'; Name='max_phantom_processes'; Value='2147483647' },
    @{ Tool='settings'; Scope='global'; Name='settings_enable_monitor_phantom_procs'; Value='false' },
    @{ Tool='settings'; Scope='global'; Name='window_animation_scale'; Value='0.5' },
    @{ Tool='settings'; Scope='global'; Name='transition_animation_scale'; Value='0.5' },
    @{ Tool='settings'; Scope='global'; Name='animator_duration_scale'; Value='0.5' }
)

$installed = @((Invoke-TvShell 'pm list packages') -split "`n")
$disabled = @((Invoke-TvShell 'pm list packages -d') -split "`n")
$packageState = @{}
foreach ($package in $packages) {
    $entry = 'package:' + $package
    if ($disabled -contains $entry) { $packageState[$package] = 'disabled' }
    elseif ($installed -contains $entry) { $packageState[$package] = 'enabled' }
    else { $packageState[$package] = 'absent' }
}
foreach ($option in $options) {
    $option.Previous = Invoke-TvShell "$($option.Tool) get $($option.Scope) $($option.Name)"
}
$snapshot = [ordered]@{
    DeviceIp = $DeviceIp
    Fingerprint = $fingerprint
    Serial = $serial
    Packages = $packageState
    Options = $options
}
New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
$backupPath = Join-Path $BackupDirectory ('tv-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
$snapshot | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $backupPath -Encoding UTF8
Write-Host "Original state saved: $backupPath"

$changedPackages = 0
foreach ($package in $packages) {
    if ($packageState[$package] -eq 'enabled') {
        Invoke-TvShell "pm disable-user --user 0 $package" | Out-Null
        $changedPackages++
    }
}
$changedOptions = 0
foreach ($option in $options) {
    if ($option.Previous -ne $option.Value) {
        Invoke-TvShell "$($option.Tool) put $($option.Scope) $($option.Name) $($option.Value)" | Out-Null
        $changedOptions++
    }
}
$disabledAfter = @((Invoke-TvShell 'pm list packages -d') -split "`n")
foreach ($package in $packages) {
    if ($packageState[$package] -ne 'absent' -and $disabledAfter -notcontains ('package:' + $package)) {
        throw "Package verification failed: $package"
    }
}
foreach ($option in $options) {
    $actual = Invoke-TvShell "$($option.Tool) get $($option.Scope) $($option.Name)"
    if ($actual -ne $option.Value) { throw "Setting verification failed: $($option.Name)" }
}
Write-Host "Verified: $changedPackages packages disabled, $changedOptions settings changed."
Write-Host "Restore using .\scripts\restore-tv.ps1 -DeviceIp '$DeviceIp' -BackupPath '$backupPath'"
