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

Rules version 9 introduces the flipped-tile state contract. Rules version 10 adds deterministic automatic reveals when board changes newly expose a face-down tile. Rules version 11 requires board mates to stage in the tray before resolving against a revealed flipped tile. Rules version 12 makes reveal and play separate actions: the first tap reveals a face-down tile and the second tap selects that revealed tile into the authoritative tray. Rules version 13 removes broad automatic reveals so newly uncovered backs require a player tap. Rules version 14 makes that reveal tap immediately resolve when the revealed identity already has a mate in the tray. Rules version 20 adds a narrow cleanup reveal for the final visible face-down tile on an authored layer. Earlier rules versions preserve their existing behavior and definition identity.

## Interaction Rules

A face-down tile can be revealed manually only when ordinary board geometry considers it accessible. In rules versions 13 through 19, uncovering a back only makes it manually revealable; it remains face-down until the player taps it. Rules version 20 additionally reveals the final face-down tile on an authored `z` layer automatically once that tile is geometrically visible. Automatic cleanup does not require side selectability because it reveals information without moving the tile. Ordinary face-up tiles may remain on the layer, but another face-down tile on that layer suppresses cleanup even when that other back is covered or blocked. The candidate must already have been face-down before the transaction, so a normal selection that closes an unmatched peek does not immediately reopen it. If several layers qualify together, the highest layer wins, with physical tile ID as the deterministic tie-breaker; at most one active face remains revealed. Rules versions 10 through 12 retain their broader newly-uncovered automatic reveal behavior for replay compatibility.

An accepted reveal:

- commits a `reveal_tile` transaction;
- leaves the physical tile on the board;
- does not occupy the tray;
- does not award selection Momentum;
- does not reset or extend Combo by itself.

Each manual or automatic reveal records deterministic, timeline-derived progress for physical flipped tiles seen at least once. Automatic cleanup uses the same transaction's `auto_revealed_tile_ids` telemetry rather than creating a presentation-only state change. When the final never-before-seen flipped tile is turned face-up, telemetry marks `all_flipped_tiles_revealed` exactly once. Re-hiding and revealing an earlier tile does not reset progress or retrigger completion.

A manually revealed flipped tile remains face-up on the board until the next accepted board selection. In rules versions 12 and 13, tapping that same accessible tile again performs an ordinary authoritative tray selection. Rules version 14 and later keep the peek when no mate is held, after which a second tap sends the revealed tile to the tray; when the reveal finds a matching tray tile, the first tap resolves the pair atomically. Manual peeks remain limited to one active tile: revealing another back or accepting an ordinary non-matching selection turns the previous manual peek face-down. A rules-version-20 final-layer cleanup reveal is persistent and remains face-up until selected or resolved; it does not close on later board actions and does not prevent another layer's final back from revealing. Flipped-to-flipped direct matching remains disallowed. Reveal, play, and re-hide changes are committed in their accepted transactions.

An ordinary board tile never resolves directly against the active revealed flipped tile in rules version 11. Selecting that ordinary mate performs a normal authoritative move into the tray and turns the revealed tile face-down like every other accepted board selection. The player must then tap the tile back again to reveal and resolve it against the held mate. If three unresolved tiles were already held, selecting the board mate fills the fourth slot and loses before the flipped tile can be tapped; a flipped tile therefore provides no implicit fifth tray slot.

Rules version 11 and earlier retain atomic flipped-to-tray resolution for recorded games. Rules versions 12 and 13 always reveal first and require a second tap for tray play. Rules version 14 and later resolve on the reveal tap only when a matching tile is already held; otherwise they preserve the separate peek and play actions. A face-down tile never resolves against another flipped tile.

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

The Default skin supplies dedicated portrait and landscape tile-back artwork. Unmatched peeks use the full horizontal flip treatment. A reveal that auto-matches opens from edge-on, holds fully face-up for an Inspector-tunable readability beat, then moves into the open queue slot, pauses, and collides with its held mate through the shared tray animation. A live `MATCH!` callout explains the immediate resolution unless a modifier reward or one-time board-progress alert owns the single presentation lane. Presentation never adds temporary authoritative occupancy.

The final unique flipped-tile reveal sends `ALL TILES REVEALED!` through the shared single arcade-callout lane. The callout is live text derived from committed transaction telemetry, so replay presentation can reproduce it without changing simulation state.
