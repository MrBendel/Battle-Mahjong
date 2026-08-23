extends Control
class_name EndGameMenu

signal restart_requested
signal undo_requested

const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")

var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _stats_container: VBoxContainer
var _restart_button: Button
var _undo_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2000

	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.01, 0.02, 0.02, 0.82)
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(wash)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_panel.add_child(content)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	content.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_subtitle_label)

	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_stats_container.add_theme_constant_override("separation", 6)
	content.add_child(_stats_container)

	_restart_button = Button.new()
	_restart_button.name = "RestartButton"
	_restart_button.text = "Play Again"
	_restart_button.focus_mode = Control.FOCUS_ALL
	_restart_button.add_theme_font_size_override("font_size", 16)
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	content.add_child(_restart_button)

	_undo_button = Button.new()
	_undo_button.name = "UndoButton"
	_undo_button.text = "Undo Last Move"
	_undo_button.focus_mode = Control.FOCUS_ALL
	_undo_button.add_theme_font_size_override("font_size", 14)
	_undo_button.pressed.connect(func() -> void: undo_requested.emit())
	content.add_child(_undo_button)

	resized.connect(_layout)
	_layout()


func show_result(game: Variant, elapsed_ms: int) -> void:
	if game == null:
		return
	var is_win := str(game.status) == GameStateDataScript.WON
	var can_undo := bool(game.call("can_undo"))

	if is_win:
		_title_label.text = "🎉 Victory!"
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_subtitle_label.text = "All tiles successfully cleared!"
		_undo_button.visible = false
	else:
		_title_label.text = "💔 Game Over"
		_title_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
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


func _populate_stats(game: Variant, elapsed_ms: int) -> void:
	for child in _stats_container.get_children():
		child.queue_free()

	var seconds := maxi(0, elapsed_ms / 1000)
	var mins := seconds / 60
	var secs := seconds % 60
	var time_str := "%d:%02d" % [mins, secs]

	var score: int = int(game.get("score")) if "score" in game else 0
	var resolved_pairs: int = int(game.tray.resolved_pair_count) if "tray" in game else 0
	var max_combo: int = int(game.get("max_combo")) if "max_combo" in game else 0

	var stats := [
		["Final Score", str(score)],
		["Time Played", time_str],
		["Pairs Matched", str(resolved_pairs)],
		["Peak Combo", "%dx" % max_combo if max_combo > 0 else "None"],
	]

	for stat in stats:
		var hbox := HBoxContainer.new()
		var key_lbl := Label.new()
		key_lbl.text = stat[0]
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_lbl.add_theme_font_size_override("font_size", 14)
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		hbox.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text = stat[1]
		val_lbl.add_theme_font_size_override("font_size", 14)
		val_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		hbox.add_child(val_lbl)

		_stats_container.add_child(hbox)


func _layout() -> void:
	if _panel == null:
		return
	var insets := SafeAreaScript.insets(size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var safe_top := insets.position.y

	var panel_width := minf(320.0, maxf(240.0, size.x - 28.0))
	var panel_height := 280.0 if _undo_button.visible else 240.0
	var top_pos := maxf(14.0 + safe_top, (size.y - panel_height) * 0.35)
	_panel.position = Vector2((size.x - panel_width) * 0.5, top_pos)
	_panel.size = Vector2(panel_width, panel_height)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.14, 0.95)
	style.border_color = Color(0.85, 0.7, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
