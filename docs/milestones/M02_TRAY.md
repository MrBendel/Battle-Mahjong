# M02 - Tray

Goal: implement the Battle Mahjong four-slot tray interaction model.

## Scope

- select exposed tiles into tray
- tray capacity = 4
- matching tray tiles resolve
- unmatched tiles stay
- overflowing unresolved tray causes failure
- Undo
- win/loss/restart

## Success Criteria

We can evaluate whether tray-based risk management is fun.

## Non-Goals

- Momentum.
- Modifiers.
- Consumables beyond basic Undo.
- Generator and solver.
- Async competition.

## Open Questions

Status: Open Question

- Exact Undo restrictions.
- Whether tray capacity can be configured for debug or accessibility modes.

## Current Headless Simulation Decisions

Status: Decided

- Base tray capacity is 4.
- A pair resolves immediately when the second matching identity enters the tray.
- The fourth unresolved tile causes immediate failure.
- The initial reference simulation uses 96 tiles, 24 identities, and 4 copies per identity.
- Undo, presentation, and player interaction remain outside the current headless slice.

## Command-Line Simulation

```text
C:\Tools\Godot\godot.exe --headless -s tests/simulation_runner.gd
```
