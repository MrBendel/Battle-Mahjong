# Core Gameplay

Battle Mahjong uses a layered mahjong-solitaire-style board with a permissive tray system that creates push-your-luck routing.

## Board Interaction

- The board contains physical tile objects in layered `(x, y, z)` positions.
- Selectability follows mahjong-solitaire-style blocking rules.
- Selectable tiles can be moved into the tray.
- Matching rules use logical tile identities, not cosmetic tile skins.

Status: Open Question

- Exact board layouts.
- Exact selectability edge cases for custom layouts.

## Tray

- The tray initially contains 4 slots.
- When two matching tiles enter the tray, they form a pair and are removed.
- Players may temporarily hold unmatched tiles while searching for their mates.
- If the tray fills with 4 unresolved tiles and the player cannot resolve a pair, the run is lost unless an active effect such as Extra Life prevents failure.

The tray is intentionally more permissive than traditional mahjong solitaire and should support temporary unmatched holdings.

Status: Open Question

- Exact failure timing when the fourth unresolved tile enters the tray.
- Whether some modes or modifiers adjust base tray capacity.

## Momentum

Successful pair clears push up a continuously decaying momentum meter.

Multiplier progression concept:

```text
x1 -> x2 -> x3 -> x4 -> x5 -> ...
```

Higher multiplier tiers should become progressively harder to maintain.

As players solve more rapidly:

- multiplier increases
- momentum becomes more valuable
- decay pressure increases
- visual/audio intensity increases

Stopping to search causes momentum to fall.

Status: Open Question

- Exact momentum gain values.
- Exact decay values.
- Exact multiplier thresholds.
- Exact score formula.

Tuning values should be configuration, not hard-coded assumptions.

## Win And Loss

Expected base outcomes:

- Win: all board and tray tiles are resolved.
- Loss: tray failure occurs and no active effect prevents it.

Status: Open Question

- Whether some modes have additional fail states.
- How score, time, and replay validity interact after loss prevention effects.
