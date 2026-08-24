# Figma Portrait Gameplay UI

Status: M7 first implementation pass

The portrait gameplay HUD follows the Figma frame `gameplay-portrait-components-v1` (`68:2`) in file `smmQPlegRvV6ZVGzD5Ea6y`. Figma remains the visual source of truth for this slice; Godot owns responsive layout, runtime values, clipping, interaction, and gameplay presentation.

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

Runtime exports include the gameplay background, HUD top scrim, score box, Momentum frame/fill/badge, pause button, and the composable bottom action dock. The background intentionally retains its `941 x 1672` master dimensions because its `48 px` scale-9 margins are authored in that source coordinate space. The `390 x 167` HUD top scrim is the exact Figma vector: a dark top-to-transparent fade that scales to the full portrait viewport width. The supplied composable queue artwork lives under `assets/UI/tile-queue/`; `queue-cap.png` is mirrored for the right edge and `queue-repeat.png` owns each complete empty-slot presentation. Older imported queue references under `game-assets/ui/portrait/` are not wired into the shell. The live tray must render the same tile instances as the Board. The portrait action dock uses separately exported background, ceramic cap, icon, and quantity-plaque artwork so interaction and inventory values remain live.

Mila Script Sans Regular and Bold TTF files live under `assets/fonts/`. Godot uses Regular for values and Bold for headings, multiplier emphasis, and tick labels. WOFF2 files are retained alongside the supplied artwork package but are not loaded at runtime. No font license document was supplied with these files; redistribution rights must be confirmed before a public release.

## Static And Dynamic Composition

Static exported artwork:

- background;
- HUD top scrim;
- score-box shell;
- Momentum frame, fill texture, and multiplier badge;
- pause button;
- queue caps and repeatable slot section.

Runtime UI:

- score heading, value, and elapsed timer;
- Combo/Streak readout;
- Momentum fill width and visible decay;
- seven multiplier upgrade ticks (`x2` through `x8`) and the current multiplier; `x1` remains the unlabeled default;
- live tray tiles and modifiers;
- pause interaction.
- Hint, Shuffle, Delete, and Undo touch targets and inventory quantities.

The Momentum fill is clipped inside the exported frame and scales horizontally from simulation state. The queue is assembled from a left cap, one repeated section per active capacity, and a mirrored right cap. Cap and repeat exports share a `115 px` source height and render on the same top/bottom edges. Adjacent artwork overlaps by one source pixel while retaining its authored horizontal stride; this prevents bilinear filtering from exposing each transparent crop boundary as a dark vertical seam. The exported repeat artwork owns the complete empty-slot appearance; Godot slot controls remain transparent positioning and animation targets until they contain a live Board tile. The queue supports capacities from two through six while the reference game remains at four.

## Responsive Contract

Portrait layout is resolved inside the safe-area content rectangle:

1. The `941 x 1672` Figma background uses scale-9 rendering with fixed `48 px` source margins on every edge. Only its interior and edge spans stretch, preserving the gold corner treatment while the same artwork temporarily serves every portrait and landscape aspect ratio.
2. Score, Momentum, and pause anchor to the safe-area top.
3. The queue is centered below the HUD.
4. The existing Board consumes the flexible middle region.
5. The portrait action dock recreates `bottom-menu-live` (`80:30`) above the bottom safe area. Its background stretches horizontally through the documented nine-patch, while four transparent touch targets compose the exported ceramic caps, icons, live quantity plaques, and Mila labels in Hint, Shuffle, Delete, Undo order.

Live tray tiles are centered on the logical center of each repeated queue section. The Board may overlap the queue control's transparent lower source padding, but never its visible frame or tile targets. Similarly, the action-dock control extends into its transparent bottom padding so the visible gold frame sits against the bottom safe-area edge while all touch targets remain inside that edge.

The portrait bottom action bar uses the `2172 x 724` supplied master as a horizontally stretching nine-patch. Left and right patches are `30%` of source width (`652 px` each after rounding); top and bottom patches are `50%` of source height (`362 px` each). The complete node scales uniformly to the runtime dock height, so there is no vertical stretch, and only the horizontal center span expands to fill the available width.

The portrait HUD, margins, queue allocation, and bottom drawer scale from the `390 x 844` reference composition. Scale uses the smaller ratio of safe display width to reference width and safe display height to reference height, so the complete HUD grows on high-resolution displays without overflowing shorter or wider portrait devices. The score remains left-aligned, pause remains right-aligned, and the Momentum frame is positioned independently so its center always matches the safe display's horizontal center. Portrait hides the prototype Board title/status header and uses compact internal margins so the flexible middle region is available to tile layout rather than placeholder chrome. It does not rotate or rearrange the portrait-authored board. Landscape keeps the established split-side shell while temporarily sharing the scale-9 Figma background until separate landscape artwork is approved.

## First-Pass Gaps

- Board tile artwork remains the current gameplay placeholder by design.
- The Figma frame contains no heart artwork, so this pass does not invent or approximate hearts.
- Final spacing and scale still require on-device screenshot comparison against the Figma frame.
