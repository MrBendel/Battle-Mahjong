[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$KeepEmulator,
    [string]$AvdName = "BattleMahjongApi36"
)

$ErrorActionPreference = "Stop"
$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$Godot = "C:\Tools\Godot\godot.exe"
$JavaHome = Join-Path $env:USERPROFILE "tools\Java\jdk-17.0.20+8"
$AndroidHome = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$Adb = Join-Path $AndroidHome "platform-tools\adb.exe"
$Emulator = Join-Path $AndroidHome "emulator\emulator.exe"
$AvdManager = Join-Path $AndroidHome "cmdline-tools\latest\bin\avdmanager.bat"
$ApkAnalyzer = Join-Path $AndroidHome "cmdline-tools\latest\bin\apkanalyzer.bat"
$Apk = Join-Path $RepoRoot "build\android\screenshots\battle-mahjong-debug.apk"
$OutputDirectory = Join-Path $RepoRoot "build\android\screenshots"
$PackageName = "com.platypus.battlemahjong"
$SystemImage = "system-images;android-36;google_apis;x86_64"
$StartedEmulator = $null
$EnabledCutout = ""

function Invoke-Checked {
    param([string]$FilePath, [string[]]$Arguments)
    $output = & $FilePath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath`n$output"
    }
    return $output
}

function Invoke-Godot {
    param([string[]]$Arguments)
    $stdout = Join-Path $env:TEMP ("battle-mahjong-android-test-{0}.out.txt" -f [Guid]::NewGuid())
    $stderr = Join-Path $env:TEMP ("battle-mahjong-android-test-{0}.err.txt" -f [Guid]::NewGuid())
    try {
        $process = Start-Process -FilePath $Godot `
            -ArgumentList $Arguments `
            -WorkingDirectory $RepoRoot `
            -WindowStyle Hidden `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdout `
            -RedirectStandardError $stderr
        Get-Content -LiteralPath $stdout, $stderr -ErrorAction SilentlyContinue
        if ($process.ExitCode -ne 0) {
            throw "Godot failed with exit code $($process.ExitCode)."
        }
    }
    finally {
        Remove-Item -LiteralPath $stdout, $stderr -ErrorAction SilentlyContinue
    }
}

function Invoke-Adb {
    param([string[]]$Arguments)
    return Invoke-Checked -FilePath $Adb -Arguments (@("-s", $script:Serial) + $Arguments)
}

function Get-EmulatorSerial {
    $lines = & $Adb devices
    foreach ($line in $lines) {
        if ($line -match '^(emulator-\d+)\s+device$') {
            return $Matches[1]
        }
    }
    return ""
}

function Wait-ForEmulator {
    $deadline = [DateTime]::UtcNow.AddMinutes(4)
    while ([DateTime]::UtcNow -lt $deadline) {
        $candidate = Get-EmulatorSerial
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $script:Serial = $candidate
            $booted = (& $Adb -s $script:Serial shell getprop sys.boot_completed 2>$null) -join ""
            if ($booted.Trim() -eq "1") {
                return
            }
        }
        Start-Sleep -Seconds 2
    }
    throw "Android emulator did not finish booting within four minutes."
}

function Enable-Test-Cutout {
    $overlays = (Invoke-Adb -Arguments @("shell", "cmd", "overlay", "list")) -join "`n"
    $match = [regex]::Match($overlays, 'com\.android\.internal\.display\.cutout\.emulation\.(corner|double|tall)')
    if (-not $match.Success) {
        Write-Output "No display-cutout emulator overlay is available; continuing with system insets."
        return
    }
    $script:EnabledCutout = $match.Value
    Invoke-Adb -Arguments @("shell", "cmd", "overlay", "enable-exclusive", "--category", "--user", "0", $script:EnabledCutout) | Out-Null
    Start-Sleep -Seconds 1
}

