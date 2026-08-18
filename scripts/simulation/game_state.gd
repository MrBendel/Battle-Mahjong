extends RefCounted

const TrayStateScript := preload("res://scripts/simulation/tray_state.gd")

const PLAYING := "playing"
const WON := "won"
const LOST := "lost"

const SELECTED := "selected"
const PAIR_RESOLVED := "pair_resolved"
const INVALID_SELECTION := "invalid_selection"
const GAME_OVER := "game_over"

var board: Variant
var tray: Variant
var status := PLAYING
var selection_count := 0
var max_tray_occupancy := 0

func _init(initial_board: Variant, tray_capacity: int = 4) -> void:
	board = initial_board
	tray = TrayStateScript.new(tray_capacity)


func select_tile(tile_id: String) -> String:
	if status != PLAYING:
		return GAME_OVER

	var tile: Variant = board.call("take_tile", tile_id)
	if tile == null:
		return INVALID_SELECTION

	selection_count += 1
	var tray_result: String = tray.call("add_tile", tile)
	max_tray_occupancy = maxi(max_tray_occupancy, tray.tiles.size())

	if tray_result == TrayStateScript.FAILED:
		status = LOST
		return GAME_OVER

	if board.call("active_tiles").is_empty() and tray.tiles.is_empty():
		status = WON

	if tray_result == TrayStateScript.MATCHED:
		return PAIR_RESOLVED

	return SELECTED
