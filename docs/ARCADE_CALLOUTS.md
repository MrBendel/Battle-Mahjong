# Arcade Callouts

Arcade callouts recognize exceptional play with live text and reusable presentation effects. They are presentation derived from committed transaction telemetry; they do not mutate gameplay, scoring, Combo, or replay state.

## Single Callout Lane

Only one alert may be shown at a time. A pair transaction is reduced to at most one alert using this priority:

1. Modifier rewards with their exact snapshotted effect, such as `EXTRA LIFE +1` or `SCORE BOOST 2.0X`.
2. One-time board progress such as `ALL TILES REVEALED!`.
3. Pair-difficulty recognition such as `WELL HIDDEN!`, `EAGLE EYES!`, or `AMAZING FIND!`.
4. Current-run score milestones such as `SCORE 10K!`.
5. Combo milestones such as `11 COMBO!`.

The renderer owns one live-text label. A new accepted alert replaces the active presentation rather than creating an overlapping label. Text is not baked into bitmap assets so localization and future announcer packs can consume the same event keys.

Callout typography, outline weight, vertical motion, and lane height scale from the rendered Board dimensions. Long localized or system copy is fitted to the available width after scaling, preserving legibility on high-resolution phones without clipping compact portrait layouts.

## Combo Cadence

Combo values through 10 never create large arcade callouts. The default first alert is 11, followed by each multiple of five (`15`, `20`, `25`, and so on). The compact Momentum-region Combo readout remains visible at lower values.

`ArcadeCalloutTuning` exposes the first Combo alert, recurring interval, score milestones, and top-percentile `AMAZING FIND!` cutoff in the Godot Inspector. These values affect presentation only and do not belong in deterministic game definitions.

## Score Milestones

Score milestones recognize progress inside the active run. Durable high-score callouts are intentionally excluded until M9 implements profile and game-library ownership.

## Current Scope

- Notable pair difficulty: `WELL HIDDEN!`.
- Exceptional pair difficulty: `EAGLE EYES!`.
- Top-percentile exceptional pair: `AMAZING FIND!`.
- Combo milestones beginning above 10.
- Configurable current-run score milestones.
- One-time flipped-tile completion: `ALL TILES REVEALED!`.
- Modifier rewards from natural, flipped, and Delete Pair resolution: Extra Life charges, Cold Snap duration, Score Multiplier strength, and Tray +1 pair duration.

The visual treatment is intentionally an extensible first slice. Additional phrases, announcer audio, and richer reusable FX may respond to the same alert dictionary without changing simulation transactions.
