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
- Simulation policies include a guaranteed-route baseline, a one-ply bounded-attention heuristic, and a blind random control.
- The bounded-attention window is simulation configuration; the current easy-board baseline observes up to 10 selectable tiles per decision.

## Command-Line Simulation

```text
C:\Tools\Godot\godot.exe --headless -s tests/simulation_runner.gd
```

Current 100-seed baseline with an attention limit of 10:

```text
pair-aware:       100 wins, 0 losses, 48.00 average pairs
bounded-attention: 93 wins, 7 losses, 45.68 average pairs
blind random:       0 wins, 100 losses, 0.79 average pairs
```

The bounded-attention policy is a deterministic diagnostic heuristic, not a claim about real player behavior. It samples a limited visible set, prioritizes known matches, and uses one-ply reveal scoring when it cannot see a pair.
