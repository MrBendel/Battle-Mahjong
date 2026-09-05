[CmdletBinding()]
param(
    [string]$Serial = "",
    [string[]]$Scenarios = @("all"),
    [ValidateRange(3, 60)]
    [int]$CaptureSeconds = 10,
    [string]$OutputDirectory = "",
    [string]$ApkPath = "",
    [switch]$ListScenarios
)

$ErrorActionPreference = "Stop"
$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$AndroidHome = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$Adb = Join-Path $AndroidHome "platform-tools\adb.exe"
$PackageName = "com.platypus.battlemahjong"
$LauncherActivity = "com.godot.game.GodotAppLauncher"
$ScenarioInstructions = [ordered]@{
    idle_fresh_board = "Restart the game and leave the fresh 96-tile board untouched."
    ordinary_selection = "Start with a stable board, then repeatedly select ordinary unmatched tiles during capture. Restart before the tray fills."
    natural_pair = "Prepare a visible pair, then resolve pairs and allow their queue collision/removal animations to finish during capture."
    hint_glow = "Start with Hint available, activate it after GO, and leave the two hinted tiles glowing."
    shuffle = "Start with Shuffle available and activate it once immediately after GO."
    lifecycle_resume = "The harness will background and foreground the game five times automatically."
    late_game_board = "Play until relatively few board tiles remain, then leave that late-game board visible."
}

function Invoke-Adb {
    param([string[]]$Arguments, [switch]$AllowFailure)
    $output = & $Adb -s $script:Serial @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "ADB command failed with exit code ${exitCode}: adb $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return @($output)
}

function Get-ConnectedDevices {
    $devices = @()
    foreach ($line in (& $Adb devices -l)) {
        if ($line -match '^(\S+)\s+device(?:\s|$)') {
            $devices += $Matches[1]
        }
    }
    return $devices
}

function Get-AdbValue {
    param([string[]]$Arguments)
    return ((Invoke-Adb -Arguments $Arguments -AllowFailure) -join "`n").Trim()
}

function Get-Percentile {
    param([double[]]$SortedValues, [double]$Percentile)
    if ($SortedValues.Count -eq 0) {
        return 0.0
    }
    $index = [Math]::Max(0, [Math]::Min(
        $SortedValues.Count - 1,
        [Math]::Ceiling($Percentile * $SortedValues.Count) - 1
    ))
    return [Math]::Round($SortedValues[$index], 3)
}

