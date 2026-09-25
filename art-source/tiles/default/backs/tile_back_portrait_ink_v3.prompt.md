# Portrait Ink Tile Backs V3

The portrait Default skin uses two transparent ceramic back masters with identical `2:3` geometry:

- `tile_back_portrait_ink_v3.png`: revealable/playable face-down state.
- `tile_back_portrait_ink_locked_v3.png`: inaccessible/locked face-down state.

Both were isolated from the supplied production references with background extraction only. The transparent Arcade Spark ornament remains a separate composited asset under `back-designs/`, so future back cosmetics can reuse either ceramic state without duplicating the tile shell.

Runtime exports are `512 x 768` PNGs under `game-assets/tiles/default/backs/`. Landscape continues using its existing back and blocked-veil fallback until matching wide artwork is supplied.
