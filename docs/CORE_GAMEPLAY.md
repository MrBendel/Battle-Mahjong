# Core Gameplay

Battle Mahjong uses a layered mahjong-solitaire-style board with a permissive tray system that creates push-your-luck routing.

## Board Interaction

- The board contains physical tile objects in layered `(x, y, z)` positions.
- Selectability follows mahjong-solitaire-style blocking rules.
- Selectable tiles can be moved into the tray.
- Matching rules use logical tile identities, not cosmetic tile skins.

Status: Open Question

- Exact board layouts.
- Exact selectability edge cases for custom layouts.

## Tray

- The tray initially contains 4 slots.
- When two matching tiles enter the tray, they form a pair and are removed.
- Players may temporarily hold unmatched tiles while searching for their mates.
- If the tray fills with 4 unresolved tiles and the player cannot resolve a pair, the run is lost unless an active effect such as Extra Life prevents failure.

The tray is intentionally more permissive than traditional mahjong solitaire and should support temporary unmatched holdings.

Status: Open Question

- Whether some modes or modifiers adjust base tray capacity.

## Reference Simulation Profile

Status: Decided for the initial headless simulation baseline

Analysis of the reference game established this starting profile:

- 96 physical tiles.
- 48 removable pairs.
- 24 logical tile identities.
- 4 copies of each identity.
- 4 tray slots.
- Matching tray tiles resolve immediately.
- Reaching 4 unresolved tray tiles ends the run.

The reference layout generator uses three layers and a seeded identity assignment. It guarantees at least one pair-aware clear route so simulation failures indicate policy or rules behavior rather than an accidentally impossible deal.

## Momentum

Successful pair clears push up a continuously decaying momentum meter.

Multiplier progression concept:

```text
x1 -> x2 -> x3 -> x4 -> x5 -> ...
```

Higher multiplier tiers should become progressively harder to maintain.

As players solve more rapidly:

- multiplier increases
- momentum becomes more valuable
- decay pressure increases
- visual/audio intensity increases

Stopping to search causes momentum to fall.

Status: Decided for the initial M3 tuning baseline

- Momentum uses integer units from `0` to `100000`.
- An accepted natural tile selection adds `2000` units; Undo removes the actual gain from the compensated selection after normal decay.
- A pair adds `10000` units. Together with two fast selections, a clean pair advances approximately one multiplier tier.
- `x1` is the unlabeled default. Thresholds every `12500` units produce the seven visible upgrades `x2` through `x8`.
- Tier decay rates are `3`, `4`, `5`, `6`, `7`, `8`, `10`, and `12` units per millisecond, making higher tiers progressively harder to maintain while keeping consistent fast pairs net-positive through `x8`.
- A pair scores `100 * current multiplier` before the completing selection's gain, then selection and pair gains build the multiplier for later pairs.

These values are stored in game configuration and remain provisional pending playtesting.

The defaults are editable in Godot by selecting `configuration/default_momentum_tuning.tres` in the FileSystem dock, or by selecting the `GameShell` root and opening its assigned `Momentum Tuning` resource in the Inspector. `Pair Gain`, `Selection Gain`, `Multiplier Thresholds`, and the per-tier `Decay Per Second` array are all exposed. A game snapshots these values when it is created, so restart the run after changing the resource.

## Win And Loss

Expected base outcomes:

- Win: all board and tray tiles are resolved.
- Loss: tray failure occurs and no active effect prevents it.

Status: Open Question

- Whether some modes have additional fail states.
- How score, time, and replay validity interact after loss prevention effects.
