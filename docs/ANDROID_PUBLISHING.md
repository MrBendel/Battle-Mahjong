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

The Play Console email list `Battle Mahjong Internal Testers` contains `andrew.b.poes@gmail.com` and `dancingplatypus@gmail.com`. Keep the list selected on the Internal testing track. Testers join through:

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

## GitHub Actions PR Hashtag Trigger

You can automatically trigger a build and publish to Google Play Internal testing directly from any Pull Request by including `#deploy-playstore` or `#build-and-deploy` in either:
- The **Pull Request Description** (when opening, updating, or editing a PR), or
- A **Pull Request Comment**.

The workflow (`.github/workflows/deploy_playstore_hashtag.yml`):
1. Reacts with `🚀` to your PR or comment.
2. Checks out the PR code.
3. Sets up Godot 4.6.3 and Android SDK.
4. Runs the core test suite (`res://tests/cli_test_runner.gd`).
5. Decodes the release keystore and sets a monotonic 2020-epoch version code.
6. Exports a signed release bundle (`.aab`).
7. Uploads to the Google Play Internal testing track.
8. Posts a status comment back on the PR with version details.

### Required GitHub Repository Secrets

Configure the following secrets in GitHub Repository Settings (`Settings > Secrets and variables > Actions`):

- `PLAY_STORE_JSON_KEY`: Plaintext content of `secrets/battle-mahjong-7b9090be6d44.json`.
- `ANDROID_KEYSTORE_BASE64`: Base64 encoded string of `secrets/battle-mahjong-upload.keystore` (e.g. `[Convert]::ToBase64String([IO.File]::ReadAllBytes('secrets/battle-mahjong-upload.keystore'))`).
- `ANDROID_KEYSTORE_ALIAS`: Keystore key alias from `secrets/android-upload.env`.
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password from `secrets/android-upload.env`.

## Google Play In-App Updates Integration

The game uses `UpdateChecker` (`res://scripts/presentation/update_checker.gd`) to interface with native Google Play Core in-app update plugins (`GodotPlayCore`, `GodotGooglePlayInAppUpdate`, `InAppUpdate`).

- **Android Runtime**: `UpdateChecker` discovers native Play Core plugins at runtime, checks Play Store update availability, and triggers flexible or immediate in-app updates via `start_in_app_update()`.
- **Offline / Non-Android Fallback**: When running off-Android or without native plugins, `UpdateChecker` operates fully offline without issuing external HTTP network requests.



