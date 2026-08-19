# Art Direction

Core visual goal:

> Polished, high-contrast gameplay combined with cute, expressive, slightly weird 2000s-era anime/arcade personality.

The board itself should be disciplined and easy to read. The feedback layer should be exuberant.

## Production Contract

The detailed requirements, asset contracts, production batches, dependencies, and acceptance criteria for the first major art-production milestone are defined in [M07 - Art Foundation And First Visual Slice](milestones/M07_ART_FOUNDATION.md).

This document remains the high-level visual direction. The milestone document is the production plan and should be updated when implementation establishes concrete dimensions, formats, budgets, or pipeline constraints.

## Reference Energy

- late-90s / 2000s Japanese arcade games
- Ridge Racer-style enthusiastic announcer energy
- anime character cut-ins
- dramatic speed lines
- impact frames
- playful particles
- colorful Y2K-era game UI
- indie personality without looking intentionally unfinished

Presentation principle:

> The better the player is doing, the more excited the game becomes.

## Intensity

At low momentum:

- relatively calm

At higher momentum:

- more particles
- stronger animations
- announcer activity
- UI intensity
- character reactions
- music/audio escalation

Effects must not obscure the board during normal high-speed recognition. Major achievements may temporarily earn more dramatic presentation.

## Portrait And Landscape

The game must support both portrait and landscape as a core requirement.

- Do not design portrait and landscape as separate implementations.
- The board should maintain strong readability and scale to the largest sensible available area.
- HUD components should reflow around the board.
- Tile readability should not be sacrificed to preserve decorative UI.

Visual hierarchy:

1. tiles
2. tray
3. momentum
4. consumables
5. score/status
6. character artwork and decorative presentation

Character art may move, crop, shrink, or disappear if necessary.

## Tile Art And Cosmetics

Tiles should use a canonical geometry and rendering contract:

```text
Tile Base
+ Tile Face
+ Modifier
+ Interaction State
+ FX
```

Avoid baking every combination into separate artwork.

Potential tile skin sets:

- Classic Ivory
- Neon
- Pixel
- Hand Drawn
- Kawaii
- Y2K translucent plastic
- Sticker/Doodle
- Luxury/Jade

All skins should implement the same logical tile identifiers.

Example identifiers:

```text
bamboo_1
...
bamboo_9

dots_1
...
dots_9

characters_1
...
characters_9

east
south
west
north

red_dragon
green_dragon
white_dragon
```

The gameplay system must not care which visual skin is selected.

Tile skins should be cosmetic, not mechanically advantageous. Collecting, unlocking, or buying tile sets can become part of progression.

## Asset Strategy

- Runtime sprite atlases are likely appropriate for tile faces, modifiers, consumables, icons, and small FX.
- Large character illustrations should remain separate transparent assets.
- High-resolution source artwork should be kept separately from optimized runtime assets.

Status: Initial M7 Direction

- The first Battle Mahjong title logo uses bold brush lettering, a high-contrast black backing shape, hot-pink emphasis, and loose arcade star accents. The runtime/reference asset lives at `game-assets/art/title_logo.png`.
- The first visual slice will separate source masters from runtime exports.
- Default and Neon skins will share canonical tile geometry and logical face identifiers.
- Small repeated assets will use atlases where validation confirms they are appropriate.
- The implemented Batch A proof uses `512 x 640` SVG masters, `256 x 320` PNG exports, a `328 x 400` face safe area, and independent modifier overlays. See [Tile Art Pipeline](TILE_ART_PIPELINE.md).
- The 34 traditional identities are the required first vocabulary, not a permanent maximum.

Status: Open Question

- Exact source formats, runtime export settings, and repository or large-file storage policy.
- Final character art style.

## Audio Direction

The announcer should evoke an enthusiastic Japanese arcade-racing-game personality without copying specific copyrighted performances or phrases.

Possible behavior-driven praise:

```text
fast pair -> LIGHTNING!
hard visual pair -> EAGLE EYES!
newly exposed pair immediately found -> SAW THAT COMING!
dangerous tray recovery -> CLUTCH!
cold snap streak -> ICE COLD!
major streak -> UNSTOPPABLE!
```

Announcer packs may eventually become cosmetic rewards.

Status: Open Question

- Exact voice direction.
- Exact audio escalation rules.
- Whether announcer packs affect competitive categories.
