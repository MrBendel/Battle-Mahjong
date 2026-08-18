# M04 - Generator + Solver

Status: Implemented baseline

Goal: generate deterministic games on varied layered layouts while proving that every generated game has at least one legal solution.

## Scope

- first-class board layout data independent from tile identities
- aligned and staggered 96-tile layout templates
- partial higher-layer overlap through half-tile coordinate offsets
- deterministic assignment of matching faces to a legal removal plan
- generated solution certificates
- independent pair-removal solver
- transactional solution replay validation
- layout-aware responsive board presentation and debug information

## Success Criteria

- The same seed and layout produce the same game definition.
- Every generated reference game includes a complete legal solution certificate.
- The independent solver can find and replay a winning route for each M4 layout.
- The Godot shell displays the staggered layout in portrait and landscape without changing simulation geometry.
- Existing imperfect simulation policies remain deterministic.

## Initial Decisions

- A layout owns only an identifier and ordered `(x, y, z)` positions. Tile faces remain deal data, and tile skins remain presentation data.
- A tile still occupies `2x2` integer grid units. Odd coordinates therefore represent half-tile offsets without introducing floating-point simulation geometry.
- Same-layer footprint overlap is invalid. Higher-layer overlap is expected and controls cover blocking.
- M4 uses authored geometry templates. Procedural geometry synthesis is deferred until difficulty requirements justify it.
- Generation derives a legal geometry-removal plan, shuffles the existing pair vocabulary with the seeded RNG, and assigns one matching face to each planned pair.
- The generated certificate is verification/debug output, not authoritative game state and not exposed to the player.
- The independent solver searches legal selectable matching pairs. It currently proves pair-only solutions and does not require temporary unmatched tray holdings.
- The perfect-information `pair_aware` simulator follows a solver result. `bounded_attention` and `random` remain behavioral heuristics rather than solvability proofs.
- Layout identity is included in game configuration and therefore in the definition hash and replay contract.

## Reference Layouts

### `classic_96`

The original aligned three-layer `48 + 32 + 16` geometry. It remains available as a regression baseline.

### `staggered_96`

The same layer counts with upper layers offset by one grid unit on selected axes. This creates visible half-tile cover relationships and is the default playable M4 layout.

## Non-Goals

- Procedurally inventing arbitrary board silhouettes.
- Difficulty scoring or ranking.
- Requiring unmatched tray occupancy in a solution.
- Enumerating all solutions or measuring alternate-route density.
- Changing the current 24-identity, four-copies-per-identity reference composition.
- Modifiers, consumables, production artwork, or M5 work.

## Validation

- Layout validation rejects empty, odd-sized, negative-depth, and same-layer overlapping geometry.
- Tests verify aligned and partial-overlap selectability.
- Generated certificates and independently solved routes replay through normal game transactions to `won`.
- Seeded simulation tests continue to cover perfect-information, bounded-attention, and random policies.
- Responsive UI smoke tests cover portrait and landscape shell regions.

## Remaining Questions

- How gameplay should map the intended 34-face art vocabulary into board composition; M4 preserves the current 24 abstract identities.
- Which difficulty metrics best predict human tray pressure and dead-end risk.
- Whether later generators should synthesize geometry, select from authored templates, or combine both.
- When a full tray-aware solver that permits temporary unmatched selections becomes necessary.
