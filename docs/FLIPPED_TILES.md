# Flipped Tiles

Flipped tiles add a deterministic memory layer to the normal board and tray rules.

## Definition And State

- `GameDefinition.flipped_tile_ids` records the physical tiles that begin face-down.
- Reference games choose those IDs deterministically from the game seed. Rules version 10 permits at most one flipped physical tile per face identity, ensuring every flipped tile retains ordinary matching copies.
- `flipped_tile_count` is configuration data. The playable shell exposes it in the Godot Inspector and currently defaults to `12` on a 96-tile board.
- `GameStateData.revealed_flipped_tile_ids` records committed reveals in the replayable game state.
- Flipped identity belongs to the physical tile. Shuffle may move that tile to another stable layout slot without changing whether it is flipped or already revealed.
- Tile skins only provide presentation. They cannot change flipped identity or matching behavior.
- Modifier attachments remain visible on tile backs because they belong to the physical tile; only the mahjong face identity is hidden.

Rules version 9 introduces the flipped-tile state contract. Rules version 10 adds deterministic automatic reveals when board changes newly expose a face-down tile. Earlier rules versions preserve their existing behavior and definition identity.

## Interaction Rules

A face-down tile can be revealed only when ordinary board geometry considers it accessible. In rules version 10 and later, removing a covering or side-blocking board tile automatically reveals at most one newly accessible face-down tile when no other flipped tile is currently face-up. The transaction records that physical ID in `auto_revealed_tile_ids`, so replay and presentation do not recalculate the result from screen coordinates. Other newly accessible backs remain available for manual reveal. Face-down tiles that are accessible at the start of a game remain player-revealed.

An accepted reveal:

- commits a `reveal_tile` transaction;
- leaves the physical tile on the board;
- does not occupy the tray;
- does not award selection Momentum;
- does not reset or extend Combo by itself.

A revealed flipped tile remains a special board tile and can never enter the tray. Exactly one active flipped tile may be face-up. Revealing another back turns the previous tile face-down, even when both tiles have the same identity; flipped-to-flipped direct matching is not allowed in rules version 10. An ordinary non-matching selection also turns the exposed tile face-down before applying any newly uncovered automatic reveal from that move. Reveal and re-hide changes are committed in the accepted transaction.

When an ordinary accessible tile matches the active revealed flipped tile, the pair resolves directly from the board. When a face-down reveal matches a tile already in the tray, the revealed tile and held tile resolve atomically. A face-down tile never resolves against another flipped tile in rules version 10. These paths never create temporary authoritative tray occupancy.

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
2. A newly revealed tile matches the first matching tray tile.

Rules version 9 retains its legacy flipped-to-flipped candidate ordering for replay compatibility.

This ordering is simulation data, not presentation behavior.

## Consumables And Analysis

- Hint may pair a known revealed flipped face with an ordinary selectable mate. It does not reveal hidden identities.
- Delete Pair cannot target an unrevealed tile back or use one as the automatically selected mate.
- Shuffle preserves flipped and revealed state while deterministically remapping physical tiles to slots.
- Undo remains limited to the last unresolved tray selection. Reveals are not independently undoable, but undoing an ordinary non-match also restores the exposed flipped face that the selection transaction hid when no later reveal superseded it. A resolved flipped pair is an Undo barrier like every other resolved pair.
- Face-down and revealed flipped tiles are excluded from ordinary selectable-pair difficulty analysis. Flipped direct matches currently receive normal pair rewards but no geometry-based difficulty bonus.

## Presentation Contract

The current implementation uses a temporary high-contrast tile-back treatment and a short in-place flip. Automatically uncovered tiles use the same flip animation as manual reveals. A pair containing a flipped tile captures both rendered tiles, moves them into two open tray staging positions, pauses for the normal landing hold, and then collides them between those positions before composing the existing pair-removal burst. A newly tapped face-down tile reveals before tray travel begins. Staging remains presentation-only and never occupies authoritative tray slots; when three tiles are already held, the final two visual positions are reused so no temporary fifth data slot is introduced. The authoritative pair resolves immediately. Production tile-back artwork may replace the placeholder without changing simulation, transactions, or replay data.