function Read-LayoutProbe {
    param([string]$ExpectedOrientation)
    $deadline = [DateTime]::UtcNow.AddSeconds(25)
    while ([DateTime]::UtcNow -lt $deadline) {
        $json = (& $Adb -s $script:Serial exec-out run-as $PackageName cat files/android_layout_probe.json 2>$null) -join "`n"
        if (-not [string]::IsNullOrWhiteSpace($json)) {
            try {
                $probe = $json | ConvertFrom-Json
                if ($probe.orientation -eq $ExpectedOrientation) {
                    return $probe
                }
            }
            catch {
                # The app may be replacing the probe while ADB reads it.
            }
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Android layout probe never reported $ExpectedOrientation orientation."
}

function Assert-LayoutProbe {
    param($Probe, [string]$ExpectedOrientation)
    $width = [double]$Probe.viewport.width
    $height = [double]$Probe.viewport.height
    if ($ExpectedOrientation -eq "portrait" -and $width -ge $height) {
        throw "Expected portrait viewport, received ${width}x${height}."
    }
    if ($ExpectedOrientation -eq "landscape" -and $width -le $height) {
        throw "Expected landscape viewport, received ${width}x${height}."
    }

    $left = [double]$Probe.insets.left
    $top = [double]$Probe.insets.top
    $right = $width - [double]$Probe.insets.right
    $bottom = $height - [double]$Probe.insets.bottom
    $controls = @($Probe.regions.PSObject.Properties.Value) + @($Probe.controls.PSObject.Properties.Value)
    foreach ($rect in $controls) {
        $rectRight = [double]$rect.x + [double]$rect.width
        $rectBottom = [double]$rect.y + [double]$rect.height
        if ([double]$rect.x -lt $left - 0.5 -or [double]$rect.y -lt $top - 0.5 -or
            $rectRight -gt $right + 0.5 -or $rectBottom -gt $bottom + 0.5) {
            throw "$ExpectedOrientation control escaped the Android safe area: $($rect | ConvertTo-Json -Compress)"
        }
    }
}

function Capture-Orientation {
    param([string]$Name, [int]$Rotation, [string]$Suffix)
    Invoke-Adb -Arguments @("shell", "settings", "put", "system", "accelerometer_rotation", "0") | Out-Null
    Invoke-Adb -Arguments @("shell", "settings", "put", "system", "user_rotation", $Rotation.ToString()) | Out-Null
    Invoke-Adb -Arguments @("shell", "am", "force-stop", $PackageName) | Out-Null
    Invoke-Adb -Arguments @("shell", "run-as", $PackageName, "rm", "-f", "files/android_layout_probe.json") | Out-Null
    Invoke-Adb -Arguments @("shell", "run-as", $PackageName, "rm", "-f", "files/android_viewport_capture.png") | Out-Null
    Invoke-Adb -Arguments @("shell", "am", "start", "-n", "$PackageName/com.godot.game.GodotAppLauncher") | Out-Null
    Start-Sleep -Seconds 2

    $probe = Read-LayoutProbe -ExpectedOrientation $Name
    Assert-LayoutProbe -Probe $probe -ExpectedOrientation $Name
    Start-Sleep -Seconds 2
    $local = Join-Path $OutputDirectory "android-$Suffix.png"
    $captureDeadline = [DateTime]::UtcNow.AddSeconds(15)
    while ([DateTime]::UtcNow -lt $captureDeadline) {
        & $Adb -s $script:Serial exec-out run-as $PackageName cat files/android_viewport_capture.png 2>$null > $local
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $local) -and (Get-Item -LiteralPath $local).Length -gt 100) {
            break
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not (Test-Path -LiteralPath $local) -or (Get-Item -LiteralPath $local).Length -le 100) {
        throw "Godot did not produce the $Name Android viewport capture."
    }

    Add-Type -AssemblyName System.Drawing
    $image = [Drawing.Image]::FromFile($local)
    try {
        if ($Name -eq "portrait" -and $image.Width -ge $image.Height) {
            throw "Portrait screenshot has unexpected dimensions $($image.Width)x$($image.Height)."
        }
        if ($Name -eq "landscape" -and $image.Width -le $image.Height) {
            throw "Landscape screenshot has unexpected dimensions $($image.Width)x$($image.Height)."
        }
        $bitmap = [Drawing.Bitmap]$image
        $visiblePixels = 0
        $sampleCount = 0
        $minimumLuma = 765
        $maximumLuma = 0
        $stepX = [Math]::Max(1, [int]($bitmap.Width / 48))
        $stepY = [Math]::Max(1, [int]($bitmap.Height / 48))
        for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
            for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
                $pixel = $bitmap.GetPixel($x, $y)
                $sampleCount++
                $luma = $pixel.R + $pixel.G + $pixel.B
                $minimumLuma = [Math]::Min($minimumLuma, $luma)
                $maximumLuma = [Math]::Max($maximumLuma, $luma)
                if ($luma -gt 30) {
                    $visiblePixels++
                }
            }
        }
        if ($visiblePixels -lt [Math]::Max(1, [int]($sampleCount * 0.02)) -or ($maximumLuma - $minimumLuma) -lt 40) {
            throw "$Name screenshot is blank or flat ($visiblePixels of $sampleCount visible samples; luma range $minimumLuma-$maximumLuma)."
        }
    }
    finally {
        $image.Dispose()
    }
    Write-Output "Captured $Name Android screenshot: $local"
}

