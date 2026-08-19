# Pair Difficulty Analysis

Status: Implemented as provisional telemetry; no rewards are attached.

## Purpose

Battle Mahjong evaluates the visual-search opportunity before every accepted natural tile selection. The analysis is deterministic simulation data derived from the current board revision. It never reads viewport coordinates, orientation, tile artwork, animation, or wall-clock time.

The first implementation exists to collect comparable playtest and simulation data before difficulty tiers or rewards are designed.

## Tile Score

Every selectable tile receives an integer difficulty score from:

- base value: `10`;
- selectable search space: `2` per selectable tile;
- local crowding: `4` per active tile within four authored grid units on both axes;
- lower-layer depth: `8` per layer below the highest active layer;
- interior depth: `2` per authored grid unit from the nearest active-board edge; and
- alternate-mate relief: `-8` for each selectable matching mate beyond the first.

Scores are clamped to zero. These weights are provisional diagnostics, not final game balance.

## Pair Score

Every matching pair among the selectable tiles receives an integer score from:

- the average difficulty of its two tiles;
- spatial separation: `2` per authored Manhattan grid unit;
- layer separation: `8` per layer;
- board-region span: `8` for crossing each active-board midpoint axis; and
- alternate-mate relief: `-6` for each selectable tile of the same identity beyond the pair.

Pairs and tiles are ranked hardest-first. Equal scores use stable physical tile IDs as the tie-breaker. Percentiles use integer basis points from `0` to `10000`, making analysis stable across platforms and JSON-safe after integer normalization.

## Transaction Telemetry

Each accepted natural selection records:

- the pre-command board revision;
- active, selectable, and available-pair counts;
- the selected tile score, components, rank, and percentile; and
- matching board-pair options involving that selected tile.

When a natural pair resolves, telemetry links it to the pair opportunity observed before its first tile was selected. If the mate was not a selectable board pair at that time, the event is labeled `tray_completion` and records the currently selected tile observation without inventing a contextual pair rank.

The analysis is derived telemetry. It does not drive reduction, state hashes, legal moves, score, Momentum, Combo, or rewards.

## Validation And Tuning

The CLI simulation runner reports analyzed pair count, average selected-pair difficulty, and hardest selected-pair difficulty by policy. Tests verify deterministic ranking, axis-transposition invariance, transaction serialization, and unchanged scoring.

Before rewards are attached, playtest data should answer:

- whether high-ranked pairs are consistently perceived as harder by players;
- which components correlate poorly with human judgment;
- whether rankings remain useful at early, middle, and late board states; and
- whether tray completions need a separate difficulty model.
