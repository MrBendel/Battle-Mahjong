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

Runtime exports include the gameplay background, score box, Momentum frame/fill/badge, and pause button. The supplied composable queue artwork lives under `assets/UI/tile-queue/`; `queue-cap.png` is mirrored for the right edge and `queue-repeat.png` owns each complete empty-slot presentation. Older imported queue references under `game-assets/ui/portrait/` are not wired into the shell. The live tray must render the same tile instances as the Board, and the consumable drawer intentionally retains its current placeholders.

Mila Script Sans Regular and Bold TTF files live under `assets/fonts/`. Godot uses Regular for values and Bold for headings, multiplier emphasis, and tick labels. WOFF2 files are retained alongside the supplied artwork package but are not loaded at runtime. No font license document was supplied with these files; redistribution rights must be confirmed before a public release.

## Static And Dynamic Composition

Static exported artwork:

- background;
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

The Momentum fill is clipped inside the exported frame and scales horizontally from simulation state. The queue is assembled from a left cap, one repeated section per active capacity, and a mirrored right cap. The exported repeat artwork owns the complete empty-slot appearance; Godot slot controls remain transparent positioning and animation targets until they contain a live Board tile. The queue supports capacities from two through six while the reference game remains at four.

## Responsive Contract

Portrait layout is resolved inside the safe-area content rectangle:

1. The Figma background aspect-covers the viewport and may crop at the sides.
2. Score, Momentum, and pause anchor to the safe-area top.
3. The queue is centered below the HUD.
4. The existing Board consumes the flexible middle region.
5. The existing compact consumables drawer stays above the bottom safe area.

The portrait HUD, margins, queue allocation, and bottom drawer scale from the `390 x 844` reference composition. Scale uses the smaller ratio of safe display width to reference width and safe display height to reference height, so the complete HUD grows on high-resolution displays without overflowing shorter or wider portrait devices. The score remains left-aligned, pause remains right-aligned, and the Momentum frame is positioned independently so its center always matches the safe display's horizontal center. It does not rotate or rearrange the portrait-authored board. Landscape keeps the established split-side shell until a separate landscape visual source is approved.

## First-Pass Gaps

- Board tile artwork and the consumable drawer remain the current gameplay placeholders by design.
- The Figma frame contains no heart artwork, so this pass does not invent or approximate hearts.
- Final spacing and scale still require on-device screenshot comparison against the Figma frame.
