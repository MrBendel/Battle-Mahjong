# Game Transaction Timeline

Status: Implemented Foundation

This document defines the authoritative mutation model for Battle Mahjong. The M2 simulation uses this foundation; networking, durable persistence, replay UI, snapshots, and M3 timing remain future work.

## Goals

- Every accepted gameplay mutation is atomic and recorded.
- The current game state can be rebuilt deterministically from a game definition and transaction timeline.
- Transactions can be applied by local play, replay playback, tests, or a future network client through the same reducer.
- Undo is represented in history instead of silently editing history.
- Presentation remains a projection of simulation state.
- Schema and rules changes can be detected instead of producing subtly different replays.

This model is a foundation for synchronous multiplayer, but does not by itself solve server authority, input ordering, clocks, latency, prediction, rollback, or reconnection.

## Model Overview

```text
Game Definition + Initial State
              |
              v
Command -> Validate -> Transaction -> Apply -> New State
                             |
                             v
                    Append-only Timeline
```

Commands express player or system intent. Transactions are accepted facts. Only transactions mutate authoritative state.

## State Ownership

`GameStore` is the single writer and owns the definition, materialized state, and timeline.

```text
GameStore
  submit_command(command) -> CommandResult
  apply_transaction(transaction) -> ApplyResult
  current_state() -> read-only snapshot
  transactions_since(revision) -> transactions
```

- Presentation submits commands and renders read-only projections or snapshots.
- Gameplay systems may validate commands and build proposed transactions, but cannot mutate stored state directly.
- The store validates revision, applies all changes, verifies invariants and hashes, then appends the transaction.
- Failed validation leaves both state and timeline unchanged.
- GDScript callers must not receive mutable arrays, dictionaries, or tile objects owned by the store. Snapshots and transaction payloads must be copied or treated as immutable values.

Replay playback may use an isolated store with the same reducer. Network transport may deliver commands or transactions, but does not own gameplay state.

## Immutable Game Definition

Data that does not change during a run belongs in `GameDefinition`:

```text
GameDefinition
  schema_version
  rules_version
  seed
  configuration
  board_layout_id
  tiles
    tile_id
    face_identity
    board_position
```

Tile identity and original board position remain immutable. Cosmetic skin data is not part of the simulation definition.

The configuration must contain gameplay tuning such as base tray capacity. A replay embeds the effective configuration or a content-addressed reference to it.

## Materialized Game State

`GameStateData` is the current projection of accepted transactions:

```text
GameStateData
  revision
  status
  tile_zones
    tile_id -> board | tray | resolved
  tray_tile_ids
  selection_count
  resolved_pair_count
  max_tray_occupancy
  rng_state
```

A tile has one mutable location. This replaces the current duplicated representation where a tile can be marked removed while also being stored separately in the tray.

`tray_tile_ids` preserves unresolved selection order. Board selectability is derived from immutable positions plus tiles whose zone is `board`.

## Commands

A command is a request and may be rejected without changing state:

```text
GameCommand
  command_id
  actor_id
  expected_revision
  type
  payload
```

Initial command types:

- `SELECT_TILE { tile_id }`
- `UNDO {}`; the current M2 policy resolves the latest eligible transaction during validation.

`expected_revision` provides optimistic concurrency control. A future authority rejects or rebases commands submitted against stale state.

Restart creates a new game record with the same definition rather than erasing or extending the existing timeline. The current shell creates this record in memory; durable linkage between restarted records remains future work.

## Transactions

A transaction is the authoritative result of validating one command:

```text
GameTransaction
  schema_version
  transaction_id
  definition_hash
  revision
  actor_id
  command_id
  command_type
  logical_tick
  playback_time_ms
  changes
  telemetry
  reverts_transaction_id
  previous_state_hash
  next_state_hash
```

- `revision` is monotonic within a game record.
- `definition_hash` binds the transaction to exact seed, configuration, tile identities, and geometry.
- `logical_tick` orders deterministic transactions.
- `playback_time_ms` is monotonic active gameplay time supplied by the command. M3 uses it as authoritative input for momentum decay and replay pacing; system wall-clock time is never read by simulation code.
- `telemetry` records derived observations such as pair intervals and awarded multiplier. It does not drive reduction.
- `reverts_transaction_id` is present only for a compensating Undo transaction.
- State hashes detect divergence; they are validation aids, not game logic.

All changes in a transaction validate first and apply atomically. A partially applied transaction is invalid.

The transaction is the persistence and replication boundary. Signals, animations, and audio cues may be derived after commit, but they are never authoritative mutations.

Momentum does not generate frame-by-frame transactions. Each accepted command materializes elapsed decay as part of that command's atomic changes. Presentation may preview the same deterministic decay function between commands, but only committed command boundaries affect state hashes and replay data.

## Reversible Changes

Changes are typed simulation deltas with explicit before and after values:

