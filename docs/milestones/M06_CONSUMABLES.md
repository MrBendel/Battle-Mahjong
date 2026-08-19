# M06 - Consumables

## Goal

Add deliberate, limited-use recovery tools without weakening deterministic simulation, replay validation, or the distinction between player-controlled consumables and tile-bound modifiers.

## Run Inventory

`GameDefinition` snapshots integer quantities for Hint, Undo, Delete Pair, and Shuffle. The reference game starts with one of each so the playable shell exposes the complete M6 slice. `GameStateData` owns the remaining quantities, and every successful use records the complete before/after inventory in its transaction.

M6 does not implement accounts, persistent ownership, rewards, purchases, or profile progression. A later profile system supplies the run snapshot when creating the definition.

Rejected uses are atomic: they consume no quantity, advance no clock, append no transaction, and cannot consume another consumable type.

## Hint

Hint chooses deterministically:

1. the lowest-ID selectable board mate for the earliest unresolved tray tile; otherwise
2. the lowest-ID selectable board pair.

The suggested physical tile IDs are stored in transient state and highlighted by presentation. The next accepted action clears the suggestion. Hint awards no score or momentum.

If no pair is currently available, the UI tells the player to try another move or Shuffle. No Hint or Undo quantity is consumed and no transaction is recorded.

## Undo

Undo retains the existing append-only compensation behavior and now requires an Undo quantity. A successful use returns only the latest unresolved tray tile selected after the most recent resolved pair to its reserved board slot and consumes one Undo. Completing a pair clears prior Undo eligibility, so Undo cannot cross that commit boundary or reopen a resolved pair. A later unmatched selection establishes a fresh Undo opportunity. Failure consumes nothing.

## Delete Pair

The player arms Delete Pair and selects a currently selectable board tile. The simulation removes it with the lowest-ID currently selectable matching physical tile. A successful assisted pair:

- consumes one Delete Pair;
- increments selection and resolved-pair counters;
- triggers attached modifier tiles;
- advances pair-based Tray +1 duration; and
- awards no score or momentum.

Blocked tiles and targets without a selectable mate are rejected without consumption.

## Tray-Aware Shuffle

Shuffle is a recovery tool and is valid while a run is playing with zero through one-less-than-capacity unresolved tray tiles. In particular, it supports an almost-full tray with two or three unresolved tiles.

Shuffle preserves:

- the occupied board geometry and stable authored slot IDs;
- tray contents and order;
- each physical tile's face and modifier attachment; and
- resolved tiles and all unrelated state.

The simulation constructively assigns a selectable board mate for every tray tile, then assigns the remaining physical tiles as a verified pair-removal route. It consumes seeded deterministic RNG, records physical-tile-to-slot changes plus the resulting RNG state, and verifies the candidate route through normal selection transactions before accepting it. Failure consumes nothing.

## Presentation

The responsive consumables region provides Hint, Delete Pair, and Shuffle controls with remaining quantities and notices. Undo remains beside the tray and displays its quantity. Hint suggestions are highlighted on the board; Delete Pair uses the next board selection as its target.

## Definition of Done

- All four quantities are definition-bound, state-hashed, serialized, reversible, and replay-safe.
- Rejected actions never consume inventory or append history.
- Hint prioritizes tray recovery and reports a no-pair state without consuming Hint or Undo.
- Shuffle succeeds with two or three unresolved tray tiles, preserves them, and constructs a verified route.
- Delete Pair has no scoring or momentum reward while retaining modifier interaction.
- Landscape and portrait presentation remain within their regions.
- Core, simulation, and responsive UI suites pass.

## Deferred

- Persistent consumable ownership, acquisition, upgrades, and economy.
- Ranked-mode policy and replay-category labels for assisted runs.
- Undo depth upgrades or resolved-pair reversal.
- Backend, accounts, networking, and monetization.
