<#
.SYNOPSIS
    Revert / Restore Script for TCL P7K / Android 14 TV packages.
#>
param(
    [string]$DeviceIp = "192.168.0.22:5555"
)

Write-Host "=== Re-enabling all disabled packages on $DeviceIp ===" -ForegroundColor Cyan
adb connect $DeviceIp

$allPackages = @(
    "com.google.android.apps.tv.dreamx",
    "com.android.dreams.basic",
    "tv.samba.ssm.ui",
    "com.tcl.logkit",
    "com.tcl.usercenter",
    "com.tcl.useragreement",
    "com.google.android.feedback",
    "com.tcl.smartlink.core",
    "com.tcl.tv.tclhome_passive",
    "com.tcl.channelplus",
    "com.tcl.smartalexa",
    "com.tcl.dashboard",
    "com.tcl.messagebox",
    "com.tcl.suspension",
    "com.tcl.waterfall.overseas",
    "com.tcl.magiconnectfree",
    "com.tcl.browser",
    "com.tcl.esticker",
    "com.tcl.exhibit",
    "com.tcl.ocean.instructions",
    "com.tcl.repairguide",
    "com.tcl.gamebar",
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

foreach ($pkg in $allPackages) {
    adb -s $DeviceIp shell "pm enable $pkg"
}

adb -s $DeviceIp shell "settings put global window_animation_scale 1.0"
adb -s $DeviceIp shell "settings put global transition_animation_scale 1.0"
adb -s $DeviceIp shell "settings put global animator_duration_scale 1.0"

Write-Host "Restoration complete." -ForegroundColor Green
