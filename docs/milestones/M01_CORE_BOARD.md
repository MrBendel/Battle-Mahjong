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

Status: Open Question

- Exact placeholder tile art approach.

## Current M1 Simulation Decisions

Status: Decided

- Board positions use integer `(x, y, z)` coordinates.
- Each tile occupies a `2 x 2` footprint in board grid units.
- Horizontal blocking is evaluated against immediate left/right neighbors on the same `z` level.
- Cover blocking is evaluated by footprint overlap from any active tile at a higher `z` level.
- The initial fixed layout is a small six-tile smoke-test layout for command-line validation, not the final playable board.

## Command-Line Validation

```text
C:\Tools\Godot\godot.exe --headless -s tests/cli_test_runner.gd
```
