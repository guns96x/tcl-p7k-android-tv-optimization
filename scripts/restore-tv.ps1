<#
.SYNOPSIS
    Restore the exact package and setting state saved by optimize-tv.ps1.
.DESCRIPTION
    Requires a snapshot from optimize-tv.ps1. It does not claim to recover
    values from changes made before that snapshot was created.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceIp,
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$BackupPath,
    [string]$AdbPath
)

$ErrorActionPreference = 'Stop'
$snapshot = Get-Content -LiteralPath $BackupPath -Raw | ConvertFrom-Json
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
if ($LASTEXITCODE -ne 0 -or (Invoke-TvShell 'getprop ro.serialno') -ne $snapshot.Serial -or
    (Invoke-TvShell 'getprop ro.build.fingerprint') -ne $snapshot.Fingerprint) {
    throw 'The connected device does not match the backup.'
}

$disabled = @((Invoke-TvShell 'pm list packages -d') -split "`n")
foreach ($entry in $snapshot.Packages.PSObject.Properties) {
    $package = $entry.Name
    $was = $entry.Value
    $isDisabled = $disabled -contains ('package:' + $package)
    if ($was -eq 'enabled' -and $isDisabled) {
        Invoke-TvShell "pm enable --user 0 $package" | Out-Null
    } elseif ($was -eq 'disabled' -and -not $isDisabled) {
        Invoke-TvShell "pm disable-user --user 0 $package" | Out-Null
    }
}
foreach ($option in $snapshot.Options) {
    $current = Invoke-TvShell "$($option.Tool) get $($option.Scope) $($option.Name)"
    if ($current -eq $option.Previous) { continue }
    if ($option.Previous -eq 'null') {
        Invoke-TvShell "$($option.Tool) delete $($option.Scope) $($option.Name)" | Out-Null
    } else {
        Invoke-TvShell "$($option.Tool) put $($option.Scope) $($option.Name) $($option.Previous)" | Out-Null
    }
}

$disabledAfter = @((Invoke-TvShell 'pm list packages -d') -split "`n")
foreach ($entry in $snapshot.Packages.PSObject.Properties) {
    if ($entry.Value -eq 'absent') { continue }
    $isDisabled = $disabledAfter -contains ('package:' + $entry.Name)
    if (($entry.Value -eq 'disabled') -ne $isDisabled) {
        throw "Package restore verification failed: $($entry.Name)"
    }
}
foreach ($option in $snapshot.Options) {
    $actual = Invoke-TvShell "$($option.Tool) get $($option.Scope) $($option.Name)"
    if ($actual -ne $option.Previous) {
        throw "Setting restore verification failed: $($option.Name)"
    }
}
Write-Host 'Verified: TV package and setting state matches the snapshot.'
