# Town Hub

Status: Initial presentation foundation

The Town Hub is Battle Mahjong's application-level home and the future presentation surface for modes, profile-owned choices, progression, and live events. It sits above individual games and must not own simulation state.

## First Slice

The initial implementation launches into a responsive town map. The Mall is the only active destination and enters the existing generated-Board and modifier-loadout flow. Other destinations remain visible but non-interactive until their owning milestones define real behavior.

The supplied `Colorful Mahjong Town Hub Map.png` is retained only as concept artwork under `art-source/town/default/`. Runtime presentation uses a constructed asset kit: a vegetation-free ground map, six destination-building atlas regions, and a separate vegetation atlas. The same pieces are recomposed for portrait and landscape.

## Application Boundary

```text
AppRoot
  TownHubView
  GameShell
  future Profile and Library screens
```

`AppRoot` owns screen transitions. `TownHubView` emits destination intent such as `tower`; it does not construct a `GameDefinition`, read profile storage, or mutate gameplay. `GameShell` can request a return to town without knowing how the application represents the hub.

When M9 persistence is implemented, the application coordinator will load a profile, snapshot validated profile choices into a new game record, and then enter `GameShell`. The active game must remain independent from later profile mutations.

## Responsive Composition

The environment uses one stable full-bleed world canvas. Destinations have orientation-specific presentation rectangles because they are independently positioned scene elements rather than content baked into the ground map. Destination identity and behavior remain stable when the composition changes.

- Portrait arranges destinations vertically around the central landmark.
- Landscape spreads the same destination sprites across a wide plaza.
- Safe-area insets are applied before map scaling.
- Runtime art, signs, and animation scale through the shared presentation-scale utility.
- Each destination is a `TextureButton` with a click mask derived from its sprite alpha. The visible building is the hit target; its transparent rectangular bounds and separate sign reject input.
- Destination signs are live clipped-corner controls with themed board colors, inset borders, fasteners, and width-aware font fitting. Sign artwork and labels must never be baked into building sprites.

The production map may later support limited panning or camera framing. Portrait and landscape remain two arrangements of one asset kit rather than unrelated flattened illustrations.

## Destination Asset Contract

Production artwork should separate:

- terrain, paths, water, and other stable non-interactive environment;
- each destination building on a transparent canvas aligned to the world map;
- trees, shrubs, flowers, and other seasonally replaceable vegetation;
- foreground occlusion such as branches and banners;
- destination signage where live labels or localization are required;
- optional decoration overlays and ambient effects.

The environment remains still. Available destination sprites use a restrained brightness pulse and small vertical idle motion. The stationary `TextureButton` owns alpha-masked input while a child `Sprite2D` owns subpixel visual motion, avoiding Godot `Control` pixel snapping and moving hit targets. Touch or controller focus may strengthen the treatment. Locked destinations remain quiet and must not compete with available destinations. Large rectangular hotspot panels are prohibited.

## Seasonal Themes

`TownTheme` changes presentation without changing navigation geometry. Every theme shares the same map dimensions and destination anchors.

The first resource contract supports:

- base environment texture;
- optional foreground or seasonal overlay;
- ambient tint and clear color;
- available and locked presentation colors;
- optional destination-specific replacement overlays.

This supports three production costs:

1. Palette themes change lighting and accents.
2. Decoration themes add snow, blossoms, lanterns, banners, or similar overlays.
3. Full themes replace environment or building artwork while preserving registration and hit geometry.

Theme selection is presentation/profile state and never participates in game-definition hashes. A future content catalog may choose a seasonal default, but gameplay must not depend on device wall-clock time.

## Destination Ownership

- **The Mall / Tower:** endless Tower mode; current first playable entrance.
- **Your Home:** profile, equipped cosmetics, collection, and loadout presentation.
- **The Dojo:** practice, tutorials, and development difficulty tools.
- **Game Hall:** battle and tournaments.
- **Daily Shrine:** daily deterministic play.
- **Downtown:** shops, tile packs, and cosmetics.

News, Inbox, Friends, Quests, currencies, shops, progression, and social behavior remain deferred. Their appearance in concept artwork is not an implementation commitment.

## Production Art Handoff

The current generated first-pass kit lives under `art-source/town/default/`, with runtime copies under `game-assets/town/default/`:

- `town-ground.png`: season-neutral ground and fixed plaza geometry;
- `destination-buildings-atlas.png`: transparent 3-by-2 destination atlas;
- `vegetation-atlas.png`: transparent 3-by-2 foliage atlas.

Future art handoffs should preserve those boundaries and provide independently aligned destination and decoration sprites without baked HUD, labels, currency values, or interaction outlines. Runtime UI text remains live for scaling and localization.
