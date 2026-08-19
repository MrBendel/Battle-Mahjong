# Systems

This document records major gameplay-adjacent systems and their current design status.

## Modifiers

Modifiers are collectible RPG-style effects attached to ordinary physical tiles on the board.

The player receives the modifier when a pair involving the modified tile is completed.

Status: Implemented M5 baseline

- A game receives a plain-data pre-run loadout snapshot with a configurable initial limit of three equipped modifiers.
- Reference games give new players one level-0 `2.0x` Score Multiplier modifier.
- Ownership, collection, upgrade persistence, and loadout UI remain later progression work.
- Equipped modifiers attach deterministically to stable physical tile IDs and are included in the game-definition hash.
- M5 permits at most one equipped modifier of each type.

Design principle:

- Modifiers should generally enhance gameplay without unexpectedly disrupting board geography.
- Modifiers should remain associated with physical tile objects unless later design work establishes a better rule.

### Extra Life

If the tray would cause a loss, automatically save the player.

Possible behavior:

- clear or recover the tray
- preserve the run
- potentially reshuffle only when explicitly appropriate

M5 baseline: a collected Extra Life grants level-scaled charges. When the tray would fill, one charge is consumed and all previously unresolved tray tiles return to their board slots; the attempted tile remains on the board.

### Cold Snap

Temporarily freezes momentum decay.

Possible upgrade paths:

- Deep Freeze: longer freeze duration.
- Flash Freeze: short freeze, but matches during the effect generate extra momentum.
- Cold Chain: each match made while frozen extends the freeze slightly.

Modifier leveling should ideally introduce meaningful behavioral changes rather than only numerical increases.

M5 baseline: level 0 freezes active-play momentum decay for 8 seconds, and each level adds 0.5 seconds. Upgrade branches and stacking remain future work.

### Score Multiplier

Applies a time-limited score multiplier after its tile resolves. Level 0 is `2.0x`, each level adds `0.1x`, and the M5 duration is 10 seconds. It does not alter momentum or its tier multiplier.

### Tray +1

Temporarily expands tray capacity by one slot.

M5 baseline: level 0 adds one slot for the next three resolved pairs, with one additional pair per level. The triggering pair does not consume duration.

### Future Modifier Concepts

Future modifiers may include board-clearing or chain-reaction effects, such as a modifier that removes several pairs and recursively triggers similar modifiers encountered in those cleared pairs.

Status: Open Question

- Whether board-clearing effects can preserve competitive fairness and board readability.

## Consumables

Consumables are separate from modifiers. They are deliberate player-controlled actions, analogous to potions/items in an RPG.

### Hint

Reveal or highlight a currently available pair.

Status: Implemented M6 baseline

Hint prioritizes a selectable mate for an unresolved tray tile, then a selectable board pair. It awards no score or momentum. If no pair is available, it reports that state and consumes neither Hint nor Undo. Ranked/replay categorization remains deferred.

### Undo

Return a recently selected unmatched tray tile to the board.

Basic behavior:

- return the most recently selected unmatched tile to its original board position

Potential upgrades:

- choose among recent tiles
- return several tray tiles
- briefly protect momentum

Status: Implemented M6 baseline

Undo returns only the latest unresolved tray tile selected after the most recent resolved pair, appends a compensating transaction, and consumes one Undo on success. Resolving a pair clears prior Undo eligibility; a later unmatched selection starts a fresh Undo window. Undo cannot reverse or cross a resolved pair.

### Delete Pair

Select a tile and automatically remove it together with a valid matching tile.

Status: Implemented M6 baseline

The target and its match must both be visible, but neither needs to satisfy ordinary movement selectability. Side-blocked and partially covered tiles are valid; a tile whose complete footprint is covered by one or more higher tiles is not. The lowest-ID visible match is chosen deterministically. Assisted removal triggers attached modifiers but awards no score or momentum.

### Shuffle

Deliberately reshuffle remaining board tiles.

Shuffle must never leave the player in an unknowingly impossible state.

The shuffle system should:

- preserve occupied board geometry
- account for tiles already in the tray
- preserve modifiers appropriately
- validate solvability
- preferably create useful immediate moves

Status: Implemented M6 baseline

Shuffle supports zero through one-less-than-capacity tray tiles, including an almost-full tray. It preserves tray order and occupied geometry, assigns immediate mates for tray identities, constructs the remaining pairs, and verifies the route through normal transactions before consuming the charge. Ranked Battle policy remains deferred.

## Board Generation

Boards do not rely on naive full randomness. The M4 baseline uses constructive assignment:

1. Start from an empty board layout.
2. Add matching pairs into positions that correspond to legal removal states.
3. Continue until populated.
4. Reverse the construction sequence to obtain a guaranteed solution.

Goal:

> Guarantee at least one valid solution without forcing the player to follow one rigid solution.

The tray allows valid solutions to include temporary unmatched holdings.

Difficulty targets may include:

- tile count
- maximum stack depth
- number of simultaneously available pairs
- required tray pressure
- alternate solution density
- visual ambiguity
- branching factor
- dead-end risk

M4 implements this against both versioned authored assets and seeded requirements-driven geometry. Procedural requirements currently control tile count, layer distribution, dimensions, broad shape family, horizontal symmetry, and immediate support. Every result emits a legal pair-removal certificate and completed definitions are independently verified with a pair-only solver. Generated boards should eventually be analyzed or simulated so difficulty can be measured rather than guessed.

Status: Open Question

- How art-directed masks and measured difficulty targets should extend the initial procedural requirements.
- When solver routes should require temporary unmatched tray holdings.
- How much alternate-route density is enough.

## Difficulty

Difficulty should not be represented only by more tiles.

Important levers:

- total tile count
- layout shape
- stack height/depth
- number of exposed/selectable tiles
- number of immediately available pairs
- visual similarity between exposed tile faces
- solution branching
- required tray occupancy
- fragile dependency chains
- momentum decay tuning
- consumable availability

Conceptual profile:

```text
EASY
- lower tile count
- shallow stacks
- many available pairs
- tray pressure 0-1
- many alternate routes
- low dead-end risk
```

Conceptual profile:

```text
EXPERT
- high tile count
- deep stacks
- fewer obvious pairs
- tray pressure up to 3
- fewer alternate routes
- higher visual ambiguity
- stronger dependency chains
```

These values are illustrative, not finalized constants.
