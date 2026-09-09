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

The Default skin uses one canonical `16:23` ceramic base geometry in portrait and landscape. This is fifteen percent taller than the earlier `4:5` prototype and clearly matches the upright inspiration silhouette. Both recipes preserve the same tile identity, stable authored slot, modifier attachment role, face-art layer, and physical silhouette. Orientation changes reflow peripheral UI without changing tile shape.

Legacy canonical face geometry:

| Contract | Pixels |
| --- | --- |
| Full source tile | `512 x 640` |
| Runtime reference tile | `256 x 320` |
| Face-art safe area | `x=92, y=104, w=328, h=400` |
| Modifier bounds | `x=384, y=32, w=96, h=96` |
| Runtime atlas padding | `8` |
| Minimum validated runtime footprint | `32 x 40` |

Active base geometry:

| Variant | Source | Runtime | Face safe area | Minimum footprint |
| --- | --- | --- | --- | --- |
| Portrait | `512 x 736` | `256 x 368` | `x=72, y=78, w=368, h=506` | `32 x 46` |
| Landscape | `512 x 736` | `256 x 368` | `x=72, y=78, w=368, h=506` | `32 x 46` |

Coordinates are recorded in each source tile's pixel space and scaled proportionally at runtime. Changing orientation does not rotate, reorder, transpose, or replace layout slot identifiers and does not affect simulation coverage or matching.

Tile composition remains:

```text
Tile Base
+ Tile Back (face-down state only)
+ Tile Back Design (face-down cosmetic overlay)
+ Tile Face
+ Modifier Overlay
+ Interaction State
+ FX
```

The current Godot proof renders the shared ceramic base as a texture, places imported face art inside the safe area, and places skin-declared modifier artwork in normalized shared bounds.

### Authored Depth Presentation

The Default skin's `depth_presentation` manifest section controls board-stack lighting and lift. The renderer maps the lowest authored `z` layer to `lowest_layer_brightness`, anchors the layer directly below the top to `near_top_layer_brightness`, and keeps the highest layer at full brightness. Intermediate layers interpolate between those anchors. Every authored layer is offset by `layer_offset_ratio`; the offset is an `[x, y]` fraction of the current rendered tile size per layer, so negative `y` moves higher layers upward and remains responsive across tile geometry and viewport sizes.

Each tile projects two presentation-only shadows: a tight, darker contact shadow derived from the active base silhouette and a larger, softer cast shadow using the skin's preblurred `shadow_asset`. Both occupy the render band below their own tile surface and above the next lower tile layer. Peer tiles therefore render cleanly over one another's shadows while upper tiles visibly shade the layer beneath them. The blur is precomputed rather than sampled by a per-tile shader, keeping the effect inexpensive on mobile. Opacity, offset, and cast expansion remain skin configuration values.

Blocked state is a separate cool, low-saturation silhouette glaze applied after the depth lighting. It darkens and mutes locked tiles independently from their authored layer, including tiles blocked by peers at the same height. A tile becomes canonical warm, full brightness as soon as it is selectable or otherwise visually active. Depth therefore communicates physical elevation while desaturation communicates availability. Tray tiles and moving previews remain fully lit because they are no longer being read as part of the board stack. Face-down tiles render the blank ceramic base without a question mark or rectangular placeholder.

The skin's `layout_presentation.adjacent_gap_ratio` controls spacing between immediately adjacent authored slots as a fraction of the active tile footprint. Zero makes control bounds touch; a small negative value compensates for transparent padding in base artwork. The Default skin uses `-0.025` so the visible ceramic edges meet in portrait and landscape. This setting is cosmetic and does not change authored positions, overlap rules, selectability, or replay data.

The same section defines a dark warm manga-ink silhouette using `ink_outline_color`, `ink_outline_expansion_ratio`, and `ink_outline_offset_ratio`. Presentation derives the silhouette from the active ceramic base, expands it slightly and asymmetrically, then renders it behind board, tray, and moving-preview tiles. It is not a rectangular control border and follows each orientation's alpha contour.

## Source And Runtime Assets

Editable tile masters live under `art-source/tiles/<skin>/`. Godot runtime tile exports live under `game-assets/tiles/<skin>/`. Shared modifier masters live under `art-source/modifiers/tile-overlays/`, with runtime exports under `game-assets/modifiers/tile-overlays/`.

Rules:

- SVG remains the canonical source format for flat face artwork. Physical tile bases and backs use high-resolution transparent raster masters with 1:1 front-and-back perspective alignment.
- The Default front favors a warm illustrated ceramic treatment: a tall upright silhouette, restrained highlight, thin irregular dark contour, and compact golden-brown foot. It intentionally omits corner wear and ornamental notches so the face artwork remains the visual identity. Cast shadows remain presentation layers rather than being baked into the base texture.
- Runtime tile assets are transparent sRGB PNG files at 50% source scale. Face-down presentation reuses the canonical terracotta tile back and composites the selected independent back design.
- Alpha is straight, not premultiplied.
- File names are stable logical face IDs such as `bamboo_1.svg` and `red_dragon.svg`.
- Runtime PNG files are generated outputs and must not be edited directly. The tile exporter downsamples raster base masters alongside SVG face masters.
- Run `godot --headless --path . --script res://scripts/tools/generate_default_tile_faces.gd` to regenerate the brush-arcade Default SVG candidate set.
- Run `godot --headless --path . --script res://scripts/tools/export_tile_art.gd` after changing tile or modifier SVG masters.
- Run `godot --headless --editor --path . --quit` after export on a fresh checkout so Godot imports every runtime PNG before headless tests.
- Small vector masters and runtime exports remain in Git. Large character, background, audio, and layered-painting storage remains an M7 production decision.

