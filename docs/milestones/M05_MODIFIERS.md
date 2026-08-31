# M05 - Modifiers

Status: Implemented deterministic baseline

Goal: add collectible, levelable tile modifiers through a bounded pre-run loadout without coupling gameplay simulation to future account or progression systems.

## Scope

- a maximum three-slot modifier loadout, configurable per game definition;
- a starter level-0 `2.0x` Score Multiplier modifier;
- deterministic attachment of equipped modifiers to ordinary physical board tiles;
- pair-triggered Extra Life, Cold Snap, Score Multiplier, Tray +1, Three Pair Clear, and Bomb effects;
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

The snapshot is supplied when a game definition is created. The playable prototype now includes a presentation-only pregame picker over the staged gameplay chrome. Board tiles remain hidden while the player chooses; Start rebuilds the run from the selected snapshot and deals the tiles into the empty Board field. It is debug authoring support rather than persistent inventory: every implemented type is available, selection has no progression-driven cap, and selected modifiers are placed on early solver-route pairs so their effects are practical to test.

Restart returns to this same picker with the previous run's choices preselected. The staged HUD and Board field reset immediately, but tiles remain hidden until the next Start command.

M5 does not own inventory persistence, collection rewards, upgrade costs, or accounts. Those later systems must produce the same snapshot rather than becoming dependencies of simulation.

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

### Three Pair Clear

- The tile overlay is a circle containing a prominent `3`.
- After the modifier's own pair resolves, simulation takes one fixed snapshot of visible, ordinarily selectable natural pairs and chooses up to its level-scaled maximum from that snapshot.
- Rules version 16 and later prioritize currently selectable pairs top-down. Ranking compares each pair's lower tile first and then its higher tile, preventing one high tile from pulling a much deeper mate ahead of a pair whose two tiles are both near the top. Stable tile IDs break remaining ties. Earlier rules versions retain lexical ordering for replay compatibility.
- Pairs blocked at activation are ineligible. An assisted removal may expose them for subsequent normal play, but it cannot add them to the active Three Pair Clear route.
- The effect plans up to five eligible pairs at level 4. If no pair is available in the activation snapshot, it does nothing.
- Rules version 18 and later record the ordered route in the triggering transaction without removing its tiles. The gameplay shell locks player input, then submits each tile in the route through the ordinary selection command on a timer: select the first tile, select its mate, wait for the normal match, then continue. Each automated selection is therefore its own replayable transaction.
- Automated selections use normal queue occupancy, Score, Momentum, Combo, pair-difficulty, haptic, callout, and match behavior. Candidate routes exclude identities carrying unresolved modifiers, preventing recursive modifier activation.
- Rules version 17 and earlier preserve atomic assisted removal for replay compatibility.
- Candidate routes skip identities already represented in the tray so the reward cannot strand a held tile by clearing its board mates.
- Match uses an Inspector-configurable `1, 2, 3, 4, 5` debug progression: level 0 clears one pair and each level adds one. The all-modifier playtest equips level 2 for the familiar Match 3 behavior.
- Three Pair Clear owns no specialized tile animation. Its presentation waits for the triggering pair's complete collision and disappearance, then comes entirely from the existing board-to-queue selection and pair-match paths. The Inspector exposes a `150 ms` anticipation hold after that trigger removal, a short `50 ms` default delay between the two tiles, and a `550 ms` default delay before the next pair.

### Bomb

- The tile overlay uses a compact cartoon bomb and lit-fuse silhouette.
- Bomb level 0 targets one pair. Each level adds one pair through level 5, which targets at most six pairs.
- The current debug picker and all-modifier playtest equip Bomb at level 4 so activation visibly exercises five pairs; this does not change the underlying `1..6` progression curve.
- The base, per-level gain, and maximum are snapshotted tuning values exposed through `ModifierTuning`; the default curve is `1, 2, 3, 4, 5, 6`.
- After the modifier's own pair resolves, simulation chooses up to its effective pair count from currently selectable natural pairs using the seeded gameplay RNG.
- Selectability is recalculated after every projected removal, so one randomly chosen pair may expose a later candidate.
- The ordered random route and resulting RNG state are committed in the same reversible transaction. Replay never rerolls the targets.
- Bomb-assisted pairs award no Score, Momentum, Combo, or difficulty reward and do not recursively activate modifiers.
- Automated clear routes preserve any face identity carrying an unresolved modifier and skip identities already represented in the tray.
- Presentation waits for the triggering pair's complete collision and disappearance, then holds an additional `300 ms`. It eases each pair out into responsive columns on either side of Board center, eases both columns inward into one held vertical stack, then removes its rows through the existing poof chain. Formation, hold, collapse, and chain timing remain presentation-only and Inspector-tunable.
- Bomb formation leaves enough time to read the selected targets before the collision sequence begins; the final poof chain advances at a fast, Inspector-tunable `50 ms` interval per pair.
- Bomb ignition begins only after the triggering pair has fully disappeared, keeping the reward visually connected to the tile that activated it.
- If fewer pairs can be selected, Bomb clears the available partial route and reports the actual count.

The pregame debug picker exposes Bomb 1 through Bomb 6 and Match 1 through Match 5 as separate square tile choices. Choosing another iteration replaces the previous choice from that family; a run cannot equip multiple Bomb or Match levels simultaneously.

## Determinism And Replay

- Current gameplay rules version is `18` and game-definition schema version is `4`.
- Loadouts, attachments, tuning, and active effects participate in definition or state hashes as appropriate.
- Effect mutations use typed counter changes and replay through the production reducer.
- Time-based effects use command `playback_time_ms`; simulation never reads wall-clock time.
- Modifier placement does not consume runtime gameplay RNG state.

## Non-Goals

- persistent ownership, rewards, collection, or leveling workflows;
- accounts, backend storage, or monetization;
- progression-backed loadout limits or inventory ownership;
- duplicate equipped modifier types or modifier stacking rules;
- upgrade branches such as Deep Freeze, Flash Freeze, or Cold Chain;
- recursive modifier chains from assisted pair clearing;
- production modifier artwork or final audiovisual feedback;
- consumables, which remain M6 scope.

## Validation

- loadout capacity, unique identity/type, valid type, and non-negative level checks;
- same-seed attachment determinism and definition JSON/hash round trips;
- fixed-point Score Multiplier level and scoring checks;
- committed Cold Snap decay behavior;
- dynamic Tray +1 capacity and pair duration;
- atomic Extra Life recovery and charge consumption;
- seeded Bomb target selection, RNG reversal, and responsive chained presentation;
- existing reducer replay/reverse, solver, simulation, and responsive UI suites.

## Remaining Questions

- How players earn duplicate modifier tiles and convert them into levels.
- Whether later progression introduces nonlinear or branching upgrades.
- Whether competitive modes normalize or restrict permanent modifier levels.
- Whether future modes allow duplicate equipped modifier types and, if so, how they stack.
