# Battle Mahjong — Gameplay UI Design Guide

This document defines the design intent and responsive layout rules for the
Battle Mahjong gameplay screen.

It is not a pixel-perfect specification. Exact dimensions may evolve as the
game is implemented and tested across devices.

The important goal is to preserve the hierarchy, interaction ergonomics, and
visual identity described here.

---

## 1. Core Design Philosophy

Battle Mahjong is a fast, tactile mahjong solitaire game.

The gameplay UI should feel:

- immediate
- physical
- playful
- slightly punk / handmade
- arcade-like
- readable at a glance
- comfortable during rapid play

The board and tiles are always the hero.

UI exists to support the board rather than frame or dominate it.

Avoid the appearance of a conventional mobile-game dashboard where every
piece of information lives inside a large high-contrast panel.

---

## 2. Visual Identity

The target aesthetic combines:

- tactile ivory mahjong tiles
- dark green felt
- hand-painted / hand-printed typography
- slightly imperfect edges
- restrained punk / zine influence
- cute, colorful tile artwork
- black, cream, pink, cyan, yellow, lime, and other punchy accent colors

The visual inspiration is closer to:

> a playful early-2000s Japanese punk/anime zine turned into an arcade
> mahjong game

than to:

- cyberpunk
- casino mahjong
- traditional luxury mahjong
- generic polished mobile-game UI
- cozy Japanese interior design

### Punk character should come from the graphic language

Use:

- imperfect line work
- distressed/printed texture
- playful symbols
- hand-painted typography
- occasional subtle doodles
- bold accent colors

Do NOT create personality by filling the screen with decorative objects.

---

## 3. Component Layers And Themes

Portrait and landscape must be two layout recipes for the same component tree, not separate flattened screens. Runtime values, interaction controls, tiles, and effects remain live Godot nodes in both orientations.

Compose the gameplay screen in this presentation order:

1. scalable felt/background surface
2. optional low-contrast seasonal texture and edge decoration
3. orientation-specific layout containers
4. reusable component shells such as Score, Momentum, tray, consumables, and Pause
5. runtime text, icons, meter fill, tile faces, and touch targets
6. transient callouts, tile motion, particles, and modal overlays

Do not bake multiple systems into a full-screen portrait or landscape image. Export artwork as reusable pieces with stable transparent bounds. Use `NinePatchRect` for stretchable panels and cap/repeat/cap composition for variable-length structures such as the tray. The portrait tray may lay those pieces out horizontally while landscape arranges the same logical slots vertically; gameplay capacity and slot identity do not change.

Each component should expose independently replaceable themed parts:

- background surface, motif layer, and optional edge decoration
- Score and Momentum shells, accents, and runtime typography
- tray body pieces and slot treatment
- consumable tile base, action icon, and quantity plaque
- Pause tile base and icon
- tile base, face, back, modifier badge, ink, and shadow treatment
- reusable FX textures and color ramps

Theme selection is presentation-only and resolves these assets through a manifest or resource. Gameplay code must never branch on a theme ID. A theme may replace one component family while inheriting the default for everything else, which allows seasonal sets to ship incrementally without duplicating the complete UI.

Keep high-resolution editable masters under `art-source/` and optimized runtime exports under `game-assets/` (or the established runtime asset path for an existing component). Orientation-specific artwork is allowed when geometry truly differs, but shared artwork is the default and both variants must implement the same component contract.

---

## 4. Background

The primary gameplay surface is dark green felt.

The background may contain:

- subtle texture
- faint wear
- very low-contrast printed motifs
- restrained hand-drawn marks

Background decoration must remain visually behind gameplay.

### Do not use foreground-breaking decorations

Avoid decorative:

- plants
- books
- mugs
- loose tiles
- characters
- cats
- desk objects
- hanging charms
- props extending over UI

These are difficult to make responsive and distract from gameplay.

Think of the background as a single scalable surface.

---

# 5. Gameplay Hierarchy

The screen contains four primary functional systems:

1. Status HUD
2. Hold Tray
3. Mahjong Playfield
4. Consumables

Their visual importance should roughly be:

    PLAYFIELD
        ↓
    STATUS
        ↓
    HOLD TRAY
        ↓
    CONSUMABLES

