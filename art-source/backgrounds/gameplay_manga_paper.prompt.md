# Gameplay Manga Paper Background

The portrait source was supplied as production artwork and normalized to the theme's canonical `941 x 1672` portrait dimensions. The matching landscape companion was generated with the built-in OpenAI image-generation tool from that portrait reference.

## Landscape Prompt

Derive a wide landscape companion from the supplied portrait manga-paper background while preserving its exact visual language. Use a `16:9` landscape canvas with a quiet, lightly textured cream paper center covering at least the middle 65% for gameplay tiles. Recompose the same distressed black halftone, dry ink splatters, sharp brush wedges, red rising sun with hand-drawn cream clouds, and restrained cyan/red corner strokes around only the far perimeter. Do not rotate or horizontally stretch the reference.

Background only. Preserve a calm high-readability center and edge artwork that survives cropping and `48 px` scale-9 margins. Do not add a frame, border, rounded rectangle, text, logo, characters, mahjong tiles, UI, or watermark.

## Export

- Portrait source/runtime: `941 x 1672` PNG.
- Landscape source/runtime: `1672 x 941` PNG.
- Godot presentation: orientation-specific `NinePatchRect` assets with `48 px` margins.