The proof uses individual PNG files so framing and import behavior are easy to inspect. Build atlases after the complete Default face set exists; do not make atlas coordinates part of gameplay identity.

## Skin Manifest

Each skin owns a versioned `skin.json` containing skin identity, geometry, guaranteed canonical face IDs, face labels and optional runtime asset paths, and any temporary compatibility mappings.

The loader requires the initial 34 IDs but does not reject additional face definitions. This allows the vocabulary to grow without changing the renderer contract.

Tile backs have two cosmetic layers. `back_variants` supplies a full-surface base that must read distinctly from the ivory front even before ornament is visible. `default_back_id` then chooses an entry from `back_designs`; each entry supplies transparent ornament artwork only. `base_variants.<orientation>.back_design_safe_area` defines where that ornament is composited over the back base. Back selection is cosmetic and must never enter matching, board, transaction, or replay logic. Durable player ownership and selection remain deferred to the profile milestone.

The Default back uses a terracotta face for immediate face-down recognition while sharing the front tile's golden-brown lower sidewall, contour, proportions, and lighting. Front and back should therefore read as two faces of one physical tile rather than unrelated colored pieces.

Tile-attached modifiers use the manifest's `modifiers` catalog and each orientation variant's `modifier_bounds`. The attachment area is a large upper-left badge so modifiers remain legible at phone gameplay size without obscuring the central face identity. The first shared overlay set uses an enamel arcade badge language: a pink heart for Extra Life, cyan snowflake for Cold Snap, amber impact `X` for Score Multiplier, and green expanding tray for Tray +1. Board tiles, tray tiles, and moving previews all resolve the same texture by modifier type. The artwork never enters simulation identity, attachment placement, transaction data, or replay state.

For visual and activation review, the gameplay shell exposes `playtest_all_modifiers` in the Inspector. When enabled, the run snapshots all six modifiers and places one on the first tile of each of the opening six solver pairs. Bomb is equipped at level 4 for Bomb 5, Three Pair Clear is equipped at level 2 for Match 3, and the other four modifiers remain level 0. The pregame debug picker separately exposes Bomb 1 through Bomb 6 and Match 1 through Match 5, allowing one iteration from each family at a time. This authoring-only path is deterministic and raises that run's loadout capacity to six; the default remains off and production reference games retain the single starter Score Multiplier with normal seeded placement. Three Pair Clear variants currently share the skin-declared circular `3` overlay while their picker labels and activation callouts report the effective pair count; Bomb uses a cartoon bomb and lit-fuse badge.

Missing face art intentionally falls back to live text during production. A skin is not production-complete until every identity used by a game definition has artwork and both text fallback and placeholder mappings are disabled for release.

## Current Default Assets

The Default candidate set contains all 34 Bamboo, Dots, Characters, Winds, and Dragons as editable SVG masters and runtime PNG exports. The treatment preserves familiar family and count structure while using heavy rounded strokes, loose registration, bright arcade color, and brush accents.

The board and tray consume the same skin manifest and canonical ceramic geometry in both orientations. Face-down board tiles compose a dark green patterned ceramic back plus the selected cosmetic design inside the shared safe area, making them recognizable without placeholder text. The Default skin currently selects `arcade_spark` from its `back_designs` catalog. A skin can replace either layer without duplicating gameplay geometry or changing tile identity. Revealed tiles return to the normal ivory base plus face composition. Animation previews capture the same active artwork, and orientation changes remain presentation-only. Covered tiles receive warm depth treatment without changing their face asset. A blocked tap produces a short horizontal rejection motion and generated negative tone without submitting a gameplay command. Successful ordinary selections commit immediately, then animate a presentation-only duplicate into the next tray slot. A committed pair converges on the matching tray slot and composes the reusable `PairMatchFx` burst; Delete Pair composes the same removal primitive over its resolved board tiles.

These are production candidates with replaceable masters, not final approval of every glyph. Gameplay still uses the existing 24 abstract identities through the presentation-only map.

## Validation

Automated checks cover all 34 required IDs and runtime assets, uniqueness, canonical honor naming, all 24 temporary mappings, geometry values, independent face/modifier layers, board-to-tray motion targeting, blocked-tap isolation, transaction-gated pair feedback, shared Delete Pair removal feedback, responsive background coverage, and board containment in landscape, phone portrait, and `375 x 667` compact portrait.

The compact-phone board validates the canonical tile at its declared `32 x 46` minimum. Portrait and landscape both retain the same `16:23` physical silhouette while the board scales to its available region. Continued visual review at the declared minimum remains required for Default refinements and every Neon face before M7 can be considered done.

## Gameplay Background

The first gameplay-background source master lives at `art-source/backgrounds/gameplay_brush_arcade.png`; its generation prompt and export contract live beside it. The downsampled runtime export lives at `game-assets/backgrounds/gameplay_brush_arcade.png`.

Presentation uses an aspect-covered center crop plus a subtle dark wash. The center remains low-noise beneath the board while the outer brushwork can crop aggressively or disappear on compact viewports. Background imagery is cosmetic and has no simulation dependency.
