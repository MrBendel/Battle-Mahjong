# Portrait Ink Tile V3

The enabled and locked masters were derived from user-supplied concept artwork with the built-in image generation tool in background-extraction mode.

The extraction removed the baked black surround and preserved transparent padding, tall portrait proportions, ivory or muted ceramic color, ink splatters, scratches, bevels, highlights, and physical base thickness. Runtime exports are `512 x 768` PNG files under `game-assets/tiles/default/bases/`.

- `tile_base_portrait_ink_v3.png`: enabled/available ceramic master.
- `tile_base_portrait_ink_locked_v3.png`: muted locked ceramic master.

The locked asset is presentation-only. Matching, tile identity, stable slots, transactions, and replay data never depend on it.

The matching `backs/tile_back_portrait_ink_v3.png` and `backs/tile_back_portrait_ink_locked_v3.png` masters use the same background-extraction process. They remain blank beneath the separately composited cosmetic back design.
