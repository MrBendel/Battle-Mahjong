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

## Later Milestones

Record only. Detailed implementation contracts are intentionally deferred.

- M4 Generator + Solver
- M5 Modifiers
- M6 Consumables
- M7 Juice / Anime Arcade Feedback
- M8 Tile Skin + Art System
- M9 Replays + Ghosts
- M10 Game Modes
- M11 Backend + Async Battle
- M12 Progression + Collection
