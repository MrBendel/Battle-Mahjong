extends RefCounted

const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")

var capacity: int:
	get:
		return _definition.tray_capacity()

var tiles: Array:
	get:
		var projected: Array = []
		for tile_id in _state.tray_tile_ids:
			projected.append(_definition.get_tile(tile_id))
		return projected

var resolved_pair_count: int:
	get:
		return _state.resolved_pair_count

var failed: bool:
	get:
		return _state.status == GameStateDataScript.LOST

var _definition: Variant
var _state: Variant


func _init(definition: Variant, state: Variant) -> void:
	_definition = definition
	_state = state
