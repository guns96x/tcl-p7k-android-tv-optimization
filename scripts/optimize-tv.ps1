<#
.SYNOPSIS
    Automated Optimization & Debloat Script for TCL P7K / Android 14 TVs via ADB.
.DESCRIPTION
    Disables 28+ background bloatware and telemetry services, tunes OS process limits,
    accelerates UI animations, and prevents the LowMemoryKiller from crashing media players.
.PARAMETER DeviceIp
    IP address and port of the target Android TV (default: 192.168.0.22:5555).
#>
param(
    [string]$DeviceIp = "192.168.0.22:5555"
)

Write-Host "=== Connecting to Android TV at $DeviceIp ===" -ForegroundColor Cyan
adb connect $DeviceIp

Write-Host "`n=== 1. Disabling Screensavers and Sleep Triggers ===" -ForegroundColor Yellow
$screensavers = @(
    "com.google.android.apps.tv.dreamx",
    "com.android.dreams.basic"
)
foreach ($pkg in $screensavers) {
    adb -s $DeviceIp shell "pm disable-user --user 0 $pkg"
    adb -s $DeviceIp shell "am force-stop $pkg"
}
adb -s $DeviceIp shell "settings put secure screensaver_enabled 0"
adb -s $DeviceIp shell "settings put secure screensaver_activate_on_sleep 0"
adb -s $DeviceIp shell "settings put secure screensaver_activate_on_dock 0"

Write-Host "`n=== 2. Disabling Telemetry, Tracking and Diagnostics ===" -ForegroundColor Yellow
$telemetry = @(
    "tv.samba.ssm.ui",
    "com.tcl.logkit",
    "com.tcl.usercenter",
    "com.tcl.useragreement",
    "com.google.android.feedback"
)
foreach ($pkg in $telemetry) {
    adb -s $DeviceIp shell "pm disable-user --user 0 $pkg"
}
adb -s $DeviceIp shell "settings put global send_action_app_error 0"
adb -s $DeviceIp shell "settings put secure send_action_app_error 0"
adb -s $DeviceIp shell "settings put secure ad_personalization_enabled 0"
adb -s $DeviceIp shell "settings put secure limit_ad_tracking 1"
adb -s $DeviceIp shell "device_config put privacy privacy_sandbox_enabled false"
adb -s $DeviceIp shell "device_config put privacy privacy_sandbox_ad_measurement_enabled false"

Write-Host "`n=== 3. Disabling TCL Bloatware & Unused Vendor Services ===" -ForegroundColor Yellow
$tclBloat = @(
    "com.tcl.smartlink.core",
    "com.tcl.tv.tclhome_passive",
    "com.tcl.channelplus",
    "com.tcl.smartalexa",
    # NOTE: com.tcl.suspension (Quick_Panel), com.tcl.dashboard, com.tcl.gamebar,
    # and com.tcl.guard are intentionally PRESERVED: they provide the physical remote's
    # Source / HDMI input switcher menu and CEC switching.
    "com.tcl.messagebox",
    "com.tcl.waterfall.overseas",
    "com.tcl.magiconnectfree",
    "com.tcl.browser",
    "com.tcl.esticker",
    "com.tcl.exhibit",
    "com.tcl.ocean.instructions",
    "com.tcl.repairguide",
    "com.tcl.t_solo",
    "com.tcl.interactive",
    "com.tcl.partnercustomizer",
    "com.tcl.UpdatePeripheral",
    "com.tcl.hearaid",
    "com.android.printspooler",
    "com.google.android.play.games",
    "com.google.android.videos",
    "com.google.android.marvin.talkback"
)
foreach ($pkg in $tclBloat) {
    adb -s $DeviceIp shell "pm disable-user --user 0 $pkg"
}

Write-Host "`n=== 4. Tuning LowMemoryKiller & Background Process Limits ===" -ForegroundColor Yellow
# Limit background cached processes so RAM is never choked
adb -s $DeviceIp shell "device_config put activity_manager max_cached_processes 8"
# Disable Phantom Process Killer so TorrServer is never abruptly terminated
adb -s $DeviceIp shell "device_config put activity_manager max_phantom_processes 2147483647"
adb -s $DeviceIp shell "settings put global settings_enable_monitor_phantom_procs false"

Write-Host "`n=== 5. Accelerating UI Animations (2x Snappier) ===" -ForegroundColor Yellow
adb -s $DeviceIp shell "settings put global window_animation_scale 0.5"
adb -s $DeviceIp shell "settings put global transition_animation_scale 0.5"
adb -s $DeviceIp shell "settings put global animator_duration_scale 0.5"

Write-Host "`n=== 6. Trimming System Caches ===" -ForegroundColor Yellow
adb -s $DeviceIp shell "pm trim-caches 1000000000"

Write-Host "`n=== TV Memory Status After Optimization ===" -ForegroundColor Green
adb -s $DeviceIp shell "free -m"
Write-Host "`nOptimization complete! Device is fast, clean, and ready for 4K streaming." -ForegroundColor Green