foreach ($required in @($Godot, $JavaHome, $AndroidHome, $Adb, $Emulator, $AvdManager, $ApkAnalyzer)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required Android screenshot-test dependency is missing: $required"
    }
}

$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidHome
$env:ANDROID_SDK_ROOT = $AndroidHome
$env:GRADLE_OPTS = "-Dorg.gradle.daemon=false"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$buildIgnore = Join-Path $RepoRoot "build\.gdignore"
if (-not (Test-Path -LiteralPath $buildIgnore)) {
    [IO.File]::WriteAllText($buildIgnore, "")
}

Push-Location $RepoRoot
try {
    if (-not $SkipBuild) {
        Invoke-Godot -Arguments @(
            "--headless", "--path", ".", "--install-android-build-template",
            "--export-debug", "AndroidScreenshots", $Apk
        )
    }
    if (-not (Test-Path -LiteralPath $Apk)) {
        throw "Android screenshot APK is missing: $Apk"
    }

    $manifest = (Invoke-Checked -FilePath $ApkAnalyzer -Arguments @("manifest", "print", $Apk)) -join "`n"
    # Godot maps SCREEN_SENSOR to Android fullUser. apkanalyzer may render the
    # compiled enum numerically.
    if ($manifest -notmatch 'android:screenOrientation="(?:fullUser|13)"') {
        throw "Android manifest must request Godot's sensor orientation."
    }

    $script:Serial = Get-EmulatorSerial
    if ([string]::IsNullOrWhiteSpace($script:Serial)) {
        $acceleration = (& $Emulator -accel-check 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            $driverInstaller = Join-Path $AndroidHome "extras\google\Android_Emulator_Hypervisor_Driver\silent_install.bat"
            throw "Android emulator acceleration is unavailable.`n$acceleration`nRun this once from an elevated PowerShell, then reboot if requested:`n& `"$driverInstaller`""
        }
        $avds = (Invoke-Checked -FilePath $Emulator -Arguments @("-list-avds")) -join "`n"
        if ($avds -notmatch "(?m)^$([regex]::Escape($AvdName))$") {
            "no" | & $AvdManager create avd --force --name $AvdName --package $SystemImage --device "pixel_7"
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to create Android virtual device $AvdName."
            }
        }
        $script:StartedEmulator = Start-Process -FilePath $Emulator `
            -ArgumentList @("-avd", $AvdName, "-no-snapshot-save", "-no-boot-anim", "-no-audio", "-gpu", "swiftshader") `
            -WindowStyle Hidden `
            -PassThru
        Wait-ForEmulator
    }

    Enable-Test-Cutout
    Invoke-Adb -Arguments @("shell", "settings", "put", "secure", "immersive_mode_confirmations", "confirmed") | Out-Null
    Invoke-Adb -Arguments @("install", "-r", $Apk) | Out-Null

    Capture-Orientation -Name "portrait" -Rotation 0 -Suffix "portrait-start"
    Capture-Orientation -Name "landscape" -Rotation 1 -Suffix "landscape"
    Capture-Orientation -Name "portrait" -Rotation 0 -Suffix "portrait-return"
    Write-Output "PASS: Android portrait, landscape, return portrait, safe-area, and screenshot checks."
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($script:Serial)) {
        & $Adb -s $script:Serial shell settings put system accelerometer_rotation 1 2>$null | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($EnabledCutout)) {
            & $Adb -s $script:Serial shell cmd overlay disable --user 0 $EnabledCutout 2>$null | Out-Null
        }
    }
    if ($StartedEmulator -ne $null -and -not $KeepEmulator) {
        & $Adb -s $script:Serial emu kill 2>$null | Out-Null
    }
    Pop-Location
}
