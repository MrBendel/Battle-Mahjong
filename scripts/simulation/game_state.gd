extends RefCounted

const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const BoardOpportunityAnalysisScript := preload("res://scripts/simulation/board_opportunity_analysis.gd")
const ComboRulesScript := preload("res://scripts/simulation/combo_rules.gd")
const GameCommandScript := preload("res://scripts/simulation/game_command.gd")
const GameCommandProcessorScript := preload("res://scripts/simulation/game_command_processor.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const GameStoreScript := preload("res://scripts/simulation/game_store.gd")
const MomentumRulesScript := preload("res://scripts/simulation/momentum_rules.gd")
const ModifierRulesScript := preload("res://scripts/simulation/modifier_rules.gd")
const TrayStateScript := preload("res://scripts/simulation/tray_state.gd")

const PLAYING := GameStateDataScript.PLAYING
const WON := GameStateDataScript.WON
const LOST := GameStateDataScript.LOST

const SELECTED := GameCommandProcessorScript.SELECTED
const PAIR_RESOLVED := GameCommandProcessorScript.PAIR_RESOLVED
const TILE_REVEALED := GameCommandProcessorScript.TILE_REVEALED
const FLIPPED_PAIR_RESOLVED := GameCommandProcessorScript.FLIPPED_PAIR_RESOLVED
const INVALID_SELECTION := GameCommandProcessorScript.INVALID_SELECTION
const GAME_OVER := GameCommandProcessorScript.GAME_OVER
const EXTRA_LIFE_USED := GameCommandProcessorScript.EXTRA_LIFE_USED
const UNDONE := GameCommandProcessorScript.UNDONE
const NOTHING_TO_UNDO := GameCommandProcessorScript.NOTHING_TO_UNDO
const HINTED := GameCommandProcessorScript.HINTED
const NO_HINT_AVAILABLE := GameCommandProcessorScript.NO_HINT_AVAILABLE
const PAIR_DELETED := GameCommandProcessorScript.PAIR_DELETED
const NO_DELETABLE_PAIR := GameCommandProcessorScript.NO_DELETABLE_PAIR
const SHUFFLED := GameCommandProcessorScript.SHUFFLED
const CONSUMABLE_UNAVAILABLE := GameCommandProcessorScript.CONSUMABLE_UNAVAILABLE
const COMBO_BROKEN := GameCommandProcessorScript.COMBO_BROKEN
const BASE_TRAY_CAPACITY := 4

var definition: Variant
var board: Variant
var tray: Variant
var store: Variant

var status: String:
	get:
		return _state.status

var selection_count: int:
	get:
		return _state.selection_count

var max_tray_occupancy: int:
	get:
		return _state.max_tray_occupancy

var revision: int:
	get:
		return _state.revision

var score: int:
	get:
		return _state.score

var elapsed_time_ms: int:
	get:
		return _state.elapsed_time_ms

var max_multiplier: int:
	get:
		return _state.max_multiplier

var max_combo: int:
	get:
		return _state.max_combo

var modifier_activation_count: int:
	get:
		return _state.modifier_activation_count

var _state: Variant


func _init(game_definition: Variant) -> void:
	definition = game_definition
	_state = GameStateDataScript.new(definition)
	store = GameStoreScript.new(definition, _state)
	board = BoardStateScript.new(definition, _state)
	tray = TrayStateScript.new(definition, _state)


func select_tile(tile_id: String, playback_time_ms: int = -1) -> String:
	var effective_time := elapsed_time_ms if playback_time_ms < 0 else playback_time_ms
	var command := GameCommandScript.new(GameCommandScript.SELECT_TILE, {"tile_id": tile_id}, revision, "", "local", effective_time)
	return store.call("submit_command", command).result


func reveal_tile(tile_id: String, playback_time_ms: int = -1) -> String:
	var effective_time := elapsed_time_ms if playback_time_ms < 0 else playback_time_ms
	var command := GameCommandScript.new(GameCommandScript.REVEAL_TILE, {"tile_id": tile_id}, revision, "", "local", effective_time)
	return store.call("submit_command", command).result


func tap_tile(tile_id: String, playback_time_ms: int = -1) -> String:
	if board.call("is_tile_face_down", tile_id):
		return reveal_tile(tile_id, playback_time_ms)
	if definition.rules_version < 12 \
			and board.call("is_tile_revealed_flipped", tile_id) \
			and not flipped_match_candidate(tile_id).is_empty():
		return reveal_tile(tile_id, playback_time_ms)
	return select_tile(tile_id, playback_time_ms)


func flipped_match_candidate(tile_id: String) -> Dictionary:
	var tile: Variant = definition.get_tile(tile_id)
	if tile == null:
		return {}
	if board.call("is_tile_face_down", tile_id) \
			or definition.rules_version >= 11 and board.call("is_tile_revealed_flipped", tile_id):
		for held_tile_id in _state.tray_tile_ids:
			var held_tile: Variant = definition.get_tile(held_tile_id)
			if held_tile.face.equals(tile.face):
				return {"tile_id": held_tile_id, "zone": GameStateDataScript.ZONE_TRAY}
	if definition.rules_version >= 10:
		return {}
	var candidate_ids: Array[String] = []
	for candidate_id in _state.revealed_flipped_tile_ids:
		if candidate_id != tile_id and _state.tile_zones.get(candidate_id) == GameStateDataScript.ZONE_BOARD:
			candidate_ids.append(candidate_id)
	candidate_ids.sort()
	for candidate_id in candidate_ids:
		if definition.get_tile(candidate_id).face.equals(tile.face):
			return {"tile_id": candidate_id, "zone": GameStateDataScript.ZONE_BOARD}
	return {}


func can_undo() -> bool:
	return store.call("can_undo")


func undo_last_unmatched(playback_time_ms: int = -1) -> String:
	var effective_time := elapsed_time_ms if playback_time_ms < 0 else playback_time_ms
	var command := GameCommandScript.new(GameCommandScript.UNDO, {}, revision, "", "local", effective_time)
	return store.call("submit_command", command).result


func request_hint(playback_time_ms: int = -1) -> String:
	return _submit_consumable(GameCommandScript.HINT, {}, playback_time_ms)


func delete_pair(tile_id: String, playback_time_ms: int = -1) -> String:
	return _submit_consumable(GameCommandScript.DELETE_PAIR, {"tile_id": tile_id}, playback_time_ms)


func shuffle(playback_time_ms: int = -1) -> String:
	return _submit_consumable(GameCommandScript.SHUFFLE, {}, playback_time_ms)


func break_combo_for_locked_tile(tile_id: String, playback_time_ms: int = -1) -> String:
	var effective_time := elapsed_time_ms if playback_time_ms < 0 else playback_time_ms
	var command := GameCommandScript.new(
		GameCommandScript.BREAK_COMBO,
		{"tile_id": tile_id},
		revision,
		"",
		"local",
		effective_time
	)
	return store.call("submit_command", command).result


func consumable_count(consumable_type: String) -> int:
	return int(_state.consumable_counts.get(consumable_type, 0))


func hinted_tile_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_state.hinted_tile_ids)
	return ids