```text
TileZoneChanged
  tile_id
  before
  after

TrayChanged
  before_tile_ids
  after_tile_ids

CounterChanged
  counter
  before
  after

StatusChanged
  before
  after

RngStateChanged
  before
  after
```

Typed changes are preferred over arbitrary property paths. They keep validation and schema migration explicit.

Applying a transaction forward uses each `after` value. Reversing a transaction applies changes in reverse order using each `before` value. The reducer verifies that the current value matches the expected side before changing it.

Example selection that remains unresolved:

```text
transaction 18: SELECT_TILE tile_043
  TileZoneChanged tile_043 board -> tray
  TrayChanged [tile_012] -> [tile_012, tile_043]
  CounterChanged selection_count 17 -> 18
```

Example selection that resolves a pair:

```text
transaction 19: SELECT_TILE tile_091
  TileZoneChanged tile_091 board -> resolved
  TileZoneChanged tile_043 tray -> resolved
  TrayChanged [tile_012, tile_043] -> [tile_012]
  CounterChanged selection_count 18 -> 19
  CounterChanged resolved_pair_count 8 -> 9
```

## Undo Semantics

Replay scrubbing and gameplay Undo are related but distinct operations.

- A replay viewer may move an in-memory cursor backward by applying transactions in reverse. This does not mutate the recorded game.
- Gameplay Undo is itself a command. If accepted, it appends a compensating transaction that returns the selected unresolved tile to the board and references the transaction being undone.
- Recorded history is never deleted or rewritten. Network peers see the same Undo fact and advance to the same new revision.
- An Undo command must be validated against current state. It cannot blindly reverse an old tray snapshot after later transactions have changed unrelated tray entries.

The current M2 policy only permits undoing the latest selected tile that still remains unresolved. Resolved-pair transactions are not undoable. Whether later game modes allow full transaction rewind remains an explicit future design question.

## Replay

A replay record contains:

```text
GameReplay
  game_id
  definition
  transactions
  terminal_state_hash
```

Playback starts from the initial state and applies transactions through the production reducer. Presentation consumes `playback_time_ms`, telemetry, and transaction types to animate the result like a video without storing video frames.

Seeking can replay from revision zero initially. Periodic verified snapshots may be added later as a performance optimization; the transaction timeline remains authoritative.

A replay is valid only when:

- schema and rules versions are supported;
- the game definition hash matches every transaction;
- transaction revisions and IDs are ordered correctly;
- every transaction validates against the preceding state;
- previous and next state hashes match; and
- the final hash matches `terminal_state_hash`.

## Deterministic Randomness

Future gameplay randomness must be consumed while building a transaction. The resulting transaction records the RNG state transition and all chosen outcomes.

Replaying an accepted transaction does not reroll randomness. Re-simulating commands may rerun the deterministic RNG and verify that it produces the recorded transaction.

The current state records the game seed as its initial RNG state. No implemented command consumes gameplay randomness yet, so `RngStateChanged` is defined but not yet emitted.

## Future Synchronous Replication

A minimal authoritative flow would be:

1. Client submits a command with `expected_revision`.
2. Authority validates it against the current state.
3. Authority assigns the next revision and transaction ID.
4. Authority commits the transaction atomically.
5. Authority broadcasts the transaction.
6. Clients verify revision and previous hash, apply it, and verify the next hash.
7. A mismatch requests a verified snapshot plus subsequent transactions.

Client prediction and rollback can reuse reversible changes, but should not be implemented until a networking milestone requires them.

## Implemented Foundation

Completed through M3:

1. Serializable `GameDefinition`, `GameStateData`, `GameCommand`, `GameChange`, and `GameTransaction` models.
2. One atomic reducer that applies and reverses typed changes.
3. A command processor that validates `SELECT_TILE` and `UNDO` intent and builds transactions.
4. A single-writer `GameStore` for local commands and externally supplied transactions.
5. Compensating M2 Undo transactions that preserve append-only history.
6. Read-only board and tray projections over normalized tile zones.
7. JSON round-trip, replay, reverse-apply, stale revision, atomic rejection, hash-divergence, snapshot isolation, and same-seed tests.
8. Monotonic active-play timestamps, atomic momentum decay, score changes, and pair timing telemetry.

Current serialization uses JSON-compatible dictionaries. State hashes use SHA-256 over a canonical ordered state string. Local command and transaction IDs are deterministic revision-based IDs within one game record.

Do not add networking, persistence services, prediction, or replay UI as part of this refactor.

## Remaining Decisions

- Durable replay container and migration format beyond the current JSON-compatible dictionaries.
- Globally unique transaction and command ID format for persisted or networked games.
- Snapshot interval and storage format.
- How active gameplay time pauses around menus, interruptions, and app suspension.
- Whether any future mode permits rewinding resolved-pair transactions.
- How restart links related game records.
