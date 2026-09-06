# Default Town Source Assets

These first-pass raster masters were generated from the user-provided town composition as an art-direction reference. Runtime copies live under `game-assets/town/default/`.

- `town_map_concept.png`: original composition reference; never load this as the runtime hub.
- `town-ground.png`: square, vegetation-free ground layer with plaza, paths, water, and open destination pads.
- `destination-buildings-atlas.png`: transparent `1254 x 1254` atlas, three columns by two rows. Order: Tower, Home, Game Hall, Daily Shrine, Dojo, Downtown.
- `vegetation-atlas.png`: transparent `1536 x 1024` atlas, three columns by two rows. Order: two tree clusters, tall tree, cherry tree, hedge/flowers, bamboo/shrubs.

The generated assets use the built-in image generation workflow. Prompts requested matching isometric camera, warm daylight, anime/Y2K arcade rendering, transparent isolated sprites, no baked labels/UI, and season-neutral ground geometry.

Do not bake destination buildings or seasonally replaceable vegetation back into the ground layer. Replacement atlases must retain the documented cell grid or update the corresponding `AtlasTexture` regions in the theme resource.
