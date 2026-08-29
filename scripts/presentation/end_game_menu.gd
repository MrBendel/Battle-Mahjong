extends "res://scripts/presentation/game_overlay.gd"
class_name EndGameMenu

signal restart_requested
signal undo_requested

const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const PANEL_REFERENCE_WIDTH := 330.0
const PANEL_REFERENCE_HEIGHT := 340.0
const PANEL_REFERENCE_HEIGHT_WITH_UNDO := 394.0

var _title_label: Label
var _subtitle_label: Label
var _stats_container: VBoxContainer
var _restart_button: Button
var _undo_button: Button
var _stat_labels: Array[Label] = []


func show_result(game: Variant, elapsed_ms: int) -> void:
	if game == null:
		return
	var is_win := str(game.status) == GameStateDataScript.WON
	var can_undo := bool(game.call("can_undo"))

	if is_win:
		_title_label.text = "VICTORY!"
		_title_label.add_theme_color_override("font_color", Color("f5d56d"))
		_subtitle_label.text = "All tiles successfully cleared!"
		_undo_button.visible = false
	else:
		_title_label.text = "GAME OVER"
		_title_label.add_theme_color_override("font_color", Color("ef7582"))
		_subtitle_label.text = "Tray is full with no matching pairs."
		_undo_button.visible = can_undo

	_populate_stats(game, elapsed_ms)
	visible = true
	_restart_button.grab_focus()
	_layout()


func close() -> void:
	_restart_button.release_focus()
	_undo_button.release_focus()
	visible = false


func _panel_name() -> String:
	return "EndGamePanel"


func _panel_reference_size() -> Vector2:
	return Vector2(
		PANEL_REFERENCE_WIDTH,
		PANEL_REFERENCE_HEIGHT_WITH_UNDO if _undo_button != null and _undo_button.visible \
			else PANEL_REFERENCE_HEIGHT
	)


func _build_overlay_content() -> void:
	_title_label = _make_title("")
	_title_label.name = "TitleLabel"
	_content.add_child(_title_label)
	_content.add_child(_make_rule())

	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_override("font", REGULAR_FONT)
	_subtitle_label.add_theme_color_override("font_color", Color("d5decf"))
	_content.add_child(_subtitle_label)

	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_content.add_child(_stats_container)

	_restart_button = _make_command_button("PLAY AGAIN")
	_restart_button.name = "RestartButton"
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_content.add_child(_restart_button)

	_undo_button = _make_command_button("UNDO LAST MOVE")
	_undo_button.name = "UndoButton"
	_undo_button.pressed.connect(func() -> void: undo_requested.emit())
	_content.add_child(_undo_button)


func _populate_stats(game: Variant, elapsed_ms: int) -> void:
	for child in _stats_container.get_children():
		_stats_container.remove_child(child)
		child.queue_free()
	_stat_labels.clear()

	var seconds := maxi(0, elapsed_ms / 1000)
	var mins := seconds / 60
	var secs := seconds % 60
	var time_str := "%d:%02d" % [mins, secs]
	var score: int = int(game.get("score")) if "score" in game else 0
	var resolved_pairs: int = int(game.tray.resolved_pair_count) if "tray" in game else 0
	var max_combo: int = int(game.get("max_combo")) if "max_combo" in game else 0
	var stats := [
		["FINAL SCORE", str(score)],
		["TIME PLAYED", time_str],
		["PAIRS MATCHED", str(resolved_pairs)],
		["PEAK COMBO", "%dx" % max_combo if max_combo > 0 else "NONE"],
	]

	for stat in stats:
		var row := HBoxContainer.new()
		var key_label := Label.new()
		key_label.text = stat[0]
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_label.add_theme_font_override("font", REGULAR_FONT)
		key_label.add_theme_color_override("font_color", Color("aebdb1"))
		row.add_child(key_label)
		var value_label := Label.new()
		value_label.text = stat[1]
		value_label.add_theme_font_override("font", BOLD_FONT)
		value_label.add_theme_color_override("font_color", Color("f5e4a4"))
		row.add_child(value_label)
		_stats_container.add_child(row)
		_stat_labels.append(key_label)
		_stat_labels.append(value_label)


func _layout_overlay_content(scale_factor: float) -> void:
	_apply_title_layout(_title_label, scale_factor)
	_subtitle_label.custom_minimum_size = Vector2(240.0, 38.0) * scale_factor
	_subtitle_label.add_theme_font_size_override("font_size", roundi(15.0 * scale_factor))
	_stats_container.add_theme_constant_override("separation", roundi(6.0 * scale_factor))
	for row in _stats_container.get_children():
		row.add_theme_constant_override("separation", roundi(12.0 * scale_factor))
	for label in _stat_labels:
		label.add_theme_font_size_override("font_size", roundi(15.0 * scale_factor))
	_apply_command_button_layout(_restart_button, scale_factor)
	_apply_command_button_layout(_undo_button, scale_factor, 17.0)
