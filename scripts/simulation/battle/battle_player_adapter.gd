extends RefCounted

const GameDefinition := preload("res://scripts/simulation/game_definition.gd")
const GameStateData := preload("res://scripts/simulation/game_state_data.gd")
const Reducer := preload("res://scripts/simulation/game_reducer.gd")
const Momentum := preload("res://scripts/simulation/momentum_rules.gd")
var _battle: RefCounted
var _definition: RefCounted
var _game_state: RefCounted
var _valid := false


func _init(battle: RefCounted, game_definition: RefCounted) -> void:
	_battle = battle
	_definition = GameDefinition.from_dict(game_definition.to_dict())
	_game_state = GameStateData.new(_definition)
	var state: Dictionary = _battle.snapshot()
	_valid = state.has("player_charge") and state.player_charge.source_revision == 0 \
		and state.sides.player.cleared_pairs == 0 \
		and state.sides.player.remaining_pairs * 2 == _definition.tiles.size()


## Consume every committed Mahjong transaction, in order, from a fresh game.
## No UI callbacks, profile state, or mutations to the source game are involved.
func consume(transaction: RefCounted) -> Dictionary:
	if not _valid or transaction == null:
		return {"accepted": false, "reason": "invalid_adapter"}
	if transaction.previous_state_hash.is_empty() or transaction.next_state_hash.is_empty():
		return {"accepted": false, "reason": "uncommitted_transaction"}
	var after: Variant = Reducer.new().apply_forward(_definition, _game_state, transaction)
	if after == null:
		return {"accepted": false, "reason": "invalid_source_transaction"}
	var pairs: int = after.resolved_pair_count - _game_state.resolved_pair_count
	var natural := 1 if transaction.command_type in ["select_tile", "reveal_tile"] \
		and transaction.result in ["pair_resolved", "flipped_pair_resolved"] else 0
	var before_layers := _unresolved_by_layer(_game_state)
	var after_layers := _unresolved_by_layer(after)
	var cleared: Array = []
	if pairs > 0:
		for layer in before_layers:
			if not after_layers.has(layer):
				cleared.append(layer)
	cleared.sort()
	var event := {"source_hash": _definition.definition_hash(), "source_revision": transaction.revision,
		"at_ms": transaction.playback_time_ms, "pair_count": pairs, "natural_pairs": natural,
		"score": after.score, "streak": after.combo_count, "momentum_units": after.momentum_units,
		"momentum_tier": Momentum.multiplier_for(after.momentum_units, _definition.configuration), "cleared_layers": cleared}
	var result: Dictionary = _battle.submit({"id": "player_event_%d" % transaction.revision,
		"expected_revision": _battle.snapshot().revision, "type": "player_event", "side": "player", "event": event})
	if result.accepted:
		_game_state = after
	return result


func _unresolved_by_layer(state: RefCounted) -> Dictionary:
	var layers := {}
	for tile in _definition.tiles:
		if state.tile_zones[tile.id] == "resolved":
			continue
		var slot: Variant = _definition.get_tile(state.tile_slot_ids[tile.id])
		layers[slot.position.z] = true
	return layers
