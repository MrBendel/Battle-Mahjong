# Pair Difficulty Analysis

Status: Implemented with provisional deterministic recognition tiers and score rewards.

## Purpose

Battle Mahjong evaluates the visual-search opportunity before every accepted natural tile selection. The analysis is deterministic simulation data derived from the current board revision. It never reads viewport coordinates, orientation, tile artwork, animation, or wall-clock time.

The analysis remains provisional and produces comparable playtest and simulation data. Qualified board-pair opportunities now also drive a deliberately small first reward slice so perceived difficulty and reward frequency can be tested together.

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

Selections also record when moving one accessible blocker makes a tile matching a held tray tile newly selectable. If that exact mate is selected immediately afterward, the pair transaction receives deterministic `hidden_pair_recognition` telemetry. A mate that was fully covered earns the `eagle_eyes` key; a mate that was visible but blocked earns `great`. Any intervening command expires the setup. This recognition is presentation-only and does not turn tray completions into board-difficulty score rewards.

The analysis remains derived data and does not affect legal moves, Momentum, Combo, or tile state. The recorded opportunity may drive score through the rules below; the resulting score mutation remains an ordinary transaction change and therefore participates in state hashes and replay.

## Recognition And Score Rewards

Only opportunities recorded with `source: board_pair` are eligible. Tray completions and consumable removals never receive board-difficulty rewards. A pair must satisfy both the absolute score and contextual percentile threshold, preventing the last remaining pair from qualifying merely because it ranks first in a tiny search space.

Default tiers:

- `notable`: score at least `130` and percentile at least `6000`; emits `great` and adds 25 percent;
- `exceptional`: score at least `190` and percentile at least `8500`; emits `eagle_eyes` and adds 50 percent.

The exceptional tier is evaluated first. These deliberately lively playtest thresholds target recognition more often than the original `160/7500` and `220/9000` gates. Thresholds and bonus basis points are exposed through the `MomentumTuning` Inspector resource and copied into the immutable game definition.

The score before difficulty is the normal pair award after Momentum and active score-modifier multiplication. Difficulty adds:

`floor(score_before_difficulty * bonus_basis_points / 10000)`

Transaction telemetry records the tier, stable callout key, observed difficulty, contextual percentile, bonus basis points, and awarded bonus score. Presentation consumes the callout key from the committed transaction and never re-evaluates difficulty.

## Validation And Tuning

The CLI simulation runner reports analyzed pair count, average selected-pair difficulty, and hardest selected-pair difficulty by policy. Tests verify deterministic ranking, axis-transposition invariance, transaction serialization, and unchanged scoring.

Playtest and simulation data should answer:

- whether high-ranked pairs are consistently perceived as harder by players;
- which components correlate poorly with human judgment;
- whether rankings remain useful at early, middle, and late board states; and
- whether tray completions need a separate difficulty model;
- whether the default tiers trigger often enough to feel special without becoming noisy; and
- whether 25 and 50 percent bonuses remain proportional at high Momentum multipliers.
