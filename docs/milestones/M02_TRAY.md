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

Status: Decided For M2

- M2 Undo appends a compensating transaction that returns the most recently selected unresolved tray tile to the board.
- Undo cannot restore an already resolved pair and is unavailable after win or loss.
- Restart recreates the same board geometry and seeded identity deal.
- Player-facing tray capacity remains four. `GameDefinition` configuration retains a capacity parameter for simulation tests; debug and accessibility modes are deferred.

## Current M2 Decisions

Status: Decided

- Base tray capacity is 4.
- A pair resolves immediately when the second matching identity enters the tray.
- The fourth unresolved tile causes immediate failure.
- The initial reference simulation uses 96 tiles, 24 identities, and 4 copies per identity.
- Board selection now moves exposed tiles into the tray instead of directly removing pairs.
- The four tray slots, Undo, restart, and terminal win/loss state are presented in both portrait and landscape layouts.
- Accepted selections and Undo operations are recorded as hash-linked atomic transactions over normalized game state.
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
