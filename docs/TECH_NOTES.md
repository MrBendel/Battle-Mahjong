# Technical Notes

## Engine Choice

Status: Decided

The game engine is Godot 4.6.3 stable.

Primary language:

- GDScript

Rationale:

- Battle Mahjong is heavily 2D.
- The game needs particles, shaders, animation, audio, and mobile support.
- The project should remain friendly to agent-driven development.
- GDScript is the primary language for gameplay and project code unless a later technical constraint requires a documented exception.

## Architecture Principles

Separate simulation from presentation.

```text
Presentation / UI / FX / Audio
            |
        Game Events
            |
       Game Engine
            |
   Generator / Solver
```

The game engine should handle:

- board state
- selectability
- tray
- matching
- momentum
- modifiers
- consumables
- seeded RNG
- scoring
- deterministic events

Presentation should handle:

- tile artwork
- animations
- particles
- screen shake
- anime transitions
- announcer
- UI
- responsive layout

Example simulation event:

```text
MODIFIER_TRIGGERED: cold_snap
```

The presentation layer decides how that looks and sounds.

Do not couple gameplay state to specific visual effects.

## M0 Project Structure

Status: Decided

Godot project files use this initial structure:

```text
project.godot
scenes/
  main.tscn
scripts/
  simulation/
  presentation/
  ui/
```

Current boundaries:

- `scripts/simulation/`: deterministic gameplay-facing utilities that can run without presentation.
- `scripts/presentation/`: screen composition, responsive layout, and visual placeholders.
- `scripts/ui/`: debug and interface controls.
- `tests/`: command-line simulation tests that can run headlessly.

Do not add deeper structure until an implementation milestone needs it.

Current simulation scripts are consumed through explicit `preload()` references instead of global `class_name` registration. This keeps cold-start command-line tests predictable.

## Determinism

Gameplay should be deterministic from day one.

Conceptually:

```text
GameConfig
+ BoardLayout
+ Seed
+ PlayerLoadout
= Reproducible Game
```

Random behavior should use seeded RNG.

A run should eventually be representable as a timestamped event stream:

```text
seed: 92817361

events:
  0.000 START
  0.821 SELECT tile_43
  1.104 SELECT tile_91
  2.430 USE cold_snap
```

This architecture supports:

- Daily Challenges
- tournaments
- async Battle
- ghost playback
- deterministic bug reproduction
- board difficulty analysis
- replay validation

Status: Implemented Foundation

- The command, transaction, reversible change, Undo, replication, and replay contracts are defined in `GAME_TIMELINE.md`.
- The M2 simulation uses a single-writer transactional store, normalized state, JSON-compatible models, and canonical SHA-256 state hashes.
- Durable replay storage, global identifiers, snapshots, and replay timing remain open decisions.
- Exact seeded RNG state serialization remains an open decision.

## Configuration

Avoid hard-coded tuning values.

Configuration should eventually cover:

- momentum gains and decay
- multiplier thresholds
- tray capacity
- modifier behavior
- consumable availability
- difficulty targets
- scoring

Status: Open Question

- Configuration file format.
- Runtime override strategy for debug builds.

## Validation

Current M0 smoke test:

```text
C:\Tools\Godot\godot.exe --headless --path . --quit-after 5
```

This verifies that the Godot project and main scene launch without script parse errors.

## Out Of Scope Until Later Milestones

- networking
- monetization
- accounts
- backend systems
- ranked services
- permanent progression implementation
