# Board Layout Authoring

Battle Mahjong uses the same normalized board-layout model for hand-authored and procedurally generated geometry.

## Orientation Contract

Production board layouts are authored portrait-first because phone portrait is the primary gameplay format. Layout coordinates are authoritative gameplay data and do not change with the viewport.

- Portrait and landscape render the same slots in the same relative positions.
- Landscape may rearrange the tray, momentum, consumables, character, and decorative regions around the board.
- The board may scale uniformly to fit its allocated region, but it must not rotate, transpose, stretch, or reflow its slots.
- New authored and generated production layouts should have a portrait footprint unless a later design decision explicitly introduces another layout class.

This keeps slot IDs, selectability, transactions, solution certificates, and replays identical across orientations. Presentation is responsible for fitting the portrait board into the available shell.

## Coordinate Model

- Each tile occupies `2x2` integer grid units.
- `x` and `y` may be odd, representing half-tile offsets.
- `z` is a non-negative layer index.
- Tiles on the same layer may touch but may not overlap.
- Higher-layer footprint overlap blocks lower tiles.

Runtime layouts contain stable slots:

```text
LayoutSlot
  slot_id
  x
  y
  z
```

Coordinate-derived IDs such as `z2_x5_y8` remain stable when source rows are reordered. Layouts also carry a positive revision and a canonical content hash. Game definitions record the layout ID, revision, and hash.

## Authored Layouts

Authored assets live in `configuration/layouts/`. The catalog discovers all `.json` files in that directory automatically.

The compact format groups coordinates by layer and row:

```json
{
  "schema_version": 1,
  "layout_id": "example_12",
  "revision": 1,
  "metadata": {
    "source": "authored"
  },
  "layers": [
    {
      "z": 0,
      "rows": [
        {"y": 0, "x": [0, 2, 4, 6]},
        {"y": 2, "x": [0, 2, 4, 6]}
      ]
    },
    {
      "z": 1,
      "rows": [
        {"y": 1, "x": [1, 5]},
        {"y": 3, "x": [1, 5]}
      ]
    }
  ]
}
```

Increment `revision` whenever published geometry changes. Row ordering does not affect slot identity or the layout hash.

## Procedural Requirements

Requirements profiles live in `configuration/layout_requirements/` and describe constraints rather than individual slots:

```json
{
  "schema_version": 1,
  "requirements_id": "generated_portrait_diamond_96",
  "revision": 1,
  "tile_count": 96,
  "columns": 6,
  "rows": 7,
  "layer_counts": [42, 30, 18, 6],
  "shape": "diamond",
  "horizontal_symmetry": true,
  "require_support": true
}
```

Supported shape families:

- `rectangle`: favors concentric rectangular bands.
- `ellipse`: favors rounded silhouettes.
- `diamond`: favors diagonal tapering.

## Art-Directed Motifs

New requirements profiles may add seeded choices for each layer:

```json
"layer_motif_choices": [
  ["solid", "hourglass"],
  ["wings", "hourglass"],
  ["bridge", "tower"],
  ["tower"]
]
```

The generator chooses one motif per layer from the seeded RNG, then combines that motif's placement score with the broad silhouette score. Available motifs are:

- `solid`: keeps the underlying rectangle, ellipse, or diamond preference.
- `wings`: favors separated outer structures.
- `bridge`: favors a strong horizontal connecting band.
- `tower`: favors a compact central stack.
- `hourglass`: favors width near the ends and a narrower middle.

Motifs guide candidate selection; they do not bypass support, symmetry, overlap, layout validation, or the solver gate.

`progressive_layer_inset` controls the candidate footprint across depth. The default `true` preserves the classic taper where each layer loses one row and column. Setting it to `false` alternates full and half-tile-inset footprints, allowing upper layers to spread back across the authored width. The production mobile generator uses this staggered mode so its `6x7` boards do not always collapse into the same narrow tower.

## Mobile-Fit Gate

A procedural profile may include `mobile_constraints`. The current analyzer can reject candidates based on:

- maximum footprint width-to-height ratio,
- minimum and maximum initially selectable tiles,
- maximum layer count,
- minimum estimated tile width in a reference Board region,
- minimum row-width variation,
- minimum widest-row tile count,
- required partial overlap.

Generated layout metadata records the chosen layer motifs and measured mobile-fit values. The foundation example is `configuration/layout_requirements/portrait_arcade_96.json`.

## On-Device Playtesting

Internal gameplay builds open the responsive `BUILD A BOARD` panel before modifier selection. The `-` and `+` controls regenerate adjacent seeds, `ROLL SEED` advances deterministically to a distant seed, and the numeric seed field accepts a specific value. The generated geometry previews in the live Board region with its chosen motifs and mobile-fit summary.

`USE THIS BOARD` carries the in-memory layout into modifier selection and the normal game-definition factory. Restart returns to Board generation with the previous seed retained. Generated layouts therefore remain reproducible without writing files on the device.

Procedural deals randomize which currently selectable slots form each certified pair before assigning tile identities. The generated geometry may remain art-directed and horizontally balanced, but matching faces do not inherit the planner's coordinate ordering or mirror symmetry. Authored reference layouts retain their established deal behavior unless this option is requested explicitly.

Each successive layer uses an inset candidate grid. When support is required, every generated upper slot must overlap at least one slot on the immediately lower layer. Horizontal symmetry is applied to complete slot groups rather than repaired after generation.

## Generate A Layout

From the repository root:

```powershell
& "C:\path\to\Godot_console.exe" --headless --path . `
  --script res://scripts/tools/generate_layout.gd -- `
  res://configuration/layout_requirements/portrait_diamond_96.json `
  4242 `
  res://configuration/layouts/generated_portrait_diamond_96.json `
  tower_diamond_seed_4242
```

Omit the output argument to print normalized JSON to standard output. The final layout-ID argument is optional; provide it when multiple seeds from one requirements profile need to coexist in the layout catalog. Tower generation assigns deterministic seed-derived layout IDs automatically.

Generation is deterministic for an exact requirements profile and seed. A result is emitted only when it:

- satisfies the requested tile and layer counts,
- satisfies symmetry and immediate support requirements,
- passes normal layout validation,
- has a complete legal pair-removal plan.

The generated file uses expanded stable slots and can be edited, reviewed, or promoted like any authored layout.

To preview an asset, select the root `Main` node in `scenes/main.tscn` and set its exported `layout_id` to the asset's `layout_id`. The shell falls back to the default layout if the selected asset is missing or invalid.

## Current Limits

- Shapes and motifs are scoring families, not arbitrary image masks or natural-language prompts.
- Generation does not yet target measured human difficulty or tray pressure.
- The solver gate proves a pair-only route; it does not require temporary unmatched tray holdings.
- Support currently means overlap with at least one immediate-lower tile, not a physical center-of-mass simulation.

Deterministic batch generation and provisional difficulty ranking for the future endless Tower mode are documented in [Tower Generation And Difficulty Tooling](TOWER_GENERATION.md).
