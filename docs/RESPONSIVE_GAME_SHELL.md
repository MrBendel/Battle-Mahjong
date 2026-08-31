# Responsive Game Shell

The mobile/console-oriented shell follows two presentation compositions around the same portrait-authored board. Orientation may reposition HUD and action regions and select an orientation-specific cosmetic tile geometry, but it never rotates, transposes, or rearranges stable board slots.

## Portrait

Portrait uses the M7 Figma HUD documented in [Figma Portrait Gameplay UI](FIGMA_PORTRAIT_UI.md) and a strict vertical priority stack:

1. Score, Momentum, multiplier, and Combo status.
2. Two-to-six-slot tray (four slots in normal gameplay).
3. The largest possible uninterrupted Board region.
4. A bottom action dock ordered Hint, Delete Pair, Shuffle, Undo.

The aspect-covered Figma background may crop laterally but never stretches. Score and Momentum use exported frames with runtime Mila Script Sans text; the Momentum fill remains clipped and animated from live state. The pause control stays square in the upper-right safe area. The queue is centered and composed from exported caps plus one repeatable section for each of two through six live tray slots.

The action dock uses one horizontal row of large touch targets. Decorative Character/FX and the debug panel are hidden by default so they cannot reduce the Board footprint. The debug panel remains available through the `show_debug_panel` Inspector property. The Tray derives a scaled tile footprint from the Board through the shell's `tray_tile_scale` Inspector property, then reserves the corresponding rendered tile, ink outline, and queue-art height before the Board is placed. The Board yields vertical space when necessary so their rendered children cannot overlap.

On compact phones below `800` logical pixels tall, the redundant Board title and tile-count header collapse before the tile field shrinks. This keeps the tall ceramic tiles above their `32 x 48` presentation minimum.

## Landscape

Landscape reserves a top HUD row and two side action rails:

- Score and Momentum occupy the upper-left.
- The tray is centered over the Board and reserves the full rendered wide-tile height before the Board begins.
- Pause occupies the upper-right safe area.
- The portrait-authored Board remains centered and consumes the middle playfield, using the Default skin's wide ceramic base without changing slot IDs or layer order.
- Hint and Delete Pair occupy the lower-left rail.
- Shuffle and Undo occupy the lower-right rail.

Consumables are managed by one transparent overlay whose visible buttons remain completely outside the Board. Each landscape action preserves at least a `120 x 54` logical-pixel target in the validated reference viewport.

## Responsive Priorities

Safe-area insets are applied before margins and region allocation. When space becomes constrained, presentation yields in this order:

1. Decorative Character/FX.
2. Debug information.
3. Nonessential region labels and notices.

Board tiles, tray tiles, Momentum, score, pause, and consumable actions remain readable and operable. Tray tiles preserve the active orientation geometry while scaling uniformly from the Board footprint; transfer previews animate into that smaller target using the shell's `tile_transfer_seconds` presentation setting. When resolving a held tile compacts later tray entries, presentation previews preserve their old positions through the pair collision and then slide left over `tray_compaction_seconds`; authoritative tray order still updates immediately.

All new presentation elements must define an authored reference size and derive runtime dimensions from `scripts/presentation/presentation_scale.gd`. Full-screen HUD, overlays, and FX use the limiting safe-display scale after insets; Board-local callouts use the limiting scale of the Board region. Do not introduce fixed pixel sizes for runtime artwork, particle travel, font sizes, outlines, or animation offsets without multiplying them by the appropriate presentation scale. Match collision FX use the shared safe-display scale plus the Inspector-tunable `match_fx_scale_multiplier`, which defaults to `1.30`; their particle count and lifetime remain constant for predictable mobile cost.

On mobile application pause or focus loss, the shell pauses gameplay without changing authoritative game state. Foreground recovery cancels stale touch and emulated-mouse presses, refreshes interactive presentation controls, and leaves the pause menu open until the player explicitly resumes. This prevents a touch release lost during Android suspension from leaving later taps partially unresponsive.

Pause and Game Over share the reusable `GameOverlay` presentation template. The wash, framed panel, safe-area placement, typography, spacing, borders, and command targets use the same limiting safe-display scale as the portrait HUD and remain centered in either orientation. Game Over supplies result-specific title, statistics, and actions without owning a second fixed-size layout. Pause toggles use scalable full-row ON/OFF treatments instead of Godot's fixed-size CheckButton indicator artwork. Sound and haptics are session settings in M7 and default on; durable preference storage remains deferred to M9. Tile selection uses a short light haptic, while pair resolution and assisted pair deletion use a longer, stronger profile. These feedback values are presentation tuning exposed on the game shell and never enter deterministic game state or replay transactions.

Successful Shuffle transactions use a short presentation lock. Every active tile visibly settles from its old slot into the committed deterministic slot mapping with a slight overshoot. Face-up tiles remain visible and face-down tiles remain face-down throughout the move. One native parallel Tween owns the position tracks; Shuffle does not run full-Board flip phases or per-frame GDScript interpolation. The Inspector-tunable movement duration does not alter the Shuffle transaction or replay timeline.

Board tiles overlap visually, so their scene-tree sibling order must follow the current presentation stack after Shuffle or any slot remap. Godot does not use `CanvasItem.z_index` alone to choose which overlapping `Control` receives pointer input; stale sibling order can allow a lower tile to intercept a top tile's touch target.

## Input Boundary

This composition improves thumb reach and spatial predictability for mobile and future controller navigation. It does not itself implement gamepad tile navigation, focus graphs, or console platform integration; those remain separate input work.
