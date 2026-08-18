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
- Pair resolution adds momentum before its score multiplier is evaluated.
- Pair transactions record selection interval, pair interval, momentum before/after decay, momentum after gain, multiplier, and score gain.
- Score, momentum, timestamps, and peak multiplier are authoritative state included in state hashes and replay deltas.

## Provisional Tuning

- Momentum range: `0..100000` integer units.
- Pair gain: `30000` units.
- Multiplier thresholds: `0`, `20000`, `40000`, `60000`, `80000` for `x1` through `x5`.
- Decay by tier: `5`, `7`, `10`, `14`, `19` units per millisecond.
- Pair score: `100 * post-gain multiplier`.

These values are configuration embedded in the game definition. They establish an M3 test baseline, not a final scoring economy.

## Remaining Questions

- How active-play time should pause around menus, interruptions, and app suspension.
- Final tuning after hands-on playtesting.
- Whether later scoring includes bonuses beyond pair momentum.
