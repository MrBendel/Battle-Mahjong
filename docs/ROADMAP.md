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
- deterministic Combo chains broken by mistakes rather than time
- transactional Combo breaks for locked-tile taps and successful consumable use

Success criteria:

Fast look-ahead play feels meaningfully different from slow stop-and-search play.

The implemented Combo extension distinguishes clean play from raw speed: natural pairs extend the chain, ordinary unmatched tray selections and elapsed time preserve it, and locked-tile mistakes or successful consumables break it. Combo does not directly multiply score; its first purpose is performance recognition and future presentation intensity.

Deterministic tile and pair opportunity analysis scores and ranks the selectable search space before every natural selection. Qualified hard board pairs receive configurable score bonuses and live-text performance callouts; tray completions remain ineligible. Detailed contract: [Pair Difficulty Analysis](PAIR_DIFFICULTY.md).

## M4 - Generator + Solver

Implement:

- first-class layout geometry independent from tile faces
- aligned, staggered, and portrait-stack 96-tile templates
- deterministic solvable deal generation
- generated solution certificates
- independent solution search and transactional replay validation
- responsive presentation of partial tile overlap
- versioned data-authored layouts with stable slots
- seeded requirements-driven layout generation

Success criteria:

Every generated reference game has a verified legal solution, and the playable shell exercises an irregular portrait-stack layout with partial overlap in both orientations. Board geometry is authored portrait-first and remains unchanged in landscape while the surrounding shell reflows.

Detailed contract: [M04 Generator + Solver](milestones/M04_GENERATOR_SOLVER.md)

## M5 - Modifiers

Implement:

- bounded pre-run modifier loadouts
- deterministic attachment to physical tiles
- level-scaled Extra Life, Cold Snap, Score Multiplier, and Tray +1 effects
- transactional effect state and replay telemetry
- placeholder board presentation

Success criteria:

An equipped modifier loadout is reproduced from the game definition, activates deterministically through ordinary pair clears, and replays through the authoritative transaction reducer.

Detailed contract: [M05 Modifiers](milestones/M05_MODIFIERS.md)

## M6 - Consumables

Implement:

- definition-bound per-run quantities for Hint, Undo, Delete Pair, and Shuffle
- atomic successful-use consumption and no-consumption rejection
- tray-prioritized deterministic Hint suggestions
- visible assisted pair deletion, including normally immovable tiles, without score or momentum
- tray-aware deterministic Shuffle with verified recovery routes
- responsive controls, counts, highlights, and failure notices

Success criteria:

An almost-full tray can be recovered through a deterministic, replay-safe Shuffle; Hint reports when no pair is available without consuming Hint or Undo; and all consumable actions remain transactional and reproducible.

Detailed contract: [M06 Consumables](milestones/M06_CONSUMABLES.md)

## M7 - Art Foundation And First Visual Slice

Status: In progress. The Batch A visual-slice candidate is implemented: canonical tile geometry, an extensible 34-face manifest, the complete Default face set, source/runtime exports, responsive board and tray rendering, selection/rejection motion, transaction-driven pair removal, and the first production-style gameplay background.

The gameplay foundation also supports seeded flipped tiles. Rules version 14 requires player-driven reveals, preserves unmatched peeks, and immediately resolves a reveal when its mate is already held in the tray. Detailed contract: [Flipped Tiles](FLIPPED_TILES.md).

The first live-text arcade callout lane recognizes difficult pairs, current-run score milestones, and Combo milestones above 10 while arbitrating coincident events into one visible alert. Durable high-score triggering remains deferred to M9 profile ownership. Detailed contract: [Arcade Callouts](ARCADE_CALLOUTS.md).

The gameplay shell follows a mobile-first portrait stack with a bottom action dock, while landscape preserves the portrait-authored board and moves actions into console-friendly side rails. Detailed contract: [Responsive Game Shell](RESPONSIVE_GAME_SHELL.md).

Batch B is in progress: the responsive Momentum/multiplier HUD, portrait consumable controls, and all four tile-attached modifier identities have first production-style artwork. Modifier HUD/reward presentation and activation sequences remain before broader FX, character work, and the Neon skin proof.

Mobile rendering optimization is tracked in [`PERFORMANCE_OPTIMIZATION.md`](PERFORMANCE_OPTIMIZATION.md). That work begins with representative Android measurements, then addresses Board refresh/allocation cost, transparent overdraw, and tile atlasing before considering a custom renderer.

Detailed contracts: [M07 Art Foundation](milestones/M07_ART_FOUNDATION.md) and [Tile Art Pipeline](TILE_ART_PIPELINE.md)

## Later Milestones

Later milestones are recorded here to preserve ordering. Detailed implementation contracts remain deferred unless linked below.

- M8 Art Expansion + Cosmetics - additional skins, characters, backgrounds, and visual breadth built on the M7 contracts
- [M9 Local Profile + Game Library](milestones/M09_LOCAL_PROFILE_GAME_LIBRARY.md) - local profile persistence, durable deterministic game records, resume, history, and idempotent result application
- M10 Replays + Ghosts - playback and ghost presentation built on the durable M9 game library
- M11 Game Modes
- M12 Backend + Async Battle
- M13 Progression + Collection

M9 was inserted before replay presentation because profiles and durable game records are the persistence boundary those later features consume. The former M9 through M12 placeholders move one position later; their scope is otherwise unchanged.