The playfield should receive as much usable screen area as possible.

---

# 6. Playfield — Invariant Across Orientations

The mahjong board is the primary invariant.

Portrait and landscape should display the SAME gameplay layout.

Do not:

- regenerate the board for landscape
- flatten the board
- change tile relationships
- create a wider landscape-specific board
- change gameplay geometry to fill horizontal space

The surrounding UI reflows around the board.

The board does not reflow around the UI.

This is important both visually and mechanically: a given board should feel
like the same puzzle regardless of device orientation.

---

# 7. Portrait Layout

Portrait is the primary mobile layout.

Conceptual hierarchy:

    ┌─────────────────────────────┐
    │ STATUS HUD            PAUSE │
    │                             │
    │        HOLD TRAY            │
    │                             │
    │                             │
    │         PLAYFIELD           │
    │                             │
    │                             │
    │                             │
    │                             │
    │        CONSUMABLES          │
    └─────────────────────────────┘

## Status HUD

Position the main status HUD at the top.

It contains information such as:

- lives / hearts
- score
- momentum meter
- streak
- multiplier / combo state

The HUD should be compact.

Hearts display the run's available recovery charges. The production profile begins with zero and earns hearts through rewards; each new game snapshots its starting count so replay does not depend on mutable profile state. The current prototype grants three per run for playtesting.

The current preferred direction is a single cohesive horizontal status box
rather than many independent floating panels.

### Pause

Pause is separate from the status HUD.

Place it in the upper-right corner.

It should remain:

- obvious
- easy to reach
- visually secondary to gameplay

---

# 8. Portrait Hold Tray

The hold tray sits BELOW the status HUD and ABOVE the playfield.

This placement is intentional.

The hold tray is NON-INTERACTIVE during normal gameplay.

Selected tiles animate into it, but the player does not need to tap the tray.

Therefore it should not occupy valuable lower-screen interaction space.

## Thumb ergonomics

Players will commonly hold a phone vertically and interact using their thumbs.

The middle and lower portions of the screen are therefore the most valuable
interactive areas.

Do not place passive UI in this region unnecessarily.

Placing the tray above the board allows the playfield to extend farther toward
the player's thumbs.

It also creates a natural animation direction:

    selected board tile
            ↓
       leaves playfield
            ↓
       travels upward
            ↓
         hold tray

The tile visually exits the active interaction area.

---

# 9. Hold Tray Visual Design

Keep the tray simple.

It should feel more like a physical mahjong accessory than an inventory UI.

Preferred direction:

- shallow ivory / warm-white tray
- slightly darker or more neutral than tile faces
- subtle depth
- restrained edge treatment
- physical/tactile appearance

Tiles sit naturally inside the tray.

Avoid:

- giant black containers
- heavy gold frames
- large HOLD labels
- high-contrast slot outlines
- unnecessary capacity labels
- inventory-screen styling

The tray is intentionally visually quiet.

### Empty slots

Empty capacity can be represented by:

- shallow recesses
- subtle impressions
- minimal registration marks

or potentially no explicit slot treatment at all.

The tiles themselves should remain the strongest visual objects.

---

# 10. Landscape Layout

Landscape does NOT introduce additional gameplay UI.

Instead, existing components reflow into the extra horizontal space.

Conceptually:

    ┌───────────────────────────────────────────────────┐
    │ STATUS HUD                                PAUSE   │
    │                                                   │
    │                PLAYFIELD          HOLD TRAY       │
    │                                     [tile]        │
    │                                     [tile]        │
    │                                     [tile]        │
    │                                     [empty]       │
    │                                                   │
    │ CONSUMABLES                                       │
    └───────────────────────────────────────────────────┘

### Critical rule

THERE IS ONLY ONE HOLD TRAY.

Portrait:

    horizontal tray above playfield

Landscape:

    vertical tray beside playfield

The portrait tray is reflowed into the landscape tray.

It is NOT duplicated.

Never place another tray underneath the landscape playfield.

---

# 11. Landscape Playfield

Use the horizontal space for peripheral UI.

Do not use it as justification for making the board itself wider.

The landscape board should consume as much vertical space as practical.

Peripheral systems can occupy the left and right margins:

LEFT:
- score
- hearts
- momentum
- streak
- consumables where appropriate

