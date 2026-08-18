# M05 - Modifiers

Status: Implemented deterministic baseline

Goal: add collectible, levelable tile modifiers through a bounded pre-run loadout without coupling gameplay simulation to future account or progression systems.

## Scope

- a maximum three-slot modifier loadout, configurable per game definition;
- a starter level-0 `2.0x` Score Multiplier modifier;
- deterministic attachment of equipped modifiers to ordinary physical board tiles;
- pair-triggered Extra Life, Cold Snap, Score Multiplier, and Tray +1 effects;
- level-scaled, Inspector-authored modifier tuning;
- reversible modifier state changes, definition hashing, serialization, replay validation, and trigger telemetry;
- placeholder modifier labels on board tiles.

## Loadout Contract

A loadout entry is a plain-data snapshot:

```text
modifier_id
type
level
```

The snapshot is supplied when a game definition is created. M5 does not own inventory persistence, collection rewards, upgrade costs, accounts, or loadout-selection UI. Those later systems must produce this same snapshot rather than becoming dependencies of simulation.

The initial loadout capacity is three. M5 permits at most one equipped modifier of each type. New reference games use one starter Score Multiplier at level 0; callers may provide another valid loadout, including an empty one.

Modifier placement uses a deterministic RNG stream derived from the game seed. Attachments remain associated with stable physical tile IDs, are embedded in the immutable game definition, and participate in its hash. Loadout order is significant and is preserved in the definition.

## Trigger Order

- A modifier activates when a pair containing its physical tile resolves.
- If both resolved tiles contain modifiers, triggers are processed in stable tile-ID order.
- The resolving pair scores before newly collected effects activate. The new effect therefore benefits subsequent play.
- Transactions record `modifiers_triggered` telemetry with tile ID, modifier identity, type, level, and effective values.

## Initial Effects And Tuning

All values below are provisional and authored in `configuration/default_modifier_tuning.tres`.

### Extra Life

- Level 0 grants one recovery charge; each level adds one charge.
- When an unmatched selection would fill the effective tray capacity, one charge is consumed automatically.
- Existing unresolved tray tiles return to their stable board slots, the attempted tile remains on the board, and the run stays active.
- Recovery is one atomic transaction with `extra_life_consumed` telemetry.

### Cold Snap

- Level 0 freezes momentum decay for 8,000 ms of active gameplay time.
- Each level adds 500 ms.
- Commands still advance the authoritative active-play clock while frozen. An interval crossing the expiry decays only for time after expiry.

### Score Multiplier

- Level 0 applies `2.0x`; each level adds `0.1x`.
- The effect lasts 10,000 ms of active gameplay time.
- Strength uses integer basis points where `1000 = 1.0x`, `2000 = 2.0x`, and `2100 = 2.1x`.
- A boosted pair scores `pair_base_score * momentum_multiplier * modifier_basis_points / 1000` with deterministic integer arithmetic.

### Tray +1

- Adds one temporary tray slot.
- Level 0 lasts for the next three resolved pairs; each level adds one pair.
- The triggering pair does not consume duration.
- The dynamic capacity is part of state validation and loss evaluation.

## Determinism And Replay

- Gameplay rules version is `3` and game-definition schema version is `2`.
- Loadouts, attachments, tuning, and active effects participate in definition or state hashes as appropriate.
- Effect mutations use typed counter changes and replay through the production reducer.
- Time-based effects use command `playback_time_ms`; simulation never reads wall-clock time.
- Modifier placement does not consume runtime gameplay RNG state.

## Non-Goals

- persistent ownership, rewards, collection, or leveling workflows;
- accounts, backend storage, or monetization;
- loadout-selection screens;
- duplicate equipped modifier types or modifier stacking rules;
- upgrade branches such as Deep Freeze, Flash Freeze, or Cold Chain;
- chain-reaction board clearing;
- production modifier artwork or final audiovisual feedback;
- consumables, which remain M6 scope.

## Validation

- loadout capacity, unique identity/type, valid type, and non-negative level checks;
- same-seed attachment determinism and definition JSON/hash round trips;
- fixed-point Score Multiplier level and scoring checks;
- committed Cold Snap decay behavior;
- dynamic Tray +1 capacity and pair duration;
- atomic Extra Life recovery and charge consumption;
- existing reducer replay/reverse, solver, simulation, and responsive UI suites.

## Remaining Questions

- How players earn duplicate modifier tiles and convert them into levels.
- Whether later progression introduces nonlinear or branching upgrades.
- Whether competitive modes normalize or restrict permanent modifier levels.
- Whether future modes allow duplicate equipped modifier types and, if so, how they stack.
