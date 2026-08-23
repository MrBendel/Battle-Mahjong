# Flipped Tiles

Flipped tiles add a deterministic memory layer to the normal board and tray rules.

## Definition And State

- `GameDefinition.flipped_tile_ids` records the physical tiles that begin face-down.
- Reference games choose those IDs deterministically from the game seed.
- `flipped_tile_count` is configuration data. The playable shell exposes it in the Godot Inspector and currently defaults to `12` on a 96-tile board.
- `GameStateData.revealed_flipped_tile_ids` records committed reveals in the replayable game state.
- Flipped identity belongs to the physical tile. Shuffle may move that tile to another stable layout slot without changing whether it is flipped or already revealed.
- Tile skins only provide presentation. They cannot change flipped identity or matching behavior.
- Modifier attachments remain visible on tile backs because they belong to the physical tile; only the mahjong face identity is hidden.

Rules version 9 introduces this state contract. Earlier rules versions preserve their existing definition identity and have no flipped tiles.

## Interaction Rules

A face-down tile can be revealed only when ordinary board geometry considers it accessible. Removing covering or side-blocking tiles may therefore make additional face-down tiles revealable. Accessibility does not automatically reveal a tile.

An accepted reveal:

- commits a `reveal_tile` transaction;
- leaves the physical tile on the board;
- does not occupy the tray;
- does not award selection Momentum;
- does not reset or extend Combo by itself.

A revealed flipped tile remains a special board tile and can never enter the tray. Only one unmatched flipped face remains exposed: selecting an ordinary non-matching tile turns it face-down again, while revealing a different non-matching flipped tile turns the previous tile face-down and leaves the newly tapped tile exposed. The re-hide is part of the same deterministic transaction as the accepted selection or reveal.

When an ordinary accessible tile matches an active revealed flipped tile, the pair resolves directly from the board. When a face-down reveal matches a tile already in the tray, the revealed tile and held tile resolve atomically. When it matches another active revealed flipped tile, both board tiles resolve atomically. These paths never create temporary authoritative tray occupancy.

Direct flipped matches are natural pairs. They:

- increment pair and selection projections consistently;
- award normal pair score and Momentum;
- extend Combo;
- activate attached modifiers;
- can win the game;
- record stable `flipped_pair` transaction telemetry.

An ordinary tile selected against a revealed flipped mate still receives the configured natural-selection Momentum gain. A reveal that completes a pair receives pair Momentum but not selection Momentum.

## Deterministic Priority

Four-copy identities can create multiple legal mates. The authoritative priority is:

1. An ordinary selected tile matches the lexically first active revealed flipped mate before checking the tray.
2. A newly revealed tile matches the first matching tray tile before checking active revealed flipped mates.
3. Active revealed flipped candidates are ordered by physical tile ID.

This ordering is simulation data, not presentation behavior.

## Consumables And Analysis

- Hint may pair a known revealed flipped face with an ordinary selectable mate. It does not reveal hidden identities.
- Delete Pair cannot target an unrevealed tile back or use one as the automatically selected mate.
- Shuffle preserves flipped and revealed state while deterministically remapping physical tiles to slots.
- Undo remains limited to the last unresolved tray selection. Reveals are not undoable, and a resolved flipped pair is an Undo barrier like every other resolved pair.
- Face-down and revealed flipped tiles are excluded from ordinary selectable-pair difficulty analysis. Flipped direct matches currently receive normal pair rewards but no geometry-based difficulty bonus.

## Presentation Contract

The current implementation uses a temporary high-contrast tile-back treatment and a short in-place flip. Board-to-board direct matches capture both tiles at their rendered size, send them along opposing curved paths to collide at the center of the game board, and then compose the existing pair-removal burst. When the matching tile is already in the tray, the flipped tile instead curves upward and collides at the held tile's actual tray position. These sequences are presentation-only; the authoritative pair resolves immediately. Production tile-back artwork may replace the placeholder without changing simulation, transactions, or replay data.