function Convert-GfxInfoToSummary {
    param([string[]]$Lines)
    $header = @{}
    $durations = [Collections.Generic.List[double]]::new()
    $insideProfileData = $false
    foreach ($lineValue in $Lines) {
        $line = [string]$lineValue
        if ($line.Trim() -eq "---PROFILEDATA---") {
            $insideProfileData = -not $insideProfileData
            $header = @{}
            continue
        }
        if (-not $insideProfileData -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        $columns = $line.Split(',')
        if ($line.StartsWith("Flags,")) {
            for ($index = 0; $index -lt $columns.Count; $index++) {
                $header[$columns[$index].Trim()] = $index
            }
            continue
        }
        if (-not $header.ContainsKey("IntendedVsync") -or -not $header.ContainsKey("FrameCompleted")) {
            continue
        }
        if ($columns.Count -le [Math]::Max($header.IntendedVsync, $header.FrameCompleted)) {
            continue
        }
        $intended = 0L
        $completed = 0L
        if (-not [long]::TryParse($columns[$header.IntendedVsync], [ref]$intended) -or
            -not [long]::TryParse($columns[$header.FrameCompleted], [ref]$completed)) {
            continue
        }
        if ($intended -le 0 -or $completed -lt $intended) {
            continue
        }
        $durations.Add([double]($completed - $intended) / 1000000.0)
    }

    $sorted = [double[]]@($durations | Sort-Object)
    $mean = 0.0
    if ($sorted.Count -gt 0) {
        $mean = [Math]::Round(($sorted | Measure-Object -Average).Average, 3)
    }
    return [ordered]@{
        frame_count = $sorted.Count
        frame_ms = [ordered]@{
            p50 = Get-Percentile -SortedValues $sorted -Percentile 0.50
            p95 = Get-Percentile -SortedValues $sorted -Percentile 0.95
            worst = if ($sorted.Count -gt 0) { [Math]::Round($sorted[-1], 3) } else { 0.0 }
            mean = $mean
        }
        frames_over_16_7_ms = @($sorted | Where-Object { $_ -gt 16.7 }).Count
        frames_over_33_3_ms = @($sorted | Where-Object { $_ -gt 33.3 }).Count
    }
}

function Start-Game {
    Invoke-Adb -Arguments @("shell", "am", "start", "-n", "$PackageName/$LauncherActivity") | Out-Null
    Start-Sleep -Seconds 2
}

function Invoke-LifecycleCycles {
    for ($cycle = 1; $cycle -le 5; $cycle++) {
        Invoke-Adb -Arguments @("shell", "input", "keyevent", "KEYCODE_HOME") | Out-Null
        Start-Sleep -Milliseconds 700
        Start-Game
        Write-Host "  lifecycle cycle $cycle/5"
    }
}

function Write-RawCapture {
    param([string]$Path, [object[]]$Content)
    [IO.File]::WriteAllLines($Path, [string[]]@($Content), [Text.UTF8Encoding]::new($false))
}

if ($ListScenarios) {
    foreach ($entry in $ScenarioInstructions.GetEnumerator()) {
        Write-Output ("{0}: {1}" -f $entry.Key, $entry.Value)
    }
    exit 0
}

if (-not (Test-Path -LiteralPath $Adb)) {
    throw "ADB was not found at $Adb. Install the configured Android SDK platform tools first."
}

$connectedDevices = @(Get-ConnectedDevices)
if ([string]::IsNullOrWhiteSpace($Serial)) {
    if ($connectedDevices.Count -eq 0) {
        throw "No authorized Android device is connected. Enable USB debugging, authorize this PC, and verify with adb devices -l."
    }
    if ($connectedDevices.Count -gt 1) {
        throw "More than one Android device is connected. Pass -Serial with one of: $($connectedDevices -join ', ')"
    }
    $Serial = $connectedDevices[0]
}
elseif ($Serial -notin $connectedDevices) {
    throw "Android device '$Serial' is not connected and authorized. Connected devices: $($connectedDevices -join ', ')"
}
$script:Serial = $Serial

if (-not [string]::IsNullOrWhiteSpace($ApkPath)) {
    $resolvedApk = [IO.Path]::GetFullPath((Join-Path $RepoRoot $ApkPath))
    if (-not (Test-Path -LiteralPath $resolvedApk)) {
        throw "APK not found: $resolvedApk"
    }
    Write-Host "Installing $resolvedApk"
    Invoke-Adb -Arguments @("install", "-r", $resolvedApk) | Out-Null
}

$packagePath = Get-AdbValue -Arguments @("shell", "pm", "path", $PackageName)
if (-not $packagePath.StartsWith("package:")) {
    throw "Battle Mahjong is not installed on device $Serial. Install it from Play Internal testing or pass -ApkPath."
}

$selectedScenarios = [Collections.Generic.List[string]]::new()
foreach ($scenario in $Scenarios) {
    if ($scenario -eq "all") {
        foreach ($knownScenario in $ScenarioInstructions.Keys) {
            $selectedScenarios.Add($knownScenario)
        }
        continue
    }
    if (-not $ScenarioInstructions.Contains($scenario)) {
        throw "Unknown scenario '$scenario'. Use -ListScenarios to list valid names."
    }
    if (-not $selectedScenarios.Contains($scenario)) {
        $selectedScenarios.Add($scenario)
    }
}

$timestamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $safeSerial = $Serial -replace '[^A-Za-z0-9._-]', '_'
    $OutputDirectory = Join-Path $RepoRoot "build\performance\android\$timestamp-$safeSerial"
}
elseif (-not [IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepoRoot $OutputDirectory
}
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$deviceInfo = [ordered]@{
    serial = $Serial
    manufacturer = Get-AdbValue -Arguments @("shell", "getprop", "ro.product.manufacturer")
    model = Get-AdbValue -Arguments @("shell", "getprop", "ro.product.model")
    device = Get-AdbValue -Arguments @("shell", "getprop", "ro.product.device")
    android_release = Get-AdbValue -Arguments @("shell", "getprop", "ro.build.version.release")
    sdk = Get-AdbValue -Arguments @("shell", "getprop", "ro.build.version.sdk")
    build_fingerprint = Get-AdbValue -Arguments @("shell", "getprop", "ro.build.fingerprint")
    display_size = Get-AdbValue -Arguments @("shell", "wm", "size")
    display_density = Get-AdbValue -Arguments @("shell", "wm", "density")
    package = $PackageName
    package_path = $packagePath
}

Write-RawCapture -Path (Join-Path $OutputDirectory "device-display.txt") -Content (Invoke-Adb -Arguments @("shell", "dumpsys", "display") -AllowFailure)
Write-RawCapture -Path (Join-Path $OutputDirectory "device-thermal.txt") -Content (Invoke-Adb -Arguments @("shell", "dumpsys", "thermalservice") -AllowFailure)
Write-Host "Capturing on $($deviceInfo.manufacturer) $($deviceInfo.model) ($Serial)"
Write-Host "Output: $OutputDirectory"
Start-Game

$results = [Collections.Generic.List[object]]::new()
foreach ($scenario in $selectedScenarios) {
    Write-Host ""
    Write-Host "SCENARIO: $scenario" -ForegroundColor Cyan
    Write-Host $ScenarioInstructions[$scenario]
    if ($scenario -ne "lifecycle_resume") {
        [void](Read-Host "Prepare the game, then press Enter")
    }
    Invoke-Adb -Arguments @("shell", "dumpsys", "gfxinfo", $PackageName, "reset") | Out-Null
    Write-Host "GO - capturing for $CaptureSeconds seconds" -ForegroundColor Green
    if ($scenario -eq "lifecycle_resume") {
        Invoke-LifecycleCycles
        $remainingSeconds = [Math]::Max(0, $CaptureSeconds - 9)
        if ($remainingSeconds -gt 0) {
            Start-Sleep -Seconds $remainingSeconds
        }
    }
    else {
        Start-Sleep -Seconds $CaptureSeconds
    }

    $gfxInfo = Invoke-Adb -Arguments @("shell", "dumpsys", "gfxinfo", $PackageName, "framestats")
    $memoryInfo = Invoke-Adb -Arguments @("shell", "dumpsys", "meminfo", $PackageName) -AllowFailure
    Write-RawCapture -Path (Join-Path $OutputDirectory "$scenario-gfxinfo.txt") -Content $gfxInfo
    Write-RawCapture -Path (Join-Path $OutputDirectory "$scenario-meminfo.txt") -Content $memoryInfo
    $summary = Convert-GfxInfoToSummary -Lines $gfxInfo
    if ($summary.frame_count -eq 0) {
        throw "Android gfxinfo returned no frames for '$scenario'. Godot may be rendering through a SurfaceView that gfxinfo cannot observe on this device; do not treat a zero-frame report as a valid benchmark."
    }
    $summary["name"] = $scenario
    $summary["capture_seconds"] = $CaptureSeconds
    $results.Add($summary)
    Write-Host ("Captured {0} frames: p50={1}ms p95={2}ms worst={3}ms >16.7={4} >33.3={5}" -f `
        $summary.frame_count,
        $summary.frame_ms.p50,
        $summary.frame_ms.p95,
        $summary.frame_ms.worst,
        $summary.frames_over_16_7_ms,
        $summary.frames_over_33_3_ms)
}

$report = [ordered]@{
    schema_version = 1
    captured_at_utc = [DateTime]::UtcNow.ToString("o")
    capture_type = "android_gfxinfo_assisted"
    capture_seconds_per_scenario = $CaptureSeconds
    device = $deviceInfo
    scenarios = $results
}
$reportPath = Join-Path $OutputDirectory "performance-android.json"
[IO.File]::WriteAllText(
    $reportPath,
    ($report | ConvertTo-Json -Depth 8),
    [Text.UTF8Encoding]::new($false)
)
Write-Host ""
Write-Host "Android performance report: $reportPath" -ForegroundColor Green
