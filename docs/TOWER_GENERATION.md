# Tower Generation And Difficulty Tooling

The Tower is the intended endless-play direction. The current implementation is authoring tooling, not a shipped game mode: it creates deterministic, finite Tower segments that can be inspected, playtested, and chained later.

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

Selected floors receive stable IDs such as `tower_foundation_floor_001`. They are sampled from evenly distributed difficulty buckets rather than taking only the easiest or hardest candidates. Segments can later be chained by a durable game-mode system without changing board layout identity or replay data.

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

The gameplay shell also exposes the motif generator before modifier selection in internal builds. This on-device path previews an in-memory layout and records the chosen seed in the resulting game definition; it does not write generated assets into the packaged project.

## Current Limits

- This does not implement Tower navigation, saves, rewards, profiles, or an endless runtime loop.
- One requirements profile produces a deliberately narrow difficulty range.
- The score measures a certified pair-only route, not tray-aware human play or dead-end probability.
- Segment generation is an offline authoring operation and is not optimized for a frame-time budget.
- Difficulty weights are provisional and must not become player-facing labels until validated against playtest outcomes.
