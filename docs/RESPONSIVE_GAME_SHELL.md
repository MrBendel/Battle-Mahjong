# Responsive Game Shell

The mobile/console-oriented shell follows two presentation compositions around the same portrait-authored board. Orientation may reposition HUD and action regions and select an orientation-specific cosmetic tile geometry, but it never rotates, transposes, or rearranges stable board slots.

`configuration/default_gameplay_theme.tres` is the shared presentation asset contract for both compositions. It selects the background layers, HUD artwork and fonts, tray pieces, consumable pieces and icons, Pause artwork, and tile-skin manifest. A theme may supply a landscape background composition; otherwise landscape falls back to its portrait background. Views receive that same resource when the shell constructs them; orientation changes presentation, not theme ownership or runtime state. New themes may override individual exported paths while inheriting defaults for the remaining pieces, allowing seasonal releases without duplicating a complete portrait or landscape screen.

## Portrait

Portrait uses the M7 Figma HUD documented in [Figma Portrait Gameplay UI](FIGMA_PORTRAIT_UI.md) and a strict vertical priority stack:

1. Score, Momentum, multiplier, and Combo status.
2. Two-to-six-slot tray (four slots in normal gameplay).
3. The largest possible uninterrupted Board region.
4. A bottom action dock ordered Hint, Shuffle, Delete Pair, Undo.

The themed background selects its landscape composition when supplied and otherwise falls back to the portrait surface. Both use fixed-margin scale-9 rendering. Score and Momentum use exported frames with runtime Mila Script Sans text; the Momentum fill remains clipped and animated from live state. The pause control stays square in the upper-right safe area. The queue is centered and composed from first-well and final-well end sections plus a repeatable middle well for capacities from two through six.

Portrait region proportions are normalized from the approved `942 x 1672` layout guide: Status `64.9% x 9.3%`, Tray `64.9% x 9.3%`, Board `84.0% x 57.7%`, and Actions `50.0% x 11.1%`. Their reference offsets are data constants in `game_shell.gd` and are projected into the safe display independently on each axis. The Board uses its full region fit and an `0.85` presentation-only vertical slot stride so the tall authored stack fills the broader target silhouette without changing tile geometry or gameplay coordinates.

The portrait status box uses a `613 x 155` internal reference grid with consistent `7 px` gutters. Hearts, score, and streak occupy the three upper cells (`198 / 230 / 138 px` wide); Momentum and the current multiplier occupy the two lower cells (`435 / 138 px` wide). Runtime labels and meter fill scale within those cells rather than relying on viewport-specific offsets.

The action dock uses one horizontal row of large ceramic touch targets on a composable dark tray. Separate end caps surround one repeat section per visible consumable, allowing the same presentation to support any positive action count with balanced outer margins. Remaining inventory is reinforced by up to three vertically stacked tile layers; each layer rises by the tile artwork's implied ceramic base thickness while an exact live count remains in the tile's lower-right. The tray and ceramic stacks cast independent responsive shadows. Decorative Character/FX and the debug panel are hidden by default so they cannot reduce the Board footprint. The debug panel remains available through the `show_debug_panel` Inspector property. The Tray derives a scaled tile footprint from the Board through the shell's orientation-specific tray-scale Inspector properties, then reserves the corresponding rendered tile, ink outline, and queue-art height before the Board is placed. The Board ends above the action targets; region artwork and hitboxes never overlap.

On compact phones below `800` logical pixels tall, the redundant Board title and tile-count header collapse before the tile field shrinks. This keeps the tall ceramic tiles above their `32 x 48` presentation minimum.

## Landscape

Landscape reuses the same themed components in the proportions established by the horizontal gameplay reference:

- Score and Momentum occupy a compact upper-left panel.
- The portrait porcelain tray pieces form a vertical rack to the right of the Board while live tiles retain landscape geometry.
- Pause occupies the upper-right safe area.
- The portrait-authored Board fills the broad center without changing slot IDs or layer order.
- Hint, Shuffle, Delete Pair, and Undo reuse the ceramic action tiles in one lower-left row.

Consumables are managed by one transparent overlay whose visible buttons remain completely outside the Board. Each landscape action preserves at least a `54 x 54` logical-pixel target in the validated reference viewport.

## Responsive Priorities

Safe-area insets are applied before margins and region allocation. When space becomes constrained, presentation yields in this order:

1. Decorative Character/FX.
2. Debug information.
3. Nonessential region labels and notices.

