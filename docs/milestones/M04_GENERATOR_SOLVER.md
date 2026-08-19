# M04 - Generator + Solver

Status: Implemented authoring and procedural baseline

Goal: generate deterministic games on varied layered layouts while proving that every generated game has at least one legal solution.

## Scope

- first-class board layout data independent from tile identities
- aligned, staggered, and portrait-stack 96-tile layout templates
- partial higher-layer overlap through half-tile coordinate offsets
- deterministic assignment of matching faces to a legal removal plan
- generated solution certificates
- independent pair-removal solver
- transactional solution replay validation
- layout-aware responsive board presentation and debug information
- versioned JSON authoring with stable coordinate-derived slot IDs
- deterministic requirements-driven generation for rectangular, elliptical, and diamond silhouettes
- automatic authored-layout discovery and a command-line generation tool

## Success Criteria

- The same seed and layout produce the same game definition.
- Every generated reference game includes a complete legal solution certificate.
- The independent solver can find and replay a winning route for each M4 layout.
- The Godot shell displays the portrait-stack layout in portrait and landscape without changing simulation geometry.
- Existing imperfect simulation policies remain deterministic.

## Initial Decisions

- A layout owns an ID, revision, metadata, and canonical stable slots. Tile faces remain deal data, and tile skins remain presentation data.
- A tile still occupies `2x2` integer grid units. Odd coordinates therefore represent half-tile offsets without introducing floating-point simulation geometry.
- Same-layer footprint overlap is invalid. Higher-layer overlap is expected and controls cover blocking.
- Authored layouts use compact versioned JSON assets. Source ordering does not affect canonical slot identity or geometry hashes.
- Procedural requirements specify tile count, base dimensions, layer distribution, shape family, horizontal symmetry, and immediate support.
- Procedural generation is seeded and deterministic. It builds symmetric slot groups directly and rejects output without a complete removal plan.
- Generation derives a legal geometry-removal plan, shuffles the existing pair vocabulary with the seeded RNG, and assigns one matching face to each planned pair.
- The generated certificate is verification/debug output, not authoritative game state and not exposed to the player.
- The independent solver searches legal selectable matching pairs. It currently proves pair-only solutions and does not require temporary unmatched tray holdings.
- The perfect-information `pair_aware` simulator follows a solver result. `bounded_attention` and `random` remain behavioral heuristics rather than solvability proofs.
- Layout ID, revision, and geometry hash are included in game configuration and therefore in the definition hash and replay contract.
- Gameplay layouts are authored portrait-first. Responsive presentation may uniformly scale the board, but landscape does not rotate, transpose, stretch, or rearrange its slots.

Authoring and generation workflow: [Board Layout Authoring](../LAYOUT_AUTHORING.md)

## Reference Layouts

### `classic_96`

The original aligned three-layer `48 + 32 + 16` geometry. It remains available as a regression baseline.

### `staggered_96`

The same layer counts with upper layers offset by one grid unit on selected axes. This creates visible half-tile cover relationships.

### `portrait_stack_96`

A tall, irregular layout transcribed from a hand-authored half-tile grid based on a commercial mobile mahjong board. Its four layers contain `42 / 31 / 17 / 6` tiles. The sixth top-layer tile balances the 95 positions visible in the reference map so the layout supports 48 matching pairs. It is the default playable M4 layout.

## Non-Goals

- Arbitrary image-mask or natural-language layout synthesis.
- Difficulty scoring or ranking.
- Requiring unmatched tray occupancy in a solution.
- Enumerating all solutions or measuring alternate-route density.
- Changing the current 24-identity, four-copies-per-identity reference composition.
- Modifiers, consumables, production artwork, or M5 work.

## Validation

- Layout validation rejects empty, odd-sized, negative-depth, and same-layer overlapping geometry.
- Authoring tests cover compact JSON loading, expanded round-trips, stable IDs, source-order independence, and automatic catalog discovery.
- Procedural tests cover deterministic seeds, seed variation, required layer counts, symmetry, support, three shape families, solution certificates, and independent solving.
- Tests verify aligned and partial-overlap selectability.
- Generated certificates and independently solved routes replay through normal game transactions to `won`.
- Seeded simulation tests continue to cover perfect-information, bounded-attention, and random policies.
- Responsive UI smoke tests cover portrait and landscape shell regions.

## Remaining Questions

- How gameplay should map the intended 34-face art vocabulary into board composition; M4 preserves the current 24 abstract identities.
- Which difficulty metrics best predict human tray pressure and dead-end risk.
- How procedural requirements should evolve from broad shape families toward art-directed masks and measured difficulty targets.
- When a full tray-aware solver that permits temporary unmatched selections becomes necessary.
