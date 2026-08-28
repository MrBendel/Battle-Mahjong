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
- Every accepted natural tile selection adds a small configurable Momentum reward after deterministic decay. Rejected selections and consumables add none.
- Pair resolution scores with the multiplier after decay but before the completing selection's gain, then adds selection and pair Momentum toward later pairs.
- Pair transactions record selection interval, pair interval, momentum before/after decay, momentum after selection and pair gain, scoring multiplier, resulting multiplier, and score gain.
- Score, momentum, timestamps, and peak multiplier are authoritative state included in state hashes and replay deltas.
- The gradual multiplier award order is gameplay rules version `2` because it changes command-to-score results.
- Combo is authoritative state recorded in hashes and replay transactions. Mistake-driven Combo advances gameplay rules to version `8`; rules version `7` and earlier retain their recorded timeout behavior for replay compatibility.
- A natural pair starts Combo at `1`; each later natural pair increments the chain regardless of elapsed time.
- Ordinary selectable tiles entering the tray do not break Combo.
- Tapping an active locked tile breaks a live Combo through an explicit state-only transaction. Taps with no live Combo remain presentation feedback and append no transaction.
- Successful Hint, Undo, Delete Pair, and Shuffle transactions break Combo. Rejected or unavailable consumable attempts retain the existing no-mutation contract.
- Combo has no time requirement in current rules. Momentum alone owns speed pressure.
- Every accepted natural tile selection records a deterministic pre-command opportunity summary. Resolved pairs link back to their original board-pair score and contextual rank when one existed.
- Pair-difficulty analysis is geometry- and state-derived. Qualified board-pair opportunities produce deterministic `notable` or `exceptional` score bonuses and stable callout keys; tray completions remain ineligible. It does not change Momentum, Combo, or legal moves. See [Pair Difficulty Analysis](../PAIR_DIFFICULTY.md).

## Provisional Tuning

- Momentum range: `0..100000` integer units.
- Selection gain: `2500` units.
- Pair gain: `30000` units.
- Multiplier thresholds: `0`, `20000`, `40000`, `60000`, `80000` for `x1` through `x5`.
- Decay by tier: `5`, `7`, `10`, `14`, `19` units per millisecond.
- Pair score: `100 * current multiplier`; the first pair scores at `x1` and builds momentum toward later tiers.
- Notable difficulty: score `130`, percentile `6000`, and a 25 percent bonus.
- Exceptional difficulty: score `190`, percentile `8500`, and a 50 percent bonus.

These values are configuration embedded in the game definition. They establish an M3 test baseline, not a final scoring economy.

The default values are authored in `configuration/default_momentum_tuning.tres`. Selecting the root `Main` node exposes that resource in the Godot Inspector. Changes are validated and copied into a new game definition on launch or Restart; the simulation and replay formats remain plain data and do not depend on Godot resources.

## Remaining Questions

- How active-play time should pause around menus, interruptions, and app suspension.
- Final tuning after hands-on playtesting.
- Whether later scoring includes bonuses beyond pair momentum.
- Whether Combo should eventually affect rewards or remain a presentation-intensity signal.
- Final pair-difficulty thresholds, bonus percentages, and callout intensity after human playtesting.
