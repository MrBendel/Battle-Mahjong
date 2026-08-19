# M09 - Local Profile And Game Library

Status: Planned

Goal: persist cross-game player state and deterministic game records locally without introducing accounts, cloud services, or progression systems.

Detailed architecture: [Player Profile And Cross-Game State](../PLAYER_PROFILE.md)

## Dependencies

- Stable transactional `GameDefinition`, `GameStore`, and timeline contracts.
- Versioned deterministic definitions and transactions.
- Concrete profile-derived inputs from implemented gameplay systems.

M8 art expansion may use debug-unlocked cosmetics. Persistent cosmetic ownership is not required before M9.

## Scope

- versioned `PlayerProfile` data with a stable local identifier and revision;
- separate device-level `PlayerPreferences`;
- durable `GameRecord` envelopes for active and completed runs;
- immutable start-game snapshots from profile choices into `GameDefinition`;
- presentation snapshots for cosmetic selections outside simulation hashes;
- local profile and game-record repository interfaces;
- crash-safe local persistence under `user://`;
- schema migration tests;
- game resume from a verified definition and timeline;
- terminal result derivation and idempotent profile application;
- game-history queries needed by the following replay milestone.

## Success Criteria

- A game can be closed, reloaded, and reconstructed to the same revision and state hash.
- A completed game appears in a local game library with a verified terminal result.
- Applying the same result more than once cannot duplicate statistics, inventory, or future rewards.
- Starting a game snapshots gameplay-affecting profile choices and remains reproducible after the profile changes.
- Corrupt or unsupported records fail explicitly without silently mutating a profile.
- Persistence tests run against isolated storage without scenes or presentation.

## Non-Goals

- replay playback UI or ghost presentation;
- finalized progression, currencies, rewards, shops, or collection balancing;
- authentication, accounts, cloud synchronization, or cross-device merge;
- backend authority or anti-cheat;
- social identity, friends, rankings, or matchmaking;
- changing simulation rules or gameplay composition.

## Initial Decisions

- One local profile is sufficient for the first implementation, but identifiers and repositories must not assume there can only ever be one.
- Game records and profiles are separate aggregates.
- `definition + transactions` is authoritative for a game record.
- Profile persistence is revisioned and atomic but is not initially event-sourced.
- Verified game results use durable idempotency receipts.
- Account association remains an adapter added by a backend milestone.

## Validation

- profile round-trip and revision-conflict tests;
- game-record round-trip and deterministic reconstruction tests;
- interrupted-write and backup-recovery tests;
- migration tests from every fixture schema version;
- duplicate-result application tests;
- profile-change-after-game-start tests;
- corrupt definition, timeline, and state-hash rejection tests.
