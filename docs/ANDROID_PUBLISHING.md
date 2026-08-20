# Android Internal Testing Publishing

Battle Mahjong exports Android App Bundles for package `com.platypus.battlemahjong` and publishes them to the Google Play Internal testing track through the Google Play Developer API.

## Local Toolchain

The validated Windows toolchain is:

- Godot `4.6.3.stable` with matching export templates;
- Microsoft OpenJDK 17;
- Android SDK Platform 35 and 36;
- Android SDK Build-Tools 35.0.1;
- Android Platform-Tools 37.0.1;
- Android NDK r28b (`28.1.13356709`);
- CMake `3.10.2.4988404`.

Godot Editor Settings records the local JDK and Android SDK paths under `Export > Android`. The publisher installs the matching generated Gradle build template when exporting; the generated `android/` directory is ignored.

The export targets API 36. Google Play requires API 36 for new apps and updates beginning August 31, 2026. Platform 35 remains installed because it is part of Godot 4.6.3's documented Android toolchain baseline.

## Local Secrets

All publishing credentials live under the ignored `secrets/` directory:

- `battle-mahjong-upload.keystore`: Android upload identity;
- `android-upload.env`: keystore alias and generated password;
- `battle-mahjong-7b9090be6d44.json`: Google Play service-account key.

Back up the keystore and `android-upload.env` together in a secure location. The service-account JSON can be revoked and replaced in Google Cloud, but it should also remain outside Git.

Verify the ignore boundary from the repository root:

```powershell
git check-ignore -v -- secrets/battle-mahjong-upload.keystore secrets/android-upload.env secrets/battle-mahjong-7b9090be6d44.json
git status --short --ignored secrets
```

Every path must be attributed to `/secrets/` in `.gitignore`, and none may appear as an untracked file.

## Export Without Uploading

```powershell
powershell -ExecutionPolicy Bypass -File scripts/publish_internal.ps1 -ExportOnly
```

The script runs the core test suite, assigns a monotonic local version code, exports a signed AAB, and restores the tracked preset version afterward. The bundle is written to ignored path `build/android/battle-mahjong.aab`.

The export preset excludes secrets, tests, documentation, source artwork, captured videos, and Codex working files. Before any upload, the script also inspects the finished bundle for excluded paths and verifies its signature.

Use `-SkipTests` only when the same commit has already passed validation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/publish_internal.ps1 -ExportOnly -SkipTests
```

## Publish To Internal Testing

```powershell
powershell -ExecutionPolicy Bypass -File scripts/publish_internal.ps1
```

The publisher creates a temporary Play edit, uploads the signed AAB, replaces the Internal track release with the new version, and commits the edit. Failed edits are deleted. The service-account token and signing password are never printed.

The service-account email must appear as **Active** under Play Console **Users and permissions**. Grant it app access to Battle Mahjong and permission to release to testing tracks. A Google Cloud IAM role alone does not grant Play Console access.

The Play Console email list `Battle Mahjong Internal Testers` contains `andrew.b.poes@gmail.com`. Keep the list selected on the Internal testing track. Testers join through:

`https://play.google.com/apps/internaltest/4701554282456194202`

The tester must open the link with an authorized Google account and accept the invitation before Google Play offers the test build.

## Versioning

By default, version codes are whole UTC seconds since January 1, 2020. This provides monotonic codes without modifying tracked files. Override release identity when needed:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/publish_internal.ps1 `
  -VersionCode 210000001 `
  -VersionName "0.2.0-internal.1"
```

Google Play rejects a version code that has already been uploaded.
