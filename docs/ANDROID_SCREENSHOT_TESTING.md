# Android Screenshot Testing

Battle Mahjong tests Android orientation and safe-area behavior at two levels:

- The Godot UI smoke runner injects asymmetric portrait and landscape insets. This catches layout math regressions quickly without starting Android.
- `scripts/test_android_screenshots.ps1` exports and installs the target-SDK-36 x86_64 debug APK on an API 36 emulator, launches portrait-first, relaunches in landscape and portrait, validates the safe-area geometry reported by Android, and captures the rendered Godot viewport in each state.

Android Emulator and ADB are the appropriate integration layer for this project. Native Android screenshot libraries do not inspect controls rendered inside Godot's surface.

## One-Time Setup

The harness expects the Android SDK under `%LOCALAPPDATA%\Android\Sdk`, OpenJDK 17 under `%USERPROFILE%\tools\Java\jdk-17.0.20+8`, and Godot 4.6.3 at `C:\Tools\Godot\godot.exe`.

Install the emulator image and hypervisor-driver package:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" `
  "emulator" `
  "system-images;android-36;google_apis;x86_64" `
  "extras;google;Android_Emulator_Hypervisor_Driver"
```

The hypervisor driver itself requires elevation. Run this once from an Administrator PowerShell and reboot if Windows requests it:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\extras\google\Android_Emulator_Hypervisor_Driver\silent_install.bat"
```

Verify acceleration before running the suite:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -accel-check
```

## Run

Fast Godot checks with synthetic asymmetric insets:

```powershell
godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --portrait --safe-area
godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --landscape --safe-area
```

Full Android export, rotation, safe-area, and screenshot run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test_android_screenshots.ps1
```

Use `-SkipBuild` to reuse the existing APK or `-KeepEmulator` to leave an emulator started by the script running. The script reuses an already-running emulator when one is connected.

Captures are written to the ignored `build/android/screenshots/` directory:

- `android-portrait-start.png`
- `android-landscape.png`
- `android-portrait-return.png`

The Android test verifies that the packaged manifest declares Godot's `SCREEN_SENSOR` mode (`fullUser`, compiled value `13`). The harness launches a fresh process in portrait, landscape, and portrait again because hot rotation on the emulator can relaunch and terminate Godot's reused activity fragment. On a physical device, manually verify that the live app follows rotation; startup follows the orientation in which the device is held while respecting its rotation preference.

The emulator's software compositor can fail to present Godot frames even while the renderer is running. Captures therefore come from `ViewportTexture.get_image()` inside the debug APK and are pulled from app-private storage with `run-as`. The suite verifies their dimensions and sampled contrast so a blank or flat frame cannot pass.
