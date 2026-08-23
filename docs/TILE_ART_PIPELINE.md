# Tile Art Pipeline

Status: M7 Batch A complete Default face candidate set

This document defines the first implemented tile-art contract. It separates gameplay identity, cosmetic presentation, source masters, and runtime exports.

## Vocabulary

The initial production skin guarantees the 34 traditional identities:

- Bamboo `1-9`;
- Dots `1-9`;
- Characters `1-9`;
- East, South, West, and North;
- Red, Green, and White Dragons.

Thirty-four is a required baseline, not a schema maximum. A later rules decision may add flowers, seasons, or Battle Mahjong-specific identities. New identities must receive stable logical IDs and an entry in every compatible skin. Cosmetic skins never change matching behavior.

The current 96-tile reference game still uses 24 abstract identities with four copies each. `game-assets/tiles/default/skin.json` contains an explicit presentation-only map from those identities to a 24-face preview subset. This does not alter simulation identity, deal composition, matching, state hashes, or replay behavior.

## Geometry

The Default skin now provides two orientation-specific ceramic base geometries. Both preserve the same tile identity, stable authored slot, modifier attachment role, and face-art layer; only presentation dimensions and normalized face placement change when the responsive shell changes orientation.

Legacy canonical face geometry:

| Contract | Pixels |
| --- | --- |
| Full source tile | `512 x 640` |
| Runtime reference tile | `256 x 320` |
| Face-art safe area | `x=92, y=104, w=328, h=400` |
| Modifier bounds | `x=384, y=32, w=96, h=96` |
| Runtime atlas padding | `8` |
| Minimum validated runtime footprint | `32 x 40` |

Orientation base geometry:

| Variant | Source | Runtime | Face safe area | Minimum footprint |
| --- | --- | --- | --- | --- |
| Portrait | `1024 x 1536` | `512 x 768` | `x=152, y=190, w=720, h=1050` | `32 x 48` |
| Landscape | `1536 x 1024` | `768 x 512` | `x=250, y=100, w=1036, h=740` | `48 x 32` |

Coordinates are recorded in each source tile's pixel space and scaled proportionally at runtime. Changing orientation does not rotate, reorder, transpose, or replace layout slot identifiers and does not affect simulation coverage or matching.

Tile composition remains:

```text
Tile Base
+ Tile Face
+ Modifier Overlay
+ Interaction State
+ FX
```

The current Godot proof renders the responsive ceramic base as a texture, places imported face art inside the safe area, and places modifier text in the independent modifier bounds.

### Authored Depth Presentation

The Default skin's `depth_presentation` manifest section controls board-stack lighting. The renderer maps the lowest authored `z` layer to `lowest_layer_brightness`, interpolates each higher layer toward full brightness, and projects an offset copy of the active tile-base silhouette beneath every tile. This keeps physical stack depth readable in both orientations without changing layout geometry or simulation state.

Blocked state is a separate cool translucent silhouette veil applied after the warm depth lighting. Covered tiles retain authored-layer shading and cast shadows, but a tile becomes canonical full brightness as soon as it is selectable or otherwise visually active. This prevents depth from being mistaken for availability. Tray tiles and moving previews remain fully lit because they are no longer being read as part of the board stack. Face-down tiles render the blank ceramic base without a question mark or rectangular placeholder.

The skin's `layout_presentation.adjacent_gap_ratio` controls spacing between immediately adjacent authored slots as a fraction of the active tile footprint. Zero makes control bounds touch; a small negative value compensates for transparent padding in base artwork. The Default skin uses `-0.06` so the visible ceramic edges meet in portrait and landscape. This setting is cosmetic and does not change authored positions, overlap rules, selectability, or replay data.

The same section defines a dark warm manga-ink silhouette using `ink_outline_color`, `ink_outline_expansion_ratio`, and `ink_outline_offset_ratio`. Presentation derives the silhouette from the active ceramic base, expands it slightly and asymmetrically, then renders it behind board, tray, and moving-preview tiles. It is not a rectangular control border and follows each orientation's alpha contour.

