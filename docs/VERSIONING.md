# Application Versioning

Battle Mahjong uses semantic application versions independently from gameplay rules versions, data schema versions, and replay compatibility.

## Canonical Version

The tracked application version is `preset.0.options.version/name` in `export_presets.cfg`. It must be a plain `major.minor.patch` value such as `0.1.1`.

`version.json` is generated publication metadata. It records the most recently prepared Play build and is not the source of truth for the next application version.

## Pull Request Rule

Before submitting every PR, increment the patch component exactly once relative to that PR's base branch:

```text
0.1.1 -> 0.1.2
```

Update both Android presets:

- `Android` uses the plain version, such as `0.1.2`;
- `AndroidScreenshots` uses the same base with `-screenshot`, such as `0.1.2-screenshot`.

Increment the tracked preset version code alongside the patch for coherent local debug metadata. Google Play uploads do not use this small tracked code; publishing assigns a monotonic code automatically.

For a stacked PR, compare against its immediate base branch. If rebasing or retargeting creates a version collision, advance to the next unused patch version before updating the PR.

## Play Builds

Google Play update eligibility is determined by Android `versionCode`, not the semantic version name. CI and `scripts/publish_internal.ps1` generate a monotonic code from whole UTC seconds since January 1, 2020.

Release version names combine the tracked semantic version and generated code:

```text
0.1.2-internal.209700000
```

This gives every device build a readable feature version and a unique Play identity. Do not hard-code a release base version in publishing scripts.

## Separate Version Domains

Do not conflate application versions with:

- `GameDefinition.rules_version`, which preserves deterministic gameplay and replay behavior;
- serialized schema versions, which control data migration and compatibility;
- tile-skin schema versions, which control cosmetic manifest parsing.

Changing one domain does not imply changing another.
