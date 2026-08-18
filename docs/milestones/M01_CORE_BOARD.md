# M01 - Core Mahjong Board

Goal: implement a traditional layered mahjong-solitaire board.

## Scope

- tile data model
- board positions
- layered `(x, y, z)` geometry
- selectability/blocking rules
- matching rules
- pair removal
- one fixed board layout
- placeholder tile graphics

## Success Criteria

A player can interact with and clear a traditional layered board using legal tile rules.

## Non-Goals

- Battle Mahjong tray risk model.
- Momentum.
- Modifiers.
- Consumables.
- Generator and solver.
- Async competition.

## Open Questions

Status: Decided

- Placeholder tiles are code-drawn controls with family-coded colors and short face labels. Tile skins remain presentation-only and do not alter logical identity.

## Current M1 Simulation Decisions

Status: Decided

- Board positions use integer `(x, y, z)` coordinates.
- Each tile occupies a `2 x 2` footprint in board grid units.
- Horizontal blocking is evaluated against immediate left/right neighbors on the same `z` level.
- Cover blocking is evaluated by footprint overlap from any active tile at a higher `z` level.
- The six-tile fixed layout remains the focused command-line smoke test.
- The playable M1 board uses one fixed 96-position, three-layer geometry with 24 identities and four copies per identity.
- The seed changes only identity placement; board geometry remains fixed.
- The player selects two free matching tiles directly. A mismatch moves selection to the second tile, and selecting the same tile again cancels selection.
- Tray behavior remains outside the M1 presentation even though headless experiments exist for later milestone validation.

## Command-Line Validation

```text
C:\Tools\Godot\godot.exe --headless -s tests/cli_test_runner.gd
```
