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
- Scale new HUD, overlay, callout, and FX presentation through `scripts/presentation/presentation_scale.gd`; safe-display elements must account for insets, and Board-local elements must use their rendered region scale. Avoid unscaled pixel constants for artwork size, particle motion, typography, outlines, and animation offsets.
- Author gameplay maps portrait-first. Landscape may reflow the shell and use orientation-specific cosmetic tile geometry, but must not rotate, transpose, or rearrange stable layout slots.
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
- Before submitting every PR, increment the patch component of the tracked Android version in `export_presets.cfg` exactly once relative to the PR's base branch (for example, `0.1.1` to `0.1.2`). Keep the screenshot preset on the same base version with its `-screenshot` suffix. Do not reuse gameplay rules versions as app versions; follow `docs/VERSIONING.md`.

## Current State

- Milestones M0 through M6 are implemented.
- The playable reference board uses the portrait-authored `portrait_stack_96` layout with 96 tiles and preserves its stable slot topology and layer order in every viewport orientation.
- The current reference identity composition is 24 identities with four copies each. The complete 34-face art vocabulary remains a separate unresolved production decision.
- Authored layouts live in `configuration/layouts/` and are discovered automatically.
- Procedural layout requirements live in `configuration/layout_requirements/`.
- Layout authoring conventions and schema details are documented in `docs/LAYOUT_AUTHORING.md`.
- Game definitions record layout identity, revision, and content hash for deterministic replay validation.
- The M4 solver proves pair-only removal routes. Tray-aware routes that require temporarily holding unmatched tiles are deferred.
- M5 uses a configurable three-slot modifier loadout and gives reference games a level-0 `2.0x` starter Score Multiplier tile. Persistent collection and leveling remain deferred.
- M6 snapshots Hint, Undo, Delete Pair, and Shuffle quantities into each game definition. Delete Pair targets visible tiles independently from ordinary movement selectability; Shuffle preserves an almost-full tray and constructs a verified deterministic route. Persistent consumable ownership remains deferred.
- Rules version 8 and later use mistake-driven Combo with no current timeout. Rules version 7 and earlier retain timed Combo replay behavior. Accepted natural tile selections award configurable Momentum, and Undo compensates the actual gain without rewinding gameplay time.
- Rules version 14 and later require every flipped reveal to come from a player tap. A reveal with no held mate remains a peek and needs a second tap to enter the tray; a reveal matching a held tile resolves immediately through the normal queue animation. Selecting another board tile still closes an unmatched reveal. Earlier rules versions preserve their recorded behavior. At most one physical tile per face identity is flipped, exactly one active flipped tile may be face-up, and flipped-to-flipped direct matches are disallowed. The playable 96-tile shell exposes a default count of 12 through the Inspector.
- Arcade callouts use one presentation lane. Pair difficulty outranks current-run score milestones, which outrank Combo milestones; Combo callouts begin at 11. Persistent high-score comparison remains deferred to M9.
- Reveal transactions track the unique physical flipped tiles seen during the timeline. The final first-time reveal emits the one-shot `ALL TILES REVEALED!` board-progress callout; later re-flips do not retrigger it.
- Arcade callout typography, outline, and motion scale from the rendered Board footprint, with width-aware fitting for long live text on high-resolution phones.
- The responsive gameplay shell uses a portrait bottom action dock and landscape split-side action rails around the unchanged portrait-authored Board. Decorative Character/FX and debug regions yield before gameplay space.
- Tray tiles preserve the board's active orientation geometry at a configurable uniform scale, currently `0.80`. Natural and flipped match transfer scale into the tray footprint over a configurable presentation duration. When a held match removes an interior tray tile, later tiles retain visual previews through the collision and animate left over the configurable compaction duration while authoritative order updates immediately. Landing hold, two-position tray staging, collision, removal, compaction, and Undo return remain presentation-only, and authoritative pair resolution leaves no temporary tray occupancy.
- Pair collision reuses a startup-warmed pool of two `PairMatchFx` nodes, each owning a restrained six-particle CPU burst sharing a `64 x 64` smoke-tuft texture. Pixel profiling showed first-use GPU particles caused 66-83 ms presentation stalls; keep this tiny effect pooled on `CPUParticles2D` unless new device evidence supports a change. The full-resolution master remains under `art-source/fx/`. It has no central cloud stamp, radial blast drawing, or per-frame GDScript work; increase the effect budget only after mobile profiling.
- M7 Batch A has a complete visual-slice candidate. The Default set contains all 34 baseline faces as separate SVG masters and PNG runtime exports, with a presentation-only mapping for the current 24 abstract identities. Board and tray share the skin manifest; blocked rejection, board-to-tray motion, transaction-driven pair removal, and the brush-arcade background remain presentation-only.
- Board-stack depth is presentation-only: authored lower `z` layers are progressively darker, and `depth_presentation` in the skin manifest controls the lowest-layer brightness, the lighter near-top anchor, and responsive per-layer visual offset. Tile surfaces and shadows use alternating presentation bands so shadows sit below their own layer, and blocked state uses a separate cool veil. Face-down tiles use the blank ceramic base without placeholder text.
- Adjacent Default-skin tiles use a configurable slight visual overlap to compensate for transparent base-art padding in portrait and landscape; spacing remains cosmetic and must not alter authored board positions.
- Default tiles derive a configurable asymmetric manga-ink silhouette from the active base texture across board, tray, and animation previews; it remains presentation-only and distinct from cast shadows and blocked state.
- Selectable and otherwise visually active tiles always use canonical full brightness; authored-layer shading and the cool blocked veil apply only while a tile remains covered. Responsive layouts reserve the rendered tray-tile height before placing the Board.
- Mobile background/focus loss pauses the presentation without mutating game state, immediately blocks gameplay pointer input, clears transient targeting modes, and detaches pressed controls before Android can resize the task preview. Foreground recovery cancels stale touch and emulated-mouse presses, rebuilds interactive controls, reapplies layout after viewport restoration, and requires an explicit Resume.
- Pause and Game Over derive from the shared responsive `GameOverlay` template. Both use the limiting safe-display UI scale, shared panel/button styling, and safe-area centering. Pause owns session-only Sound and Haptics controls rendered as scalable full-row ON/OFF treatments rather than fixed-size engine indicator icons. Selection and pair haptic profiles are Inspector-tunable presentation feedback; preferences remain non-persistent until M9.
- Shuffle commits its deterministic slot remapping immediately, then one native parallel position Tween settles every active tile into its new slot with a slight overshoot. Face-up and face-down presentation remains unchanged during the move, and Shuffle timing never enters simulation state. Runtime route validation uses the tray-aware planner's direct deterministic geometry-and-face verifier; full transaction replay remains an offline solver/test responsibility.
- `UpdateChecker` is currently an adapter contract only; no native Google Play Core in-app-update plugin is included in Android exports. Version bumps and monotonic Play codes do not make the in-app prompt functional without that future integration.
- The Default skin has orientation-specific supplied ceramic bases: tall in portrait and wide in landscape. The active base, face safe area, board footprint, tray footprint, and animation previews change together without changing stable layout slots or simulation rules.
- The four M5 modifiers use shared tile-attached artwork declared by the active skin manifest and positioned as large upper-left badges through orientation-specific modifier bounds. Board tiles, tray tiles, and moving previews render the same cosmetic overlay. Their lightweight activation presentation reuses one Board-edge/icon layer; persistent state appears beside Score for Extra Life, on Momentum for Cold Snap and Score Multiplier, and on the queue for Tray +1.
- The gameplay shell's default-off `playtest_all_modifiers` Inspector flag snapshots all five level-0 modifiers onto the opening five solver-route pairs for deterministic M7 review. It may raise only that run's loadout capacity; production reference games retain their starter loadout and normal seeded placement.
- Three Pair Clear resolves up to three deterministic sequential pairs after its triggering pair, recalculating selectability after every projected removal and stopping when no next pair exists. It skips identities already held in the tray, records the actual ordered route in transaction telemetry, and gives assisted pairs no Score, Momentum, Combo, difficulty reward, or recursive modifier activation.
- Resolving a modifier-bearing pair emits one live-text reward callout derived from `modifiers_triggered` transaction telemetry. Modifier rewards own the single callout lane over board progress, difficulty, score, and Combo alerts; natural, flipped, and Delete Pair resolution all use the same policy.
- The Default skin also has supplied portrait and derived landscape tile-back textures. Face-down tiles render those backs and use a configurable `0.25` second two-phase horizontal flip with a brief edge-on hold, midpoint art swap, and additive afterimage; revealed tiles return to the normal base-plus-face composition.
- A flipped tile that auto-matches a held tray mate opens to a fully readable face, holds for the Inspector-backed `flipped_auto_match_hold_seconds`, then follows the ordinary queue landing and collision sequence. Its `MATCH!` live-text callout yields to modifier rewards and one-time board-progress alerts.
- Tile backs separate ceramic geometry from cosmetic ornament artwork. The Default manifest selects `arcade_spark` from `back_designs` and composites it inside orientation-specific `back_design_safe_area` geometry. Keep back-design identity presentation-only; profile ownership and durable selection remain deferred.
- The M3 scoring model uses a mistake-driven Combo chain. Natural pairs extend Combo; ordinary unmatched selections and elapsed time preserve it; live locked-tile taps and successful consumables break it through replay-safe transactions. Combo remains separate from the pair-difficulty score reward.
- The M7 portrait HUD uses exported Figma artwork from `gameplay-portrait-components-v1` (`68:2`) with runtime Mila Script Sans text, clipped Momentum fill, a square pause control, and a composable two-to-six-slot queue. The complete portrait composition scales from its `390 x 844` reference using the limiting safe-display dimension. Full-resolution exports live under `art-source/ui/portrait/`; optimized assets live under `game-assets/ui/portrait/`. Landscape retains the existing split-side shell.
- The portrait queue's canonical runtime pieces are `assets/UI/tile-queue/queue-cap.png` and `queue-repeat.png`. Both source files are `115 px` tall and must share rendered top/bottom edges. Mirror the cap for the right edge and overlap adjacent artwork by one source pixel to suppress filtered crop seams without changing the authored stride. Do not draw a separate empty-slot panel over the repeat artwork. Godot slots remain transparent geometry for live tiles and animation targets.
- Tray +1 expands that same composable queue from four to five repeat sections, moves the mirrored end cap, and marks the fifth section with its remaining pair duration. Capacity changes must reflow the responsive shell and contract again when the transaction-owned effect expires; presentation must never own or duplicate tray capacity.
- In portrait, the Momentum frame is independently centered on the safe display width and scales with the responsive HUD reference; do not center the combined score-plus-Momentum container.
- Portrait tray tiles use each queue repeat's logical slot center plus the documented slight left optical correction. Layout may reclaim transparent source padding around the visible queue and bottom action dock, but live tile and consumable touch targets must remain inside the safe display.
- Momentum uses eight gameplay tiers: unlabeled default `x1` plus seven visible HUD upgrades `x2` through `x8`. Default thresholds are spaced every `12500` units; a fast natural pair advances approximately one tier under the default tuning. Default per-second decay is Inspector-backed at `3000, 4000, 5000, 6000, 7000, 8000, 10000, 12000`, keeping consistent fast pairs net-positive at every tier.
- The `941 x 1672` Figma gameplay background is shared across orientations through scale-9 rendering with fixed `48 px` source margins on all sides. Stretch its interior rather than aspect-covering or cropping the gold border and corners.
- Portrait HUD shading uses the exact `390 x 167` `hud-top-scrim` vector from Figma node `68:4`, scaled to the full viewport width. Do not replace its top-to-transparent fade with a uniform color rectangle; landscape hides it.
- Portrait Board presentation uses compact internal geometry and hides the prototype Board title/status header so tiles receive the flexible space between the queue and bottom action dock. Landscape retains the diagnostic Board header.
- Portrait consumables recreate Figma `bottom-menu-live` (`80:30`) with the approved transparent runtime crops under `assets/UI/bottom-bar/` and live Mila text in Hint, Shuffle, Delete, Undo order. `bottom-tray-background-export.png` stretches horizontally as a nine-patch with `30%` source-width margins and `50%` source-height margins; landscape hides all portrait action artwork and retains its side rails.
- Portrait Mila Script Sans text uses the shared Regular/Bold `FontVariation` resources under `assets/fonts/` with `spacing_glyph = -2`; do not apply ad hoc per-label tracking.
- Hint presentation is Board-only and non-authoritative: suggested active tiles share a sinusoidal brightness/additive-glow pulse and subtle vertical bob, with no bordered outline. Clearing the Hint restores baseline tile geometry and modulation.
- Deterministic tile and pair difficulty analysis runs before each accepted natural selection and records derived transaction telemetry. The provisional geometry-only formula and its current reward tiers are documented in `docs/PAIR_DIFFICULTY.md`; they must remain orientation- and skin-independent, Inspector-backed, and snapshotted into each game definition.
- Moving one accessible blocker to expose the exact mate of a held tray tile records callout-only hidden-pair recognition. The mate must be selected on the next command; fully covered mates emit `eagle_eyes`, while visible-but-blocked mates emit `great`.
- Android performance evidence is captured with `scripts/capture_android_performance.ps1`; keep generated reports under ignored `build/performance/android/` and preserve raw `gfxinfo`, memory, display, and thermal output alongside parsed summaries.
- Pair-difficulty reward tuning favors a lively arcade cadence: notable requires score `130` and percentile `6000`; exceptional requires score `190` and percentile `8500`. Bonuses remain 25 and 50 percent respectively, and all values are snapshotted into `GameDefinition`.
- Cross-game state boundaries are documented in `docs/PLAYER_PROFILE.md`. M9 will implement local profiles and a durable game library before replay presentation, game modes, backend work, or progression.

