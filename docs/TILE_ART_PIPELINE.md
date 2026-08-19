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

Canonical source geometry:

| Contract | Pixels |
| --- | --- |
| Full source tile | `512 x 640` |
| Runtime reference tile | `256 x 320` |
| Face-art safe area | `x=92, y=104, w=328, h=400` |
| Modifier bounds | `x=384, y=32, w=96, h=96` |
| Runtime atlas padding | `8` |
| Minimum validated runtime footprint | `32 x 40` |

Coordinates are recorded in source-tile space. Presentation scales them proportionally, so the same contract applies to portrait and landscape layouts.

Tile composition remains:

```text
Tile Base
+ Tile Face
+ Modifier Overlay
+ Interaction State
+ FX
```

The current Godot proof renders the responsive ceramic base with a `StyleBoxFlat`, places imported face art inside the safe area, and places modifier text in the independent modifier bounds. `tile_base.png` is the visual reference for later nine-patch or shader production.

## Source And Runtime Assets

Editable masters live under `art-source/tiles/<skin>/`. Godot runtime exports live under `game-assets/tiles/<skin>/`.

Rules:

- SVG is the canonical source format for tile bases and flat face artwork in this proof.
- Runtime tile assets are transparent sRGB PNG files at 50% source scale.
- Alpha is straight, not premultiplied.
- File names are stable logical face IDs such as `bamboo_1.svg` and `red_dragon.svg`.
- Runtime PNG files are generated outputs and must not be edited directly.
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

The board and tray consume the same skin manifest. Blocked tiles are darkened without changing their face asset. A blocked tap produces a short horizontal rejection motion and generated negative tone without submitting a gameplay command. Successful ordinary selections commit immediately, then animate a presentation-only duplicate into the next tray slot. A committed pair converges on the matching tray slot and composes the reusable `PairMatchFx` burst; Delete Pair composes the same removal primitive over its resolved board tiles.

These are production candidates with replaceable masters, not final approval of every glyph. Gameplay still uses the existing 24 abstract identities through the presentation-only map.

## Validation

Automated checks cover all 34 required IDs and runtime assets, uniqueness, canonical honor naming, all 24 temporary mappings, geometry values, independent face/modifier layers, board-to-tray motion targeting, blocked-tap isolation, transaction-gated pair feedback, shared Delete Pair removal feedback, responsive background coverage, and board containment in landscape, phone portrait, and `375 x 667` compact portrait.

The compact-phone board currently holds the minimum contract at approximately `33 x 42`. Continued visual review at `32 x 40` remains required for Default refinements and every Neon face before M7 can be considered done.

## Gameplay Background

The first gameplay-background source master lives at `art-source/backgrounds/gameplay_brush_arcade.png`; its generation prompt and export contract live beside it. The downsampled runtime export lives at `game-assets/backgrounds/gameplay_brush_arcade.png`.

Presentation uses an aspect-covered center crop plus a subtle dark wash. The center remains low-noise beneath the board while the outer brushwork can crop aggressively or disappear on compact viewports. Background imagery is cosmetic and has no simulation dependency.