CENTER:
- playfield

RIGHT:
- vertical hold tray

TOP RIGHT:
- pause

The result should preserve the same gameplay experience while taking advantage
of otherwise unused horizontal space.

---

# 12. Landscape Hold Tray

The landscape tray is the same conceptual object as the portrait tray.

It becomes vertical.

Use the same physical visual language:

- warm ivory
- simple
- low contrast
- tactile
- visually secondary

Do not turn it into a dark inventory sidebar.

---

# 13. Consumables

Consumables ARE interactive.

Examples include:

- Hint
- Shuffle
- Undo
- Bomb

They should therefore remain accessible to the player's thumbs.

In portrait:

Place a compact consumables strip near the bottom of the screen.

In landscape:

Use available peripheral space, likely toward the lower-left or another
comfortable edge location.

Consumables should be:

- easy to identify
- easy to tap
- compact
- clearly separate from passive UI

They should not steal significant space from the playfield.

---

# 14. Responsive Design Principle

Battle Mahjong should not have two unrelated gameplay interfaces.

Think of the system as:

    FIXED GAMEPLAY CORE
            +
    RESPONSIVE PERIPHERAL UI

The playfield stays conceptually invariant.

Peripheral UI changes placement according to available aspect ratio.

Portrait favors vertical stacking.

Landscape moves passive UI into horizontal margins.

---

# 15. Animation and Layout

UI layout must support rapid gameplay animations.

Selected tiles animate independently from:

    BOARD → HOLD TRAY

A later selection must never interrupt, snap, restart, or reposition an
already-running tile animation.

Presentation owns an animated tile until its current movement completes.

Responsive tray positioning therefore needs to expose a stable destination
for tile-transfer animations in either orientation.

Portrait destination:
    horizontal upper tray

Landscape destination:
    vertical right tray

---

# 16. Safe Areas

All peripheral UI must respect platform safe areas.

Particular attention should be paid to:

- portrait top HUD
- pause button
- landscape left/right HUD regions
- landscape vertical tray
- bottom consumables

The playfield should be centered within the remaining usable gameplay region,
not blindly centered within the raw viewport.

---

# 17. Typography

Use the custom Battle Mahjong typography where appropriate.

Primary custom font:

    Battle Mahjong Poster Script

It is intended for:

- scores
- streak information
- short labels
- headings
- arcade feedback
- buttons where legibility permits

Typography should reinforce the handmade printed aesthetic.

Do not overuse the custom font for tiny informational text where readability
would suffer.

---

# 18. Visual Priority

When deciding whether to add UI decoration, ask:

> Does this make the tiles and gameplay easier or more exciting to read?

If not, remove it.

The desired screen should feel surprisingly simple when the board is removed.

Most of the richness comes from:

- the tile stack
- tile artwork
- movement
- modifiers
- match effects
- momentum feedback

not from static UI chrome.

---

# 19. Things We Have Tried and Rejected

These directions have already been explored and should NOT be reintroduced
without deliberate design discussion.

### Duplicate trays in landscape

Rejected.

Landscape has exactly one vertical hold tray.

### Bottom tray in landscape

Rejected.

It wastes valuable vertical board space.

### High-contrast inventory-style hold panel

Rejected.

The hold tray should be quiet and physical.

### Busy illustrated backgrounds

Rejected.

They compete with the board.

### Foreground decorative props

Rejected.

They complicate responsive implementation and obscure gameplay.

### Traditional/cozy Japanese styling

Not the target.

Battle Mahjong should retain its punky, youthful arcade personality.

### Generic cyberpunk/neon treatment

Not the target.

Bright colors should feel like ink, paint, stickers, arcade graphics, and
printed material rather than futuristic neon UI.

---

# 20. Implementation Rule of Thumb

When adapting the gameplay UI to a new screen size:

1. Determine the safe usable viewport.
2. Reserve compact peripheral regions for required UI.
3. Give the playfield the maximum practical scale.
4. Preserve the playfield's aspect ratio and tile relationships.
5. Reflow the hold tray based on orientation.
6. Keep interactive controls within comfortable reach.
7. Do not add UI merely to fill empty space.

Empty felt is acceptable.

Breathing room is preferable to unnecessary decoration.
