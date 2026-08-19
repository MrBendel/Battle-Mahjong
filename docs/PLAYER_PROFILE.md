# Player Profile And Cross-Game State

Status: Design Contract

This document defines ownership boundaries for data that lives longer than one Battle Mahjong game. It does not implement persistence, accounts, progression, currencies, or backend services.

## Goals

- Keep an individual game deterministic and replayable without reading mutable profile state.
- Store completed and in-progress games independently from the player profile.
- Allow a verified game result to update a profile exactly once.
- Support local persistence before accounts or cloud synchronization exist.
- Give future replay, progression, collection, and asynchronous battle systems stable boundaries.

## Ownership Boundaries

```text
PlayerProfile + Content Catalog + Start Request
                       |
                       v
             Snapshot Effective Choices
                       |
                       v
                 GameDefinition
                       |
                       v
        GameStore -> Transaction Timeline
                       |
                       v
                  GameRecord
                       |
              Verify Terminal Result
                       |
                       v
          Idempotent Profile Mutation
```

The three primary aggregates are independent:

- `PlayerProfile` owns durable player-facing state across games.
- `GameRecord` owns one game definition, its timeline, lifecycle metadata, and verified result.
- `GameStore` owns the active materialized simulation state for one game while it is loaded.

An account is not a gameplay aggregate. A future account may claim or synchronize profiles, but gameplay code must not require authentication.

## Player Profile

A profile is revisioned durable data associated with a stable local `profile_id`:

```text
PlayerProfile
  schema_version
  profile_id
  revision
  created_at
  updated_at
  selected_loadout
  selected_cosmetics
  modifier_collection
  consumable_inventory
  cosmetic_entitlements
  progression
  aggregate_statistics
  applied_game_result_ids
```

Only fields required by implemented features should be added. The lists above identify ownership, not finalized progression or economy requirements.

Profile time fields may use wall-clock time because they are metadata outside deterministic simulation. They must never drive gameplay outcomes inside a run.

Device preferences such as volume, window mode, input mapping, and accessibility settings should live in a separate `PlayerPreferences` record. A later product decision may choose which preferences synchronize between devices.

## Starting A Game

Starting a game is a boundary operation:

1. Read a consistent profile revision and the applicable content catalog.
2. Validate the requested mode, loadout, inventory, and entitlements.
3. Copy every gameplay-affecting choice into a new immutable `GameDefinition`.
4. Copy presentation-only choices, such as tile skin, into `GamePresentationSnapshot` on the `GameRecord`.
5. Create the initial game record before accepting gameplay commands.

The active game never consults mutable profile inventory, loadouts, progression, or entitlements after creation. Current modifier loadouts and consumable quantities already follow this snapshot rule.

Cosmetic choices do not participate in simulation hashes. Recording them beside the game allows a replay viewer to reproduce the original look when assets remain available, while still allowing the viewer to substitute another skin.

## Game Record

`GameRecord` is the durable envelope around one deterministic run:

```text
GameRecord
  schema_version
  game_id
  owner_profile_id
  record_revision
  lifecycle_status
  created_at
  updated_at
  origin
    mode_id
    challenge_id
    parent_game_id
  definition
  presentation_snapshot
  transactions
  terminal_state_hash
  verified_result
```

`definition + transactions` remains authoritative. Materialized state snapshots and result summaries are derived caches that must be disposable and verifiable.

`parent_game_id` links restart attempts without extending or erasing the previous timeline. A restarted game receives a new `game_id`.

Initial lifecycle values may include `active`, `completed`, `abandoned`, and `invalid`. Simulation status such as `playing`, `won`, or `lost` remains inside the reconstructed game state and must not be conflated with persistence health.

## Completing A Game

A terminal game produces a `GameResult` only after its definition and complete transaction timeline verify through the production reducer:

```text
GameResult
  result_id
  game_id
  profile_id
  terminal_status
  score
  verified_statistics
  reward_payload
  definition_hash
  terminal_state_hash
```

Applying a result to a profile is an atomic, revision-checked mutation. The profile records `result_id` as an idempotency receipt. Reapplying the same result succeeds as a no-op rather than granting rewards or statistics twice.

The exact reward payload, progression rules, and statistics are deferred. They must be derived from verified game facts and versioned rules, not trusted presentation events.

If the process stops after saving a terminal game but before updating the profile, recovery can derive and apply the same result again safely. If profile persistence succeeds first, the receipt prevents a duplicate application.

## Profile Mutations

Profile writes should be atomic and optimistic-concurrency checked:

```text
ProfileRepository.update(profile_id, expected_revision, mutation)
  -> updated profile | revision conflict | validation error
```

M9 does not require full event sourcing for profiles. A revisioned record, atomic replacement, and idempotent game-result receipts are sufficient until audit or synchronization requirements prove otherwise.

Game timelines remain append-only because transactions are required for replay and deterministic verification. Profile storage should not duplicate that machinery without a concrete need.

## Local Persistence Boundary

M9 should introduce repository interfaces rather than allowing UI or simulation code to read files directly:

```text
ProfileRepository
  create_profile()
  load_profile(profile_id)
  update_profile(profile_id, expected_revision, mutation)

GameRecordRepository
  create_record(record)
  append_transaction(game_id, expected_revision, transaction)
  finalize_record(game_id, expected_revision, result)
  load_record(game_id)
  list_records(query)
```

The first implementation is local-only under `user://`. On-disk representation remains an M9 implementation decision, but it must support:

- explicit schema versions;
- forward migrations from every shipped version;
- atomic replacement or equivalent crash-safe commits;
- corruption detection and recoverable backups;
- deterministic canonical payloads for definitions and transactions;
- tests using isolated temporary repositories.

Godot nodes, scene references, and mutable `Resource` instances must not become save-file domain models. Persistence adapters serialize plain data transfer objects at the boundary.

## Accounts And Cloud Sync

A future account layer may associate an authenticated `account_id` with one or more profiles. It must remain outside simulation and game-definition hashing.

Cloud synchronization introduces profile merges, device conflicts, authoritative reward validation, and security concerns. Those are backend milestone requirements and are intentionally not solved by the local repository contract.

Local IDs must therefore be globally safe strings rather than array positions or display names. The exact UUID implementation is deferred to M9.

## Decisions Recorded

- Running games are self-contained snapshots and never read mutable profile state.
- Game records are stored separately from profiles.
- Game timelines remain authoritative; snapshots and summaries are derived caches.
- Profile result application is atomic, revisioned, and idempotent by `result_id`.
- Cosmetics are recorded outside simulation hashes.
- Local profiles do not require accounts.
- Full profile event sourcing is not required for the first local implementation.

## Open Questions

- Exact local serialization format and backup rotation policy.
- Autosave frequency while a game is active.
- Whether the first release supports multiple local profiles.
- Which aggregate statistics are stored versus derived from the game library.
- How abandoned and invalid game records appear in player-facing history.
- Which presentation choices a replay should honor by default.
- Reward and progression schemas, which remain part of later feature design.
