# Figma Portrait Gameplay UI

Status: M7 first implementation pass

The portrait gameplay HUD follows the Figma frame `gameplay-portrait-components-v1` (`68:2`) in file `smmQPlegRvV6ZVGzD5Ea6y`. Figma remains the visual source of truth for this slice; Godot owns responsive layout, runtime values, clipping, interaction, and gameplay presentation.

The exported pieces are resolved through `configuration/default_gameplay_theme.tres`, which is shared by portrait and landscape. Components must not load alternate full-screen composites for orientation changes. A future seasonal theme can replace the background, HUD shell, tray, controls, fonts, or tile-skin manifest independently and inherit unchanged pieces from the default theme contract.

## Asset Boundary

Full-resolution component exports and the reference-frame capture live under:

```text
art-source/ui/portrait/
```

Optimized Godot runtime exports generally live under:

```text
game-assets/ui/portrait/
```

The approved `bottom-menu-live` runtime package lives under `assets/UI/bottom-bar/`. Use those transparent crops directly; do not regenerate icon crops from the combined Figma image during import.

Runtime exports include the gameplay background, HUD top scrim, score box, Momentum frame/fill/badge, pause button, and the composable bottom action dock. The background intentionally retains its `941 x 1672` master dimensions because its `48 px` scale-9 margins are authored in that source coordinate space. The `390 x 167` HUD top scrim is the exact Figma vector: a dark top-to-transparent fade that scales to the full portrait viewport width.

The portrait tray is assembled from an authored porcelain left end containing the first recessed well, a repeatable complete middle well, and a right end containing the final well under `game-assets/ui/tray/porcelain/`. A tray renders `capacity - 2` middle wells, supporting two through six slots without stretching a fixed four-slot bitmap or cutting through the curved outer transitions. Godot slot controls remain transparent and provide only tile/animation geometry. The untouched source composition lives at `art-source/inspiration/tiles/tile-tray.png`; run `godot --headless --path . --script res://scripts/tools/slice_porcelain_tray.gd` to regenerate source and runtime slices. Landscape retains its dedicated vertical tray artwork. The live tray must render the same tile instances as the Board.

The consumables dock is independently composable. It uses dark left and right end caps around one repeat section per visible consumable, so its width follows the action count instead of assuming four items. The end spacing is symmetrical and intentionally compact. Each action composes a replaceable ceramic tile, icon, and live count anchored to the tile's lower-right. Inventory quantity also controls a presentation-only stack: one remaining item shows one tile, two show two tiles, and three or more show three. Additional tiles move only upward, with no horizontal drift, and each layer rises by the visible ceramic base thickness scaled from the tile footprint. Separate responsive shadows ground the back tray and each ceramic stack. Zero retains a dim disabled tile so controls do not move as inventory is spent. Sources live under `art-source/inspiration/consumables/`; derived masters and optimized runtime pieces live under `art-source/ui/consumables/` and `game-assets/ui/consumables/`. Run `godot --headless --path . --script res://scripts/tools/slice_consumables_art.gd` to regenerate them.

Mila Script Sans Regular and Bold TTF files live under `assets/fonts/`. Shared `FontVariation` resources apply `-2 px` glyph spacing without modifying the supplied fonts. Godot uses Regular for values and Bold for headings, multiplier emphasis, tick labels, and action labels. WOFF2 files are retained alongside the supplied artwork package but are not loaded at runtime. No font license document was supplied with these files; redistribution rights must be confirmed before a public release.

## Static And Dynamic Composition

Static exported artwork:

- background;
- HUD top scrim;
- score-box shell;
- Momentum frame, fill texture, and multiplier badge;
- pause button;
- queue end wells and repeatable middle-well section.

Runtime UI:

- score heading, value, and elapsed timer;
- Combo/Streak readout;
- Momentum fill width and visible decay;
- seven multiplier upgrade ticks (`x2` through `x8`) and the current multiplier; `x1` remains the unlabeled default;
- live tray tiles and modifiers;
- pause interaction.
- Hint, Shuffle, Delete, and Undo touch targets and inventory quantities.

The Momentum fill is clipped inside the exported frame and scales horizontally from simulation state. The queue is assembled from left and right end sections that each own one complete well, with one middle section for every additional slot. All three exports share the same source height and render on the same top/bottom edges. Adjacent artwork overlaps slightly while retaining its authored horizontal stride; this prevents bilinear filtering from exposing each transparent crop boundary as a dark vertical seam. The exported pieces own the complete empty-slot appearance; Godot slot controls remain transparent positioning and animation targets until they contain a live Board tile. The queue supports capacities from two through six while the reference game remains at four.

## Responsive Contract

Portrait layout is resolved inside the safe-area content rectangle:

1. The `941 x 1672` Figma background uses scale-9 rendering with fixed `48 px` source margins on every edge. Only its interior and edge spans stretch, preserving the gold corner treatment while the same artwork temporarily serves every portrait and landscape aspect ratio.
2. Score, Momentum, and pause anchor to the safe-area top.
3. The queue is centered below the HUD.
4. The existing Board consumes the flexible middle region.
5. The portrait action dock sits above the bottom safe area. Independent end caps surround one background repeat and one transparent touch target per action. Each target composes the ceramic inventory stack, icon, and live lower-right quantity in Hint, Shuffle, Delete, Undo order.

Live tray tiles use the logical center of each repeated queue section with a slight approved left optical correction. The current inspiration pass replaces the ornate queue and bottom-bar presentation with shared warm-ivory ceramic pieces under `game-assets/ui/shared/`. The Board never overlaps tray tiles or consumable touch targets.

The portrait bottom action bar uses the `2172 x 724` supplied master as a horizontally stretching nine-patch. Left and right patches are `30%` of source width (`652 px` each after rounding); top and bottom patches are `50%` of source height (`362 px` each). The complete node scales uniformly to the runtime dock height, so there is no vertical stretch, and only the horizontal center span expands to fill the available width.

The portrait HUD, margins, queue allocation, and bottom actions scale from the `390 x 844` reference composition. Scale uses the smaller ratio of safe display width to reference width and safe display height to reference height, so the complete HUD grows on high-resolution displays without overflowing shorter or wider portrait devices. The status panel follows the approved `613 x 155` internal scorebox grid: hearts, score, and streak across the upper row, with Momentum and multiplier below. Pause remains independently anchored at the upper right. Portrait hides the prototype Board title/status header and uses compact internal margins. It does not rotate or rearrange the portrait-authored board. Landscape shares the compact status panel, ceramic action tiles, and background, while reorienting the tray vertically and stacking actions at lower left.

The scorebox is assembled from reusable themed layers rather than baked runtime values: a dark framed panel, three live heart positions, Battle Mahjong Poster Script for every scorebox label and value, an eight-stage clipped Momentum fill, and a separate flame icon. The eight stages represent the default state plus the seven multiplier thresholds; the displayed score, heart count, streak, multiplier, and fill remain live UI state.

## First-Pass Gaps

- Board tile artwork remains the current gameplay placeholder by design.
- The Figma frame contains no heart artwork, so this pass does not invent or approximate hearts.
- Final spacing and scale still require on-device screenshot comparison against the Figma frame.