Board tiles, tray tiles, Momentum, score, pause, and consumable actions remain readable and operable. `portrait_board_content_scale` and `landscape_board_content_scale` tune the centered puzzle footprint independently of simulation geometry; both currently default to `1.00`. Landscape projects score, Board, tray, actions, and Pause from the approved `1680 x 909` horizontal reference into the current safe display. The wide landscape tile uses a `1.20` visual row stride to fill the taller central silhouette without changing stable slots or simulation coordinates. Portrait and landscape tray tiles use `0.72` and `0.70` of the rendered Board tile footprint respectively. Landscape rotates only the shared porcelain tray art sections into a vertical arrangement; live tray tiles retain the active wide landscape ceramic geometry and upright face art. The authored end wells and repeatable middle wells remain the same assets and data-driven two-to-six-slot component used by portrait. Transfer previews animate into the active smaller target using the shell's `tile_transfer_seconds` presentation setting. When resolving a held tile compacts later tray entries, presentation previews preserve their old positions through the pair collision and then travel toward their next slot over `tray_compaction_seconds`; authoritative tray order still updates immediately.

An Extra Life recovery commits atomically, then presentation completes the readable consequence: the attempted final tile reaches the last tray slot, the active tray artwork receives a short red warning pulse, and the attempted tile plus every recovered tray tile cascade back to their stable Board slots. Board input remains locked until all return previews land. Warning, return, and stagger durations are Inspector tuning and do not enter transactions or replay state.

All new presentation elements must define an authored reference size and derive runtime dimensions from `scripts/presentation/presentation_scale.gd`. Full-screen HUD, overlays, and FX use the limiting safe-display scale after insets; Board-local callouts use the limiting scale of the Board region. Do not introduce fixed pixel sizes for runtime artwork, particle travel, font sizes, outlines, or animation offsets without multiplying them by the appropriate presentation scale. Match collision FX use the shared safe-display scale plus the Inspector-tunable `match_fx_scale_multiplier`, which defaults to `1.30`; their particle count and lifetime remain constant for predictable mobile cost.

On mobile application pause or focus loss, the shell pauses gameplay without changing authoritative game state. Foreground recovery cancels stale touch and emulated-mouse presses, refreshes interactive presentation controls, and leaves the pause menu open until the player explicitly resumes. This prevents a touch release lost during Android suspension from leaving later taps partially unresponsive.

Pause and Game Over share the reusable `GameOverlay` presentation template. The wash, framed panel, safe-area placement, typography, spacing, borders, and command targets use the same limiting safe-display scale as the portrait HUD and remain centered in either orientation. Game Over supplies result-specific title, statistics, and actions without owning a second fixed-size layout. Pause toggles use scalable full-row ON/OFF treatments instead of Godot's fixed-size CheckButton indicator artwork. Sound and haptics are session settings in M7 and default on; durable preference storage remains deferred to M9. Tile selection uses a short light haptic, while pair resolution and assisted pair deletion use a longer, stronger profile. These feedback values are presentation tuning exposed on the game shell and never enter deterministic game state or replay transactions.

Successful Shuffle transactions use a short presentation lock. Every active tile visibly settles from its old slot into the committed deterministic slot mapping with a slight overshoot. Face-up tiles remain visible and face-down tiles remain face-down throughout the move. One native parallel Tween owns the position tracks; Shuffle does not run full-Board flip phases or per-frame GDScript interpolation. The Inspector-tunable movement duration does not alter the Shuffle transaction or replay timeline.

Board tiles overlap visually, so their scene-tree sibling order must follow the current presentation stack after Shuffle or any slot remap. Godot does not use `CanvasItem.z_index` alone to choose which overlapping `Control` receives pointer input; stale sibling order can allow a lower tile to intercept a top tile's touch target.

## Input Boundary

This composition improves thumb reach and spatial predictability for mobile and future controller navigation. It does not itself implement gamepad tile navigation, focus graphs, or console platform integration; those remain separate input work.

### Tray danger and heart-loss feedback

One remaining tray space starts a presentation-only three-second timer, including expanded Tray +1 capacity. A soft red edge vignette and tray tint then pulse slowly; creating space, pausing, or leaving play clears the warning. The edge width uses the shared safe-display scale. Inspector properties control delay, pulse period, and warning/impact strength.

Extra Life recovery holds the filled tray for 420 ms after arrival, with a single red edge impact, rocking tile previews, a departing themed heart, and a dedicated 100 ms haptic respecting the session preference. Returns take 360 ms plus stagger. The existing recovery input lock lasts through landing; simulation still commits recovery atomically. Timing remains outside replay state.

### Interchangeable Board trays

