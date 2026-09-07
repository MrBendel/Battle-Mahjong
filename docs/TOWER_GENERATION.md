# Tower Generation And Difficulty Tooling

The Tower is the endless-play direction. The first playable runtime loop and the heavier authoring tools share deterministic layout/deal contracts but serve different jobs.

## Runtime Loop

Selecting **The Tower** in town creates a run seed and starts floor 1 immediately after the existing modifier-loadout step. Each floor is an ordinary, independently replayable `GameDefinition`; the Tower run owns only the run seed and current floor number. Clearing a floor offers **Next Floor**, while losing can replay that same floor. Returning to town ends the in-memory run.

`configuration/tower/tower_runtime.json` controls the initial runtime curve. A floor deterministically derives separate layout and deal seeds from `(run seed, floor number)`. The current curve keeps the portrait-first 96-tile board envelope stable while increasing:

- unique tile identities, from 12 toward 24;
- deterministic deal shuffle, from 40% toward 100%.

The floor sequence is unbounded and reproducible. Persistence, rewards, checkpoints, and profile progression remain deferred; this is the playable mode foundation rather than the finished Tower metagame.

## Segment Contract

A Tower generation profile records:

- a stable profile ID and revision,
- one procedural layout requirements asset,
- the number of candidate games to sample,
- the number of difficulty-ranked floors to select,
- the tray capacity used by those games.
- versioned weights for the provisional combined difficulty score.
- the number of unique tile identities and deterministic deal-shuffle amount.

The foundation profile lives at `configuration/tower/tower_foundation.json` and uses the `6x7` portrait motif profile in `configuration/layout_requirements/portrait_arcade_96.json`. Its layers use alternating full and half-tile-inset candidate footprints rather than progressively narrowing at every level. A segment seed deterministically derives independent layout and deal seeds for every candidate. Each candidate contains its complete generated layout, chosen layer motifs, mobile-fit metrics, deal identity, certified solution, and difficulty report.

The primary authored difficulty axes are kept separate from the measured score:

- Board width, height, tile count, and layer distribution come from the referenced layout requirements.
- `unique_tile_count` controls how broad the matching vocabulary is.
- `shuffle_basis_points` controls how much of the pair vocabulary is shuffled away from solution order. `0` is ordered and `10000` performs the full deterministic shuffle.
- `randomize_removal_pairs` chooses pairs from the selectable frontier with seeded randomness. This prevents symmetric geometry from forcing matching faces into neighboring or mirrored slots while retaining a certified removal route.

All axes are copied into the generated manifest. A later Tower curve can move between multiple profiles or requirements assets without changing the generator contract.

Selected authoring floors receive stable IDs such as `tower_foundation_floor_001`. They are sampled from evenly distributed difficulty buckets rather than taking only the easiest or hardest candidates. This candidate-ranking path remains useful for tuning and curated segments; it is deliberately not run synchronously when entering Tower on a phone.

## Difficulty Report

`LayoutDifficultyAnalyzer` replays the generated solution through ordinary game transactions. Before each pair it records the existing orientation-independent pair-opportunity analysis and route flexibility.

The foundation profile's provisional integer score is:

```text
average certified-pair difficulty
+ peak certified-pair difficulty / 4
+ constrained route steps (two or fewer available pairs) * 3
+ max(0, 6 - average available pairs) * 5
```

The weights and low-availability target are editable in the profile. The report also preserves initial, minimum, and average selectable-tile and available-pair counts. These raw metrics are the durable useful output; the combined score is an authoring heuristic that should be revised after playtest correlation.

The analyzer intentionally disables flipped tiles and modifiers for the baseline ranking. Those systems can become explicit Tower difficulty axes later instead of silently distorting geometry/deal measurement.

## Generate A Segment

From the repository root:

```powershell
godot --headless --path . --script res://scripts/tools/generate_tower_segment.gd -- `
  res://configuration/tower/tower_foundation.json 4242 tower-foundation-4242.json
```

Omit the output path to print the manifest. Generation fails rather than emitting a segment when a candidate layout, deal, or certified transaction route is invalid.

Quick Play exposes the motif generator before modifier selection. This on-device path previews an in-memory layout and records the chosen seed in the resulting game definition; it does not write generated assets into the packaged project. Tower uses the same generator without showing the seed picker.

## Current Limits

- Tower runs are session-only and do not yet implement saves, rewards, profiles, checkpoints, or a run summary.
- One requirements profile produces a deliberately narrow difficulty range.
- Runtime board dimensions and layer counts are currently fixed; later profile tiers can change those axes without changing the run contract.
- The score measures a certified pair-only route, not tray-aware human play or dead-end probability.
- Segment generation is an offline authoring operation and is not optimized for a frame-time budget.
- Difficulty weights are provisional and must not become player-facing labels until validated against playtest outcomes.
