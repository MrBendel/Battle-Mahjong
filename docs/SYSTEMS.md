# Systems

This document records major gameplay-adjacent systems and their current design status.

## Modifiers

Modifiers are collectible RPG-style effects attached to ordinary physical tiles on the board.

The player receives the modifier when a pair involving the modified tile is completed.

Design principle:

- Modifiers should generally enhance gameplay without unexpectedly disrupting board geography.
- Modifiers should remain associated with physical tile objects unless later design work establishes a better rule.

### Extra Life

If the tray would cause a loss, automatically save the player.

Possible behavior:

- clear or recover the tray
- preserve the run
- potentially reshuffle only when explicitly appropriate

Status: Open Question

- Exact recovery behavior.
- Whether Extra Life consumes itself before or after failure is evaluated.

### Cold Snap

Temporarily freezes momentum decay.

Possible upgrade paths:

- Deep Freeze: longer freeze duration.
- Flash Freeze: short freeze, but matches during the effect generate extra momentum.
- Cold Chain: each match made while frozen extends the freeze slightly.

Modifier leveling should ideally introduce meaningful behavioral changes rather than only numerical increases.

Status: Open Question

- Exact freeze duration.
- Exact upgrade behavior and stacking rules.

### Multiplier Boost

Adds to or accelerates the current multiplier/momentum.

Status: Open Question

- Whether it modifies momentum, multiplier, or both.

### Tray +1

Temporarily expands tray capacity by one slot.

Status: Open Question

- Duration.
- Behavior when the effect expires while the tray has more tiles than base capacity.

### Future Modifier Concepts

Future modifiers may include board-clearing or chain-reaction effects, such as a modifier that removes several pairs and recursively triggers similar modifiers encountered in those cleared pairs.

Status: Open Question

- Whether board-clearing effects can preserve competitive fairness and board readability.

## Consumables

Consumables are separate from modifiers. They are deliberate player-controlled actions, analogous to potions/items in an RPG.

### Hint

Reveal or highlight a currently available pair.

Status: Open Question

- Whether Hint affects score, momentum, ranking, or replay category.

### Undo

Return a recently selected unmatched tray tile to the board.

Basic behavior:

- return the most recently selected unmatched tile to its original board position

Potential upgrades:

- choose among recent tiles
- return several tray tiles
- briefly protect momentum

Status: Open Question

- Exact undo history depth.
- Whether Undo can affect tiles involved in already resolved pairs.

### Delete Pair

Select a tile and automatically remove it together with a valid matching tile.

Status: Open Question

- How the matching tile is selected.
- Whether Delete Pair can target blocked tiles.

### Shuffle

Deliberately reshuffle remaining board tiles.

Shuffle must never leave the player in an unknowingly impossible state.

The shuffle system should:

- preserve occupied board geometry
- account for tiles already in the tray
- preserve modifiers appropriately
- validate solvability
- preferably create useful immediate moves

Status: Open Question

- Exact solvability validation method.
- Whether shuffle is allowed in ranked Battle.

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
