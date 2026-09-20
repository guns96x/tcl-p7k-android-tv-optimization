# TCL P7K (RTD2875P) Android TV 14 Deep Optimization & 4K Streaming Engineering Report

Comprehensive technical documentation, hardware diagnostics, debloat audit, OS tuning, and TorrServer 4K streaming pipeline optimization for the **TCL P7K** (Realtek RTD2875P platform running Google TV on Android 14).

---

## 1. Target Hardware & Platform Specifications

Live diagnostics extracted via ADB from the target device:

| Component / Property | Value | Notes |
| :--- | :--- | :--- |
| **Model & Board** | `Smart TV Pro` (`P7K`, board: `G10`) | Realtek RTD2875P / `rtd6748` SoC |
| **Android Version** | **Android 14** (API 34) | Build `UTT2.250416.001 AU02 release-keys` |
| **Security Patch** | `2026-06-05` | AVB 2.0 / `dm-verity` enforcing |
| **Physical RAM** | **1864 MB (~2.0 GB)** | 32-bit userspace on armv8l kernel 5.15.192 |
| **Kernel zRAM** | **1024 MB (1.0 GB)** | Hardware-accelerated compression (`[zacc]`) |
| **Internal Storage** | **7.9 GB total** (`/data`) | ~4.0 GB free before optimization |
| **External Storage** | **14 GB USB 3.0** (`sda1`) | Mounted under `/storage/` |
| **Bootloader State** | `locked`, `verifiedbootstate: green` | Strictly enforced signature verification |

---

## 2. Root, Swap & Hardware Wear-out Analysis

### Initial Hypothesis
The initial consideration suggested obtaining Magisk root via patched `boot.img` and configuring a 1–2 GB swapfile on internal storage (`/data/local/swapfile` via `mkswap` / `swapon`).

### Critical Findings & Why Physical Swapfile Was Rejected
1. **Flash Memory Degradation (NAND Wear-Out)**:
   The internal storage of the TV is budget eMMC flash. Active Linux virtual memory swapping performs continuous small 4K random write operations. On typical eMMC with finite write cycles, continuous swapping degrades flash cells rapidly, leading to read-only lock or permanent motherboard failure within months.
2. **I/O Latency Bottleneck**:
   Random 4K write speeds on TV flash are ~15–25 MB/s with high latency. When the Linux kernel pages out active memory to slow storage during 4K video playback, severe UI freezes, dropped video frames, and ANR (Application Not Responding) dialogues occur.
3. **Android 14 AVB (Android Verified Boot) Security**:
   The RTD2875P platform under Android 14 enforces cryptographically signed `vbmeta` partitions. Modifying `boot.img` without authorized manufacturer keys triggers bootloops that cannot be easily recovered without EDL/UART service tools.
4. **zRAM Is Already Active**:
   The TV already features **1000 MB of hardware-accelerated zRAM** in kernel RAM with a **4.5x compression ratio** (storing ~390 MB of compressed pages into just ~85 MB of physical RAM).

---

## 3. Debloat Audit: 28 Disabled Services

To liberate physical memory for 4K video decoders and TorrServer, 28 non-essential background processes, tracking daemons, and vendor bloatware were disabled via `pm disable-user --user 0`:

### A. Screensavers & Ambient Services
- `com.google.android.apps.tv.dreamx`: Google TV Ambient screensaver (**freed ~110 MB RAM**).
- `com.android.dreams.basic`: Android basic daydream service.

### B. Telemetry & Background Tracking
- `tv.samba.ssm.ui`: Samba TV Automated Content Recognition (ACR) tracking.
- `com.tcl.logkit`: TCL continuous diagnostic log collector.
- `com.tcl.usercenter` & `com.tcl.useragreement`: TCL account and telemetry sync.
- `com.google.android.feedback`: Google crash reporting agent.
- `Privacy Sandbox` & ad measurement daemons disabled via `device_config`.

### C. TCL Background Bloatware
- `com.tcl.smartlink.core`: TCL smart device mesh service.
- `com.tcl.tv.tclhome_passive`: TCL Home background sync.
- `com.tcl.channelplus`: TCL TV+ ad channels and live stream pusher.
- `com.tcl.smartalexa`: Alexa integration service.
- `com.tcl.messagebox`: Floating notification service.
- `com.tcl.waterfall.overseas`: Content feed aggregator.
- `com.tcl.browser`: TCL preinstalled web browser.
- `com.tcl.esticker` & `com.tcl.exhibit`: Store retail demonstration apps.
- `com.tcl.ocean.instructions` & `com.tcl.repairguide`: Manuals and guides.
- `com.tcl.t_solo`, `com.tcl.interactive`, `com.tcl.magiconnectfree`.

### D. Unused Android System Services
- `com.android.printspooler`: Print spooler service (unneeded on TV).
- `com.google.android.play.games`: Google Play Games on TV.
- `com.google.android.videos`: Obsolete Google Play Movies.
- `com.google.android.marvin.talkback`: TalkBack accessibility screen reader.

