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

Each successive layer uses an inset candidate grid. When support is required, every generated upper slot must overlap at least one slot on the immediately lower layer. Horizontal symmetry is applied to complete slot groups rather than repaired after generation.

## Generate A Layout

From the repository root:

```powershell
& "C:\path\to\Godot_console.exe" --headless --path . `
  --script res://scripts/tools/generate_layout.gd -- `
  res://configuration/layout_requirements/portrait_diamond_96.json `
  4242 `
  res://configuration/layouts/generated_portrait_diamond_96.json
```

Omit the output argument to print normalized JSON to standard output.

Generation is deterministic for an exact requirements profile and seed. A result is emitted only when it:

- satisfies the requested tile and layer counts,
- satisfies symmetry and immediate support requirements,
- passes normal layout validation,
- has a complete legal pair-removal plan.

The generated file uses expanded stable slots and can be edited, reviewed, or promoted like any authored layout.

To preview an asset, select the root `Main` node in `scenes/main.tscn` and set its exported `layout_id` to the asset's `layout_id`. The shell falls back to the default layout if the selected asset is missing or invalid.

## Current Limits

- Shapes are broad scoring families, not arbitrary image masks or natural-language prompts.
- Generation does not yet target measured human difficulty or tray pressure.
- The solver gate proves a pair-only route; it does not require temporary unmatched tray holdings.
- Support currently means overlap with at least one immediate-lower tile, not a physical center-of-mass simulation.
