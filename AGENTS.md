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
- Build debug tooling when it materially helps verify deterministic gameplay.
- Prefer simple, testable architecture over premature framework-building.
- Do not implement networking, monetization, accounts, or backend systems until their milestones.
- Update docs when implementation reveals a real design constraint or when an explicit design decision changes.
- Do not silently reinterpret unresolved design questions as finalized requirements.
- Model gameplay mutations as transactions applied to game state and recorded in the game timeline.
- Preserve stable layout slot identifiers so transactions and replays do not depend on presentation coordinates.
- Keep authored layouts and procedural layout requirements data-driven under `configuration/`.
- Verify generated layouts structurally and with the solver before accepting them.
- Do not commit `.codex-remote-attachments/`; those files are local conversation inputs.

## Current State

- Milestones M0 through M6 are implemented.
- The playable reference board uses the authored `portrait_stack_96` layout with 96 tiles.
- The current reference identity composition is 24 identities with four copies each. The complete 34-face art vocabulary remains a separate unresolved production decision.
- Authored layouts live in `configuration/layouts/` and are discovered automatically.
- Procedural layout requirements live in `configuration/layout_requirements/`.
- Layout authoring conventions and schema details are documented in `docs/LAYOUT_AUTHORING.md`.
- Game definitions record layout identity, revision, and content hash for deterministic replay validation.
- The M4 solver proves pair-only removal routes. Tray-aware routes that require temporarily holding unmatched tiles are deferred.
- M5 uses a configurable three-slot modifier loadout and gives reference games a level-0 `2.0x` starter Score Multiplier tile. Persistent collection and leveling remain deferred.
- M6 snapshots Hint, Undo, Delete Pair, and Shuffle quantities into each game definition. Shuffle preserves an almost-full tray and constructs a verified deterministic route; persistent consumable ownership remains deferred.

## Current Boundary

M6 Consumables is the current completed scope. Do not begin M7 or any later gameplay milestone until explicitly requested. M7 Art Foundation currently defines documentation and production requirements only; do not add production art as incidental work.

## Validation

Run Godot commands from the repository root using the Godot 4.6.3 console executable available on the machine.

- Core tests: `godot --headless --path . --script res://tests/cli_test_runner.gd`
- Responsive UI smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd`
- Portrait UI smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --portrait`
- Simulation suite: `godot --headless --path . --script res://tests/simulation_runner.gd`
- Layout generation: `godot --headless --path . --script res://scripts/tools/generate_layout.gd -- <requirements.json> <seed> <output.json>`

For documentation-only changes, `git diff --check` is sufficient unless the documentation describes behavior that should be verified against the executable project.

## Documentation Map

- `docs/ROADMAP.md`: milestone order, status, and scope.
- `docs/LAYOUT_AUTHORING.md`: authored and generated board-layout workflow.
- `docs/ART_DIRECTION.md`: canonical visual direction.
- `docs/milestones/`: detailed milestone requirements and definitions of done.