The large Board tray is independent of the small tile queue. `GameplayTheme.board_tray_skin` selects `dark`, `paper`, `porcelain`, `terrazzo`, or `walnut`; the default is `dark`. The theme also exposes an enable flag, reference-space interior padding, and a texture override. This is Inspector/theme selection only; player ownership and saved cosmetic preferences remain deferred.

Runtime artwork lives in `game-assets/ui/board-trays/`, copied unchanged from the supplied `art-source/inspiration/gameplay/background frame*.png` masters. Four supplied variants contain opaque checkerboard outside the rim. Their runtime shader borrows the dark original's alpha silhouette; custom texture overrides should supply their own transparency. The layered Board uses a nine-patch frame below shadows and tiles, with a shared PresentationScale-derived rim and padding in both orientations. Frame input is ignored, and stable layout slots, tile skins, transactions, and hashes are unchanged.

The Board tray extends beyond the tile-fit region by a theme-controlled `26 x 30` reference-pixel outset, with a `0.30` source-to-reference rim scale. This gives the supplied inspiration's broader surface and heavier rim without shrinking or relocating the tile field. Both values scale with the rendered Board region through `PresentationScale` and apply to all five skins.

### Larger portrait playfield and lower actions

The annotated gameplay reference updates portrait placement to queue `(105, 195, 731, 205)`, Board `(54, 450, 835, 1020)`, and actions `(236, 1530, 471, 120)` in the existing `942 x 1672` safe-display reference. The portrait action component removes unused lower source space from its layout and touch bounds (`471 x 120`), letting the dock sit nearer the safe bottom edge. The portrait Board uses `0.74` cosmetic vertical stride to fit larger tiles, and queue tiles use `0.90` of the Board tile footprint. Landscape keeps its existing shell recipe and tile tuning. Stable slot topology, coverage, and matching rules are unchanged.

Portrait queue clearance reserves the full queue Control bounds, an eight-reference-pixel safe-display-scaled gap, and the theme’s scaled Board-frame outset. This runs even when the queue does not grow. The Board bottom stays anchored; its top and tile-fit area yield as needed on wide portrait displays and with the update banner.

Board tiles fit the full framed interior (frame rectangle minus theme padding), including the extra surface created by the frame outset. With `board_tray_fill_height` enabled, width-limited layouts relax cosmetic row compression up to the natural 1.0 stride to use available height. Tile proportions and stable slots remain unchanged; width and natural row spacing remain safety limits.

Vertical centering uses the actual projected top and bottom of all authored tile rectangles, including per-layer lift, rather than assuming maximum lift occurs at the outermost rows. Removed tiles remain part of these layout bounds so the stack never recenters during play.

Queue tiles use the theme-controlled `tray_tile_fill_scale` (default `1.12`) to fill their wells more closely. This enlarges live tiles and the shared transfer/collision target rectangles by 12 percent around each existing well center without enlarging queue artwork or shifting the Board.

The porcelain queue artwork uses `tray_artwork_scale = 0.95` in both orientations. Caps and repeats shrink together around the queue center, while held tile sizes remain unchanged and target centers follow the tighter wells.

Tile audio is presentation-only: an airy 220 ms swoosh starts when a tile begins its tray transfer (including flipped matches and heart-loss arrival), and a short ceramic clack plays at the shared pair impact/pop, including assisted collisions. Two reusable AudioStreamPlayers allow four overlapping voices each. Inspector stream and volume properties are replaceable; the existing Sound toggle mutes them. Original PCM assets are reproducible with `python scripts/tools/generate_tile_audio.py` and use no gameplay RNG.

Portrait spacing now uses a `0.90` horizontal stride and `0.92` minimum vertical stride to balance the upright ceramic footprint. Height fitting may relax rows up to `1.0`; the same horizontal stride is used for both fit calculations and tile positions. These Inspector-controlled presentation values supersede the earlier `0.74` row compression and preserve authored slot identities and simulation geometry. Landscape tuning is unchanged.

The travel swoosh defaults to -22 dB (6 dB quieter). A separate 100 ms brush/tick flip sound defaults to -25 dB, playing at the Board flip midpoint or the start of an already edge-on auto-match reveal. It shares the Sound preference and has Inspector stream/volume overrides.

A previously revealed flipped tile with a held mate can resolve through `PAIR_RESOLVED` (for example after rules-20 automatic cleanup). The direct-match presentation accepts both ordinary and flipped pair results, routing either through tray arrival, collision, and the shared impact/audio event rather than freeing the captured previews. Regression: `tests/tray_pair_presentation_runner.gd`.
