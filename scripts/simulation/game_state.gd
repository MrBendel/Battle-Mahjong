extends RefCounted

const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const GameCommandScript := preload("res://scripts/simulation/game_command.gd")
const GameCommandProcessorScript := preload("res://scripts/simulation/game_command_processor.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const GameStoreScript := preload("res://scripts/simulation/game_store.gd")
const MomentumRulesScript := preload("res://scripts/simulation/momentum_rules.gd")
const TrayStateScript := preload("res://scripts/simulation/tray_state.gd")

const PLAYING := GameStateDataScript.PLAYING
const WON := GameStateDataScript.WON
const LOST := GameStateDataScript.LOST

const SELECTED := GameCommandProcessorScript.SELECTED
const PAIR_RESOLVED := GameCommandProcessorScript.PAIR_RESOLVED
const INVALID_SELECTION := GameCommandProcessorScript.INVALID_SELECTION
const GAME_OVER := GameCommandProcessorScript.GAME_OVER
const UNDONE := GameCommandProcessorScript.UNDONE
const NOTHING_TO_UNDO := GameCommandProcessorScript.NOTHING_TO_UNDO
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


func can_undo() -> bool:
	return status == PLAYING and not _state.tray_tile_ids.is_empty()


func undo_last_unmatched(playback_time_ms: int = -1) -> String:
	var effective_time := elapsed_time_ms if playback_time_ms < 0 else playback_time_ms
	var command := GameCommandScript.new(GameCommandScript.UNDO, {}, revision, "", "local", effective_time)
	return store.call("submit_command", command).result


func momentum_at(playback_time_ms: int) -> int:
	return MomentumRulesScript.decay(
		_state.momentum_units,
		maxi(0, playback_time_ms - _state.elapsed_time_ms),
		definition.configuration
	)


func multiplier_at(playback_time_ms: int) -> int:
	return MomentumRulesScript.multiplier_for(momentum_at(playback_time_ms), definition.configuration)


func current_snapshot() -> Variant:
	return store.call("current_state")


func transactions() -> Array:
	return store.call("transactions")


func last_transaction() -> Variant:
	return store.call("last_transaction")


func apply_transaction(transaction: Variant) -> Dictionary:
	return store.call("apply_transaction", transaction)
