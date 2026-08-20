[CmdletBinding()]
param(
    [switch]$SkipTests,
    [switch]$ExportOnly,
    [int]$VersionCode = 0,
    [string]$VersionName = "",
    [string]$Track = "internal",
    [string]$ReleaseNotes = "Automated Battle Mahjong device-testing build."
)

$ErrorActionPreference = "Stop"
$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$Godot = "C:\Tools\Godot\godot.exe"
$JavaHome = Join-Path $env:USERPROFILE "tools\Java\jdk-17.0.20+8"
$Jarsigner = Join-Path $JavaHome "bin\jarsigner.exe"
$AndroidHome = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$Secrets = Join-Path $RepoRoot "secrets"
$CredentialFile = Join-Path $Secrets "android-upload.env"
$ServiceAccount = Join-Path $Secrets "battle-mahjong-7b9090be6d44.json"
$Bundle = Join-Path $RepoRoot "build\android\battle-mahjong.aab"
$PresetFile = Join-Path $RepoRoot "export_presets.cfg"
$PublisherPython = Join-Path $Secrets ".play-publisher-venv\Scripts\python.exe"
$PackageName = "com.platypus.battlemahjong"

function Invoke-Checked {
    param([string]$FilePath, [string[]]$Arguments)
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath"
    }
}

function Invoke-Godot {
    param([string[]]$Arguments)
    $stdout = Join-Path $env:TEMP ("battle-mahjong-godot-{0}.out.txt" -f [Guid]::NewGuid())
    $stderr = Join-Path $env:TEMP ("battle-mahjong-godot-{0}.err.txt" -f [Guid]::NewGuid())
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

function Import-EnvironmentFile {
    param([string]$Path)
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }
        $separator = $line.IndexOf("=")
        if ($separator -le 0) {
            throw "Invalid environment entry in $Path"
        }
        $name = $line.Substring(0, $separator)
        $value = $line.Substring($separator + 1)
        Set-Item -Path "Env:$name" -Value $value
    }
}

function Test-AndroidBundle {
    param([string]$Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $forbidden = @($archive.Entries | Where-Object {
            $_.FullName -match '(^|/)(secrets|docs|tests|videos|art-source|\.codex-remote-attachments|\.codex-state)(/|$)' -or
            $_.FullName -match '(android-upload|battle-mahjong-7b9090be6d44|\.keystore$)'
        })
        if ($forbidden.Count -gt 0) {
            throw "Android bundle contains excluded development or secret files."
        }
    }
    finally {
        $archive.Dispose()
    }

    & $Jarsigner -verify $Path *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Android bundle signature verification failed."
    }
}

foreach ($requiredPath in @($Godot, $JavaHome, $Jarsigner, $AndroidHome, $CredentialFile, $ServiceAccount, $PresetFile)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required Android publishing path is missing: $requiredPath"
    }
}

Import-EnvironmentFile -Path $CredentialFile
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidHome
$env:ANDROID_SDK_ROOT = $AndroidHome
$env:GRADLE_OPTS = "-Dorg.gradle.daemon=false"

foreach ($secretPath in @($CredentialFile, $ServiceAccount, $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH)) {
    & git -C $RepoRoot check-ignore -q -- $secretPath
    if ($LASTEXITCODE -ne 0) {
        throw "Refusing to publish because a secret is not ignored by Git: $secretPath"
    }
}

if ($VersionCode -le 0) {
    $epoch = [DateTimeOffset]::new(2020, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
    $VersionCode = [int][Math]::Floor(([DateTimeOffset]::UtcNow - $epoch).TotalSeconds)
}
if ([string]::IsNullOrWhiteSpace($VersionName)) {
    $VersionName = "0.1.0-internal.$VersionCode"
}

Push-Location $RepoRoot
try {
    if (-not $SkipTests) {
        Invoke-Godot -Arguments @(
            "--headless", "--path", ".", "--script", "res://tests/cli_test_runner.gd"
        )
    }

    $presetBackup = [IO.File]::ReadAllBytes($PresetFile)
    try {
        Invoke-Godot -Arguments @(
            "--headless", "--path", ".",
            "--script", "res://scripts/tools/set_android_export_version.gd",
            "--", $VersionCode.ToString(), $VersionName
        )
        New-Item -ItemType Directory -Force -Path (Split-Path $Bundle) | Out-Null
        Invoke-Godot -Arguments @(
            "--headless", "--path", ".", "--install-android-build-template",
            "--export-release", "Android", $Bundle
        )
    }
    finally {
        [IO.File]::WriteAllBytes($PresetFile, $presetBackup)
    }

    if (-not (Test-Path -LiteralPath $Bundle)) {
        throw "Godot did not produce the expected app bundle: $Bundle"
    }
    Test-AndroidBundle -Path $Bundle
    Write-Output "Exported Battle Mahjong $VersionName ($VersionCode)."

    if ($ExportOnly) {
        Write-Output "Export-only mode completed; no Play Console edit was created."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $PublisherPython)) {
        Invoke-Checked -FilePath "python" -Arguments @(
            "-m", "venv", (Join-Path $Secrets ".play-publisher-venv")
        )
    }
    & $PublisherPython -c "import google.auth, requests" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Checked -FilePath $PublisherPython -Arguments @(
            "-m", "pip", "install", "--disable-pip-version-check", "--quiet",
            "-r", (Join-Path $RepoRoot "scripts\tools\play_publish_requirements.txt")
        )
    }

    Invoke-Checked -FilePath $PublisherPython -Arguments @(
        (Join-Path $RepoRoot "scripts\tools\play_publish.py"),
        "--service-account", $ServiceAccount,
        "--bundle", $Bundle,
        "--package", $PackageName,
        "--track", $Track,
        "--release-name", $VersionName,
        "--release-notes", $ReleaseNotes
    )
}
finally {
    Pop-Location
}