## Current Boundary

M7 Art Foundation is the current implementation scope. Keep art identity and presentation independent from gameplay matching, and do not begin M8 or later implementation. The M9 cross-game architecture is documented for planning only; profile and game-library code remains deferred. Do not change the 24-identity reference deal composition as part of visual production without an explicit gameplay decision.

## Validation

Run Godot commands from the repository root using the Godot 4.6.3 console executable available on the machine.

- Core tests: `godot --headless --path . --script res://tests/cli_test_runner.gd`
- Responsive UI smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd`
- Portrait UI smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --portrait`
- Small-phone UI smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --small-phone`
- Safe-area portrait smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --portrait --safe-area`
- Safe-area landscape smoke test: `godot --headless --path . --script res://tests/ui_smoke_runner.gd -- --landscape --safe-area`
- Android orientation screenshots: `powershell -ExecutionPolicy Bypass -File scripts/test_android_screenshots.ps1`
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
- `docs/PERFORMANCE_OPTIMIZATION.md`: measurement protocol and ordered Board rendering optimization backlog.
- `docs/FLIPPED_TILES.md`: seeded face-down assignment, reveal, direct-match, consumable, and replay rules.
- `docs/ARCADE_CALLOUTS.md`: single-lane alert arbitration, Combo cadence, score milestones, and profile boundary.
- `docs/RESPONSIVE_GAME_SHELL.md`: portrait stack, landscape side rails, safe-area priorities, and input boundary.
- `docs/FIGMA_PORTRAIT_UI.md`: Figma source node, portrait asset boundary, dynamic HUD contract, and first-pass gaps.
- `docs/ART_DIRECTION.md`: canonical visual direction.
- `docs/ANDROID_PUBLISHING.md`: signed Android AAB export and Play Internal testing workflow.
- `docs/ANDROID_SCREENSHOT_TESTING.md`: emulator-based portrait, landscape, rotation, and safe-area screenshot checks.
- `docs/VERSIONING.md`: PR patch bumps, Android version names/codes, and release identity ownership.
- `docs/milestones/`: detailed milestone requirements and definitions of done.