### E. Preserved Essential Features
- **Netflix (`com.netflix.ninja`)**: Untouched; full 4K HDR & Dolby Vision support preserved.
- **Voice Search (`com.google.android.katniss` + `com.google.android.tts`)**: Remote microphone search remains 100% operational.
- **Core TV Inputs & Remote HDMI Switcher**:
  - `com.tcl.tv` & `com.tcl.tvinput`: Core TV tuner and HDMI pass-through services.
  - `com.tcl.suspension` (`Quick_Panel.apk`): Provides the physical remote's Source / Inputs overlay menu (`InputActivity` / `com.android.tv.action.VIEW_INPUTS`).
  - `com.tcl.dashboard`: Side settings / inputs dashboard overlay.
  - `com.tcl.gamebar`: Game Master overlay bar for HDMI gaming sources.
  - `com.tcl.guard`: Required system permissions for HDMI-CEC active source switching.

---

## 4. Operating System & Kernel Memory Tuning

```bash
# 1. Limit cached background applications to prevent RAM exhaustion
device_config put activity_manager max_cached_processes 8

# 2. Disable Android Phantom Process Killer to protect TorrServer / AceStream
device_config put activity_manager max_phantom_processes 2147483647
settings put global settings_enable_monitor_phantom_procs false

# 3. Double UI animation responsiveness and reduce GPU compositor overhead
settings put global window_animation_scale 0.5
settings put global transition_animation_scale 0.5
settings put global animator_duration_scale 0.5

# 4. Disable advertising tracking and telemetry
settings put secure limit_ad_tracking 1
settings put secure ad_personalization_enabled 0
settings put global send_action_app_error 0
```

**Result**: Free physical RAM rose from ~340 MB to **over 420 MB**, while available memory increased to ~860 MB.

---

## 5. TorrServer 4K Streaming Pipeline Optimization

### Root Cause of Long Buffering & Crashes
1. **Oversized Preload Buffer**:
   When cache was set to 1024 MB with a 50% preload buffer, TorrServer required **512 MB to download before playback could start**. On average torrent seed speeds (~12 Mbps / 1.5 MB/s), downloading 512 MB required **over 5–6 minutes of buffering**.
2. **FAT32 (vfat) 4 GB File Size Limit**:
   The USB drive was formatted as FAT32. When streaming high-bitrate 4K movies (e.g., *The End of Oak Street*, 18.22 GB), FAT32 threw an I/O error (`storage.Piece.ReadAt` timeout) once allocations exceeded 4 GB.

### Implemented High-Speed RAM Sliding Window Solution
Configured TorrServer via REST API (`POST http://localhost:8090/settings`):
- **Cache Size (`CacheSize`)**: `83,886,080` (80 MB in RAM).
- **Preload Cache (`PreloadCache`)**: `25%` (**20 MB total preload**).
- **Disk Caching (`UseDisk`)**: `false` (Operates entirely in ultra-high-speed RAM at >3000 MB/s).
- **Lookahead (`ReaderReadAHead`)**: `95%`.
- **Active Protocols**: TCP, uTP, DHT, PEX enabled; 30 peer connections limit.

### Validation Result
- Preload time dropped from 340+ seconds to **8–12 seconds**.
- Tested live on **The End of Oak Street (2026) 4K WEB-DL HDR10 Dolby Vision H.265 (18.22 GB)**:
  - Smooth continuous playback confirmed at 24:46 without drops or out-of-memory errors.

---

## 6. Google TV Launcher Analysis & Alternatives

### Modifying Stock Launcher (`com.google.android.apps.tv.launcherx`)
- The prebuilt APK resides in `/product/priv-app/TVLauncherXPrebuilt/TVLauncherXPrebuilt.apk` signed by Google release keys.
- Re-signing with custom keys causes `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
- Renaming package drops `signature|privileged` permissions, triggering immediate startup crashes.

### Verified Approaches:
1. **Google TV Built-in "Apps-Only Mode"**:
   - `Settings -> Accounts & Sign-In -> [Profile] -> Apps-only mode -> Turn on`.
   - Removes all promotional banners, trailers, and algorithmic feeds while retaining native UI.
2. **Projectivy Launcher**:
   - The community-standard lightweight launcher (~35 MB RAM vs 300 MB Google TV).
   - Zero ads, 60 FPS UI, full remote shortcut support.

---

## 7. Repository Structure

```
├── .gitignore                      # Excludes large binaries and temporary screenshots
├── README.md                       # Comprehensive engineering report
└── scripts/
    ├── optimize-tv.ps1             # Automated ADB debloat & OS optimization
    ├── restore-tv.ps1              # Full revert script for disabled packages
    └── configure-torrserver.ps1    # Automated REST API configuration for TorrServer
```

---

## 8. Quick Start

### Running the Optimization:
```powershell
.\scripts\optimize-tv.ps1 -DeviceIp "192.168.0.22:5555"
```

### Configuring TorrServer:
```powershell
.\scripts\configure-torrserver.ps1 -TorrServerUrl "http://192.168.0.22:8090"
```

### Reverting Package Changes:
```powershell
.\scripts\restore-tv.ps1 -DeviceIp "192.168.0.22:5555"
```
