# M03 - Momentum

Status: Implemented with provisional tuning

Goal: make fast look-ahead play feel meaningfully different from slow stop-and-search play.

## Scope

- decaying momentum meter
- pair clears generate momentum
- multiplier thresholds
- higher tiers create greater maintenance pressure
- timing telemetry
- score display
- placeholder audiovisual feedback
- deterministic Combo chain telemetry
- deterministic tile and pair opportunity telemetry
- configurable hard-pair recognition and score rewards

## Success Criteria

Fast look-ahead play feels meaningfully different from slow stop-and-search play.

## Non-Goals

- Final scoring economy.
- Final audiovisual presentation.
- Modifiers.
- Consumables beyond systems already implemented.
- Async competition.

## Initial Decisions

- Gameplay commands carry monotonic active-play timestamps in integer milliseconds.
- Accepted commands atomically materialize momentum decay since the prior command. The HUD previews the same deterministic decay function between commands without mutating state.
- Pair resolution scores with the current multiplier, then adds momentum toward the multiplier for the next pair.
- Pair transactions record selection interval, pair interval, momentum before/after decay, momentum after gain, scoring multiplier, resulting multiplier, and score gain.
- Score, momentum, timestamps, and peak multiplier are authoritative state included in state hashes and replay deltas.
- The gradual multiplier award order is gameplay rules version `2` because it changes command-to-score results.
- Combo is authoritative state recorded in hashes and replay transactions. Difficulty rewards advance gameplay rules to version `6` because qualified pairs change score results.
- A natural pair starts Combo at `1`; each later natural pair inside the configured active-play window increments the chain and refreshes its deadline.
- Ordinary selectable tiles entering the tray do not break Combo.
- Tapping an active locked tile breaks a live Combo through an explicit state-only transaction. Taps with no live Combo remain presentation feedback and append no transaction.
- Successful Hint, Undo, Delete Pair, and Shuffle transactions break Combo. Rejected or unavailable consumable attempts retain the existing no-mutation contract.
- Combo uses the same active-play clock as Momentum, so pause-menu time is excluded. Presentation previews expiration without mutating state, and the next accepted action materializes the authoritative result.
- Every accepted natural tile selection records a deterministic pre-command opportunity summary. Resolved pairs link back to their original board-pair score and contextual rank when one existed.
- Pair-difficulty analysis is geometry- and state-derived. Qualified board-pair opportunities produce deterministic `notable` or `exceptional` score bonuses and stable callout keys; tray completions remain ineligible. It does not change Momentum, Combo, or legal moves. See [Pair Difficulty Analysis](../PAIR_DIFFICULTY.md).

## Provisional Tuning

- Momentum range: `0..100000` integer units.
- Pair gain: `30000` units.
- Multiplier thresholds: `0`, `20000`, `40000`, `60000`, `80000` for `x1` through `x5`.
- Decay by tier: `5`, `7`, `10`, `14`, `19` units per millisecond.
- Pair score: `100 * current multiplier`; the first pair scores at `x1` and builds momentum toward later tiers.
- Combo window: `7000` milliseconds after each natural pair. The deadline is intentionally more forgiving than Momentum pressure.
- Notable difficulty: score `160`, percentile `7500`, and a 25 percent bonus.
- Exceptional difficulty: score `220`, percentile `9000`, and a 50 percent bonus.

These values are configuration embedded in the game definition. They establish an M3 test baseline, not a final scoring economy.

The default values are authored in `configuration/default_momentum_tuning.tres`. Selecting the root `Main` node exposes that resource in the Godot Inspector. Changes are validated and copied into a new game definition on launch or Restart; the simulation and replay formats remain plain data and do not depend on Godot resources.

## Remaining Questions

- How active-play time should pause around menus, interruptions, and app suspension.
- Final tuning after hands-on playtesting.
- Whether later scoring includes bonuses beyond pair momentum.
- Whether Combo should eventually affect rewards or remain a presentation-intensity signal.
- Final pair-difficulty thresholds, bonus percentages, and callout intensity after human playtesting.
