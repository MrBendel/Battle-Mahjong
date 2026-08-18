# Roadmap

Milestones are ordered to protect the core game loop before adding breadth.

## M0 - Project Skeleton

Goal: establish project structure and architectural boundaries.

Includes:

- choose/record game engine decision
- responsive portrait/landscape canvas
- deterministic seeded RNG foundation
- asset conventions
- debug infrastructure
- simulation/presentation separation

Do not overbuild.

## M1 - Core Mahjong Board

Implement:

- tile data model
- board positions
- layered `(x, y, z)` geometry
- selectability/blocking rules
- matching rules
- pair removal
- one fixed board layout
- placeholder tile graphics

Success criteria:

A player can interact with and clear a traditional layered board using legal tile rules.

## M2 - Four-Slot Tray

Implement the actual Battle Mahjong interaction model:

- select exposed tiles into tray
- tray capacity = 4
- matching tray tiles resolve
- unmatched tiles stay
- overflowing unresolved tray causes failure
- Undo
- win/loss/restart

Success criteria:

We can evaluate whether tray-based risk management is fun.

## M3 - Momentum

Implement:

- decaying momentum meter
- pair clears generate momentum
- multiplier thresholds
- higher tiers create greater maintenance pressure
- timing telemetry
- score display
- placeholder audiovisual feedback

Success criteria:

Fast look-ahead play feels meaningfully different from slow stop-and-search play.

## M4 - Generator + Solver

Implement:

- first-class layout geometry independent from tile faces
- aligned and staggered 96-tile templates
- deterministic solvable deal generation
- generated solution certificates
- independent solution search and transactional replay validation
- responsive presentation of partial tile overlap

Success criteria:

Every generated reference game has a verified legal solution, and the playable shell exercises staggered partial overlap in portrait and landscape.

Detailed contract: [M04 Generator + Solver](milestones/M04_GENERATOR_SOLVER.md)

## Later Milestones

Later milestones are recorded here to preserve ordering. Detailed implementation contracts remain deferred unless linked below.

- M5 Modifiers
- M6 Consumables
- [M7 Art Foundation And First Visual Slice](milestones/M07_ART_FOUNDATION.md) - canonical tile system, first production-ready visual slice, reusable arcade/anime feedback, and Default-to-Neon skin proof. This consolidates the former M7 feedback and foundational M8 art placeholders.
- M8 Art Expansion + Cosmetics - additional skins, characters, backgrounds, and visual breadth built on the M7 contracts
- M9 Replays + Ghosts
- M10 Game Modes
- M11 Backend + Async Battle
- M12 Progression + Collection
