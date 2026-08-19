# AGENTS.md

Project-level instructions for Codex working on Battle Mahjong.

## Project Stack

- Engine: Godot 4.6.3 stable.
- Language: GDScript.
- Keep gameplay simulation independent from scenes, rendering, presentation, and UI.
- Treat deterministic simulation and replayability as core architectural requirements.

## Required Practice

- Read relevant `/docs` files before implementing a system.
- Implement only the requested milestone unless explicitly asked otherwise.
- Keep simulation independent from rendering and presentation.
- All gameplay randomness must come from seeded deterministic RNG.
- Avoid hard-coding tuning values; expose them through configuration.
- Keep tile identity independent from cosmetic tile skin.
- Preserve portrait and landscape support.
- Author gameplay maps portrait-first. Landscape may reflow the shell around the same board, but must not rotate, transpose, stretch, or rearrange layout slots.
- Build debug tooling when it materially helps verify deterministic gameplay.
- Prefer simple, testable architecture over premature framework-building.
- Do not implement networking, monetization, accounts, or backend systems until their milestones.
- Keep `PlayerProfile`, durable `GameRecord`, and active `GameStore` ownership separate. Snapshot gameplay-affecting profile choices into `GameDefinition` before play; never read mutable profile state during a run.
- Apply verified game results to profiles atomically and idempotently. Do not implement profile persistence before M9.
- Update docs when implementation reveals a real design constraint or when an explicit design decision changes.
- Do not silently reinterpret unresolved design questions as finalized requirements.
- Model gameplay mutations as transactions applied to game state and recorded in the game timeline.
- Preserve stable layout slot identifiers so transactions and replays do not depend on presentation coordinates.
- Keep authored layouts and procedural layout requirements data-driven under `configuration/`.
- Verify generated layouts structurally and with the solver before accepting them.
- Do not commit `.codex-remote-attachments/`; those files are local conversation inputs.

## Current State

- Milestones M0 through M6 are implemented.
- The playable reference board uses the portrait-authored `portrait_stack_96` layout with 96 tiles and preserves that geometry in every viewport orientation.
- The current reference identity composition is 24 identities with four copies each. The complete 34-face art vocabulary remains a separate unresolved production decision.
- Authored layouts live in `configuration/layouts/` and are discovered automatically.
- Procedural layout requirements live in `configuration/layout_requirements/`.
- Layout authoring conventions and schema details are documented in `docs/LAYOUT_AUTHORING.md`.
- Game definitions record layout identity, revision, and content hash for deterministic replay validation.
- The M4 solver proves pair-only removal routes. Tray-aware routes that require temporarily holding unmatched tiles are deferred.
- M5 uses a configurable three-slot modifier loadout and gives reference games a level-0 `2.0x` starter Score Multiplier tile. Persistent collection and leveling remain deferred.
- M6 snapshots Hint, Undo, Delete Pair, and Shuffle quantities into each game definition. Delete Pair targets visible tiles independently from ordinary movement selectability; Shuffle preserves an almost-full tray and constructs a verified deterministic route. Persistent consumable ownership remains deferred.
- M7 Batch A has a complete visual-slice candidate. The Default set contains all 34 baseline faces as separate SVG masters and PNG runtime exports, with a presentation-only mapping for the current 24 abstract identities. Board and tray share the skin manifest; blocked rejection, board-to-tray motion, transaction-driven pair removal, and the brush-arcade background remain presentation-only.
- The M3 scoring model now includes a definition-bound seven-second Combo window. Natural pairs extend Combo; ordinary unmatched selections preserve it; timeout, live locked-tile taps, and successful consumables break it through replay-safe transactions. Final Combo rewards remain deferred.
- Deterministic tile and pair difficulty analysis runs before each accepted natural selection and records derived transaction telemetry. The provisional geometry-only formula is documented in `docs/PAIR_DIFFICULTY.md`; it must remain orientation- and skin-independent and must not affect rewards until playtest validation.
- Cross-game state boundaries are documented in `docs/PLAYER_PROFILE.md`. M9 will implement local profiles and a durable game library before replay presentation, game modes, backend work, or progression.

## Current Boundary

M7 Art Foundation is the current implementation scope. Keep art identity and presentation independent from gameplay matching, and do not begin M8 or later implementation. The M9 cross-game architecture is documented for planning only; profile and game-library code remains deferred. Do not change the 24-identity reference deal composition as part of visual production without an explicit gameplay decision.

## Validation

Run Godot commands from the repository root using the Godot 4.6.3 console executable available on the machine.

- Core tests: `godot --headless --path . --script res://tests/cli_test_runner.gd`
- Responsive UI smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd`
- Portrait UI smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --portrait`
- Small-phone UI smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --small-phone`
- Simulation suite: `godot --headless --path . --script res://tests/simulation_runner.gd`
- Layout generation: `godot --headless --path . --script res://scripts/tools/generate_layout.gd -- <requirements.json> <seed> <output.json>`
- Default face generation: `godot --headless --path . --script res://scripts/tools/generate_default_tile_faces.gd`
- Tile-art export: `godot --headless --path . --script res://scripts/tools/export_tile_art.gd`

For documentation-only changes, `git diff --check` is sufficient unless the documentation describes behavior that should be verified against the executable project.

## Documentation Map

- `docs/ROADMAP.md`: milestone order, status, and scope.
- `docs/LAYOUT_AUTHORING.md`: authored and generated board-layout workflow.
- `docs/TILE_ART_PIPELINE.md`: canonical tile geometry, identity, source/export, and skin-manifest contract.
- `docs/PLAYER_PROFILE.md`: profile, game-record, result-application, and future account boundaries.
- `docs/PAIR_DIFFICULTY.md`: deterministic opportunity scoring, ranking, telemetry, and tuning boundary.
- `docs/ART_DIRECTION.md`: canonical visual direction.
- `docs/milestones/`: detailed milestone requirements and definitions of done.
