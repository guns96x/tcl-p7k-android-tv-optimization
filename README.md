# TCL P7K Android TV 14: measured state and reversible tuning

This repository contains ADB scripts for one verified TCL G10 / P7K device and a
TorrServer cache configuration script. Run them only after checking the target
device and reading the changes below.

**Коротко:** телевізор уже мав основні оптимізації. Повторна перевірка не
вимкнула жодного нового пакета і не змінила системних параметрів. Скрипти
тепер зберігають початковий стан для відкату, а налаштування TorrServer
оновлюються без втрати інших полів.

## Live audit on 2026-09-20

The TV connected at `192.168.0.22:5555` identified itself as `G10` on Android
14, build `TCL/G10_4K_GB/G10:14/UTT2.250416.001/AU02:user/release-keys`.
ADB reported 1,864 MiB physical RAM, 999 MiB swap (zRAM), and 4.7 GiB free
on the 7.9 GiB `/data` partition. One `/proc/meminfo` sample showed
`MemAvailable: 272320 kB`. These are snapshots, not performance guarantees.

Before this audit, 23 packages were already disabled. A fresh run of
`optimize-tv.ps1` changed **0 packages and 0 settings** and verified the selected
state. The prior claim that 28 services had been disabled was inaccurate:
the old script listed 31 packages, eight of which were absent on this TV;
two of the remaining packages were enabled.

The selected OS values were already present: animation scales `0.5`,
`max_cached_processes=8`, `max_phantom_processes=2147483647`, and the
screensaver options set to `0`. The phantom-process setting does not disable
Android's low-memory killer or guarantee that a player stays alive.

The active TorrServer (`MatriX.141.Client`) reported an 80 MiB RAM cache,
25% preload, 95% read-ahead, disk cache off, and a 30-peer limit. Its
`ResponsiveMode` was initially false, although the MatriX.141 default is true. The older
configuration script sent only part of TorrServer's settings object. TorrServer
replaces the complete object on `action=set`, so that request could reset
unmentioned fields. The revised script first reads the full object, changes
only its requested fields, and sends the full object back. The cache values
already matched; the live update changed only `ResponsiveMode` to true. A
comparison of all 37 returned fields with the backup found no other changes.

The earlier report's 8–12 second startup and uninterrupted playback at 24:46
were reported observations; this audit did not replay the film. Startup and
stalling depend on peers, bitrate, network, and player behavior.

The locked, green verified-boot device already has zRAM. No root, boot image
write, physical swapfile, system APK replacement, or launcher modification was
performed. Those changes are outside this automation. Google TV's Apps-only
mode is a user-interface option, not a memory measurement.

## What the scripts change

`optimize-tv.ps1` checks for a TCL G10, saves the initial package and setting
state in `state/`, skips absent and already disabled packages, applies selected
ADB settings, and verifies them. The package list covers screensavers,
telemetry, and optional TCL services. It leaves TalkBack, HearAid, peripheral
updates, game bar, agreement handling, Google Movies, Netflix, voice search,
and core TV inputs alone. It does not delete apps or clear app data.

`restore-tv.ps1` requires the snapshot made by `optimize-tv.ps1` and restores
those recorded package and setting values. It cannot recover values from
changes made before that snapshot. The snapshot is device-specific and is
ignored by Git.

`configure-torrserver.ps1` reads and backs up the full settings object, changes
the six cache-related fields plus `ResponsiveMode`, then verifies them. A real change makes
TorrServer disconnect and reconnect torrent sessions, so run it when playback
can be interrupted. The player may remain paused afterward; press Play to
resume. If the requested values are already set, it makes no
`action=set` request.

## Usage

Install Android platform-tools and enable authorized ADB access to the TV.
Check the serial with `adb devices -l` before writing to it. The scripts
accept `-AdbPath` if `adb` is unavailable on `PATH`.

```powershell
.\scripts\optimize-tv.ps1 -DeviceIp '192.168.0.22:5555'
.\scripts\configure-torrserver.ps1 -TorrServerUrl 'http://192.168.0.22:8090'
.\scripts\restore-tv.ps1 -DeviceIp '192.168.0.22:5555' -BackupPath '.\state\tv-YYYYMMDD-HHMMSS.json'
```

The TorrServer settings backup may contain personal settings. Keep `state/`
local. The TV snapshot records its serial number and should also stay local.

## Verification boundary

All three scripts passed PowerShell syntax parsing. A mock REST test confirmed
that the TorrServer script preserves unrelated fields and skips a repeat
request. The optimizer completed against the connected TV without changes
because its selected target state was already present. The restore script
restored `window_animation_scale` from a temporary `1.0` back to the snapshot
value `0.5` and verified all recorded settings. TorrServer accepted the live
change, remained reachable, and had local port 8090 connections afterward.
The player was paused after the change; an ADB Play command resumed its
MediaSession near 45 minutes. Its reported position then advanced from
45:03 to 47:08 while the TorrServer process remained active. Picture and
audio quality were not independently checked on the TV screen.
No new 4K playback or before-and-after performance test was run here.

TorrServer MatriX.141's [settings handler](https://github.com/YouROK/TorrServer/blob/MatriX.141/server/web/api/settings.go)
and [settings model](https://github.com/YouROK/TorrServer/blob/MatriX.141/server/settings/btsets.go)
document the complete-object behavior. Android's
[ADB documentation](https://developer.android.com/tools/adb) explains device
selection with `-s`.