## Source And Runtime Assets

Editable masters live under `art-source/tiles/<skin>/`. Godot runtime exports live under `game-assets/tiles/<skin>/`.

Rules:

- SVG remains the canonical source format for flat face artwork. The first orientation-specific ceramic bases are transparent raster masters derived from the supplied artwork and live under `art-source/tiles/default/bases/`.
- Runtime tile assets are transparent sRGB PNG files at 50% source scale.
- Alpha is straight, not premultiplied.
- File names are stable logical face IDs such as `bamboo_1.svg` and `red_dragon.svg`.
- Runtime PNG files are generated outputs and must not be edited directly. The tile exporter downsamples raster base masters alongside SVG face masters.
- Run `godot --headless --path . --script res://scripts/tools/generate_default_tile_faces.gd` to regenerate the brush-arcade Default SVG candidate set.
- Run `godot --headless --path . --script res://scripts/tools/export_tile_art.gd` after changing tile SVG masters.
- Run `godot --headless --editor --path . --quit` after export on a fresh checkout so Godot imports every runtime PNG before headless tests.
- Small vector masters and runtime exports remain in Git. Large character, background, audio, and layered-painting storage remains an M7 production decision.

The proof uses individual PNG files so framing and import behavior are easy to inspect. Build atlases after the complete Default face set exists; do not make atlas coordinates part of gameplay identity.

## Skin Manifest

Each skin owns a versioned `skin.json` containing skin identity, geometry, guaranteed canonical face IDs, face labels and optional runtime asset paths, and any temporary compatibility mappings.

The loader requires the initial 34 IDs but does not reject additional face definitions. This allows the vocabulary to grow without changing the renderer contract.

Missing face art intentionally falls back to live text during production. A skin is not production-complete until every identity used by a game definition has artwork and both text fallback and placeholder mappings are disabled for release.

## Current Default Assets

The Default candidate set contains all 34 Bamboo, Dots, Characters, Winds, and Dragons as editable SVG masters and runtime PNG exports. The treatment preserves familiar family and count structure while using heavy rounded strokes, loose registration, bright arcade color, and brush accents.

The board and tray consume the same skin manifest and active orientation variant. Portrait viewports use the tall ceramic base; landscape viewports use the wide ceramic base. Animation previews capture the same active base, and orientation changes remain presentation-only. Blocked tiles are darkened without changing their face asset. A blocked tap produces a short horizontal rejection motion and generated negative tone without submitting a gameplay command. Successful ordinary selections commit immediately, then animate a presentation-only duplicate into the next tray slot. A committed pair converges on the matching tray slot and composes the reusable `PairMatchFx` burst; Delete Pair composes the same removal primitive over its resolved board tiles.

These are production candidates with replaceable masters, not final approval of every glyph. Gameplay still uses the existing 24 abstract identities through the presentation-only map.

## Validation

Automated checks cover all 34 required IDs and runtime assets, uniqueness, canonical honor naming, all 24 temporary mappings, geometry values, independent face/modifier layers, board-to-tray motion targeting, blocked-tap isolation, transaction-gated pair feedback, shared Delete Pair removal feedback, responsive background coverage, and board containment in landscape, phone portrait, and `375 x 667` compact portrait.

The compact-phone board currently holds the portrait variant at approximately `32 x 50` after yielding its nonessential Board header. The reference landscape viewport renders the wide variant at approximately `103 x 67`. Continued visual review at each variant's declared minimum remains required for Default refinements and every Neon face before M7 can be considered done.

## Gameplay Background

The first gameplay-background source master lives at `art-source/backgrounds/gameplay_brush_arcade.png`; its generation prompt and export contract live beside it. The downsampled runtime export lives at `game-assets/backgrounds/gameplay_brush_arcade.png`.

Presentation uses an aspect-covered center crop plus a subtle dark wash. The center remains low-noise beneath the board while the outer brushwork can crop aggressively or disappear on compact viewports. Background imagery is cosmetic and has no simulation dependency.
