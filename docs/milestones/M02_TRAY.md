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

- Exact failure timing.
- Exact Undo restrictions.
- Whether tray capacity can be configured for debug or accessibility modes.
