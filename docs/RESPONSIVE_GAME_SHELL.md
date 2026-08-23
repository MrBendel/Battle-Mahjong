# Responsive Game Shell

The mobile/console-oriented shell follows two presentation compositions around the same portrait-authored board. Orientation may reposition HUD and action regions and select an orientation-specific cosmetic tile geometry, but it never rotates, transposes, or rearranges stable board slots.

## Portrait

Portrait uses a strict vertical priority stack:

1. Score, Momentum, multiplier, and Combo status.
2. Four-slot tray.
3. The largest possible uninterrupted Board region.
4. A bottom action dock ordered Hint, Delete Pair, Shuffle, Undo.

The pause control stays in the upper-right safe area. The action dock uses one horizontal row of large touch targets. Decorative Character/FX and the debug panel are hidden by default so they cannot reduce the Board footprint. The debug panel remains available through the `show_debug_panel` Inspector property. The Tray reserves the full rendered tile and ink-outline height before the Board is placed; the Board yields vertical space when necessary so their rendered children cannot overlap.

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

Board tiles, tray tiles, Momentum, score, pause, and consumable actions remain readable and operable. Tray tiles continue to use the Board's rendered tile footprint.

On mobile application pause or focus loss, the shell pauses gameplay without changing authoritative game state. Foreground recovery cancels stale touch and emulated-mouse presses, refreshes interactive presentation controls, and leaves the pause menu open until the player explicitly resumes. This prevents a touch release lost during Android suspension from leaving later taps partially unresponsive.

## Input Boundary

This composition improves thumb reach and spatial predictability for mobile and future controller navigation. It does not itself implement gamepad tile navigation, focus graphs, or console platform integration; those remain separate input work.