func _submit_consumable(command_type: String, payload: Dictionary, playback_time_ms: int) -> String:
	var effective_time := elapsed_time_ms if playback_time_ms < 0 else playback_time_ms
	var command := GameCommandScript.new(command_type, payload, revision, "", "local", effective_time)
	var result: String = store.call("submit_command", command).result
	if result == SHUFFLED:
		board = BoardStateScript.new(definition, _state)
	return result


func momentum_at(playback_time_ms: int) -> int:
	return MomentumRulesScript.decay(
		_state.momentum_units,
		ModifierRulesScript.momentum_decay_elapsed_ms(_state, playback_time_ms),
		definition.configuration
	)


func multiplier_at(playback_time_ms: int) -> int:
	return MomentumRulesScript.multiplier_for(momentum_at(playback_time_ms), definition.configuration)


func combo_at(playback_time_ms: int) -> int:
	return ComboRulesScript.count_at(_state, playback_time_ms)


func combo_remaining_ms_at(playback_time_ms: int) -> int:
	return ComboRulesScript.remaining_ms_at(_state, playback_time_ms)


func opportunity_analysis() -> Dictionary:
	return BoardOpportunityAnalysisScript.new().call("analyze", definition, _state)


func score_multiplier_basis_points_at(playback_time_ms: int) -> int:
	return ModifierRulesScript.active_score_basis_points(_state, playback_time_ms)


func current_snapshot() -> Variant:
	return store.call("current_state")


func transactions() -> Array:
	return store.call("transactions")


func last_transaction() -> Variant:
	return store.call("last_transaction")


func apply_transaction(transaction: Variant) -> Dictionary:
	var result: Dictionary = store.call("apply_transaction", transaction)
	if bool(result.get("accepted", false)):
		board = BoardStateScript.new(definition, _state)
	return result
