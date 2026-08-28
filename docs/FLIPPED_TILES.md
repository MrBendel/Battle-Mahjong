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

Rules version 9 introduces the flipped-tile state contract. Rules version 10 adds deterministic automatic reveals when board changes newly expose a face-down tile. Rules version 11 requires board mates to stage in the tray before resolving against a revealed flipped tile. Rules version 12 makes reveal and play separate actions: the first tap reveals a face-down tile and the second tap selects that revealed tile into the authoritative tray. Rules version 13 removes automatic reveals so every face-down tile requires a player tap. Earlier rules versions preserve their existing behavior and definition identity.

## Interaction Rules

A face-down tile can be revealed only when ordinary board geometry considers it accessible. In rules version 13 and later, uncovering a back only makes it revealable; it remains face-down until the player taps it. Rules versions 10 through 12 retain their deterministic automatic reveal transaction and `auto_revealed_tile_ids` telemetry for replay compatibility.

An accepted reveal:

- commits a `reveal_tile` transaction;
- leaves the physical tile on the board;
- does not occupy the tray;
- does not award selection Momentum;
- does not reset or extend Combo by itself.

Each reveal transaction also records deterministic, timeline-derived progress for physical flipped tiles seen at least once. When the final never-before-seen flipped tile is turned face-up, telemetry marks `all_flipped_tiles_revealed` exactly once. Re-hiding and revealing an earlier tile does not reset progress or retrigger completion.

A revealed flipped tile remains face-up on the board until the next accepted board selection. In rules version 12 and later, tapping that same accessible tile again performs an ordinary authoritative tray selection. It occupies a slot when unmatched and resolves normally when its mate is already held. The reveal itself never occupies a tray slot, and a face-down tile never skips directly to tray resolution. Exactly one active flipped tile may be face-up. Revealing another back turns the previous tile face-down, even when both tiles have the same identity; flipped-to-flipped direct matching is not allowed in rules version 10 and later. An ordinary non-matching selection also turns the exposed tile face-down. Reveal, play, and re-hide changes are committed in their accepted transactions.

An ordinary board tile never resolves directly against the active revealed flipped tile in rules version 11. Selecting that ordinary mate performs a normal authoritative move into the tray and turns the revealed tile face-down like every other accepted board selection. The player must then tap the tile back again to reveal and resolve it against the held mate. If three unresolved tiles were already held, selecting the board mate fills the fourth slot and loses before the flipped tile can be tapped; a flipped tile therefore provides no implicit fifth tray slot.

Rules version 11 and earlier retain atomic flipped-to-tray resolution for recorded games. In rules version 12 and later, a face-down tile always reveals first; its second tap uses the same tray occupancy, capacity, loss, pair scoring, and Undo rules as an ordinary selection. A face-down tile never resolves against another flipped tile.

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

1. An ordinary selected tile checks the tray normally and never consumes a revealed board mate.
2. A revealed flipped tile selected on its second tap matches the first matching tray tile.

Rules versions 9 and 10 retain their earlier direct-match behavior for replay compatibility.

This ordering is simulation data, not presentation behavior.

## Consumables And Analysis

- Hint may pair a known revealed flipped face with an ordinary selectable mate. It does not reveal hidden identities.
- Delete Pair cannot target an unrevealed tile back or use one as the automatically selected mate.
- Shuffle preserves flipped and revealed state while deterministically remapping physical tiles to slots.
- Undo remains limited to the last unresolved tray selection. Reveals are not independently undoable, but undoing an ordinary non-match also restores the exposed flipped face that the selection transaction hid when no later reveal superseded it. A resolved flipped pair is an Undo barrier like every other resolved pair.
- Face-down and revealed flipped tiles are excluded from ordinary selectable-pair difficulty analysis. Flipped direct matches currently receive normal pair rewards but no geometry-based difficulty bonus.

## Presentation Contract

The Default skin supplies dedicated portrait and landscape tile-back artwork. Player reveals compress the tile horizontally, swap back/front artwork during a brief edge-on midpoint, and expand with a short additive afterimage. Flip-back uses the same animation in reverse. The shell exposes the full two-sided duration through `tile_flip_seconds`, currently `0.25` seconds; previews that are already edge-on use only the opening half. On the second tap, the revealed tile uses the ordinary board-to-tray transfer; a matching pair pauses in the open slot and collides with its held mate through the shared tray animation. Presentation never adds temporary authoritative occupancy.

The final unique flipped-tile reveal sends `ALL TILES REVEALED!` through the shared single arcade-callout lane. The callout is live text derived from committed transaction telemetry, so replay presentation can reproduce it without changing simulation state.
