extends Control
class_name ConsumablesView

const PORTRAIT_BACKGROUND := preload("res://game-assets/ui/portrait/bottom_tray_background.png")
const HORIZONTAL_PATCH_RATIO := 0.30
const VERTICAL_PATCH_RATIO := 0.50

signal hint_requested
signal delete_pair_requested
signal shuffle_requested
signal undo_requested

var _game: Variant
var _buttons: Dictionary = {}
var _notice: Label
var _background: Panel
var _portrait_background: NinePatchRect
var _title: Label
var _action_rects: Dictionary = {}
var _horizontal_dock := false


func _init(game_state: Variant) -> void:
	_game = game_state


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = Panel.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.17, 0.13, 1.0)
	style.border_color = Color(0.42, 0.62, 0.47, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_background.add_theme_stylebox_override("panel", style)
	add_child(_background)
	_portrait_background = NinePatchRect.new()
	_portrait_background.name = "PortraitBackground"
	_portrait_background.texture = PORTRAIT_BACKGROUND
	_portrait_background.set_patch_margin(SIDE_LEFT, roundi(PORTRAIT_BACKGROUND.get_width() * HORIZONTAL_PATCH_RATIO))
	_portrait_background.set_patch_margin(SIDE_RIGHT, roundi(PORTRAIT_BACKGROUND.get_width() * HORIZONTAL_PATCH_RATIO))
	_portrait_background.set_patch_margin(SIDE_TOP, roundi(PORTRAIT_BACKGROUND.get_height() * VERTICAL_PATCH_RATIO))
	_portrait_background.set_patch_margin(SIDE_BOTTOM, roundi(PORTRAIT_BACKGROUND.get_height() * VERTICAL_PATCH_RATIO))
	_portrait_background.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_portrait_background.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_portrait_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_background)
	_title = Label.new()
	_title.text = "Consumables"
	_title.position = Vector2(12.0, 8.0)
	_title.add_theme_font_size_override("font_size", 20)
	add_child(_title)
	_notice = Label.new()
	_notice.position = Vector2(12.0, 38.0)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_color_override("font_color", Color("d8e4d9"))
	add_child(_notice)
	_add_button("hint", "Hint", func() -> void: hint_requested.emit())
	_add_button("delete_pair", "Delete Pair", func() -> void: delete_pair_requested.emit())
	_add_button("shuffle", "Shuffle", func() -> void: shuffle_requested.emit())
	_add_button("undo", "Undo", func() -> void: undo_requested.emit())
	resized.connect(_layout)
	refresh()
	_layout()


func set_game_state(game_state: Variant) -> void:
	_game = game_state
	show_notice("")
	refresh()


func reset_input_state() -> void:
	for button in _buttons.values():
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_add_button("hint", "Hint", func() -> void: hint_requested.emit())
	_add_button("delete_pair", "Delete Pair", func() -> void: delete_pair_requested.emit())
	_add_button("shuffle", "Shuffle", func() -> void: shuffle_requested.emit())
	_add_button("undo", "Undo", func() -> void: undo_requested.emit())
	refresh()
	_layout()


func refresh() -> void:
	if _buttons.is_empty():
		return
	for consumable_type in _buttons:
		var button: Button = _buttons[consumable_type]
		var label: String = str(button.get_meta("label"))
		if size.y <= 180.0 and consumable_type == "delete_pair":
			label = "Delete"
		button.text = "%s (%d)" % [label, _game.call("consumable_count", consumable_type)]
		button.disabled = _game.status != "playing" \
			or _game.call("consumable_count", consumable_type) <= 0 \
			or consumable_type == "undo" and not _game.call("can_undo")


func show_notice(message: String) -> void:
	if _notice != null:
		_notice.text = message
		_layout()


func set_action_rects(rects: Dictionary) -> void:
	_action_rects = rects.duplicate(true)
	_layout()


func clear_action_rects() -> void:
	_action_rects.clear()
	_layout()


func set_horizontal_dock(enabled: bool) -> void:
	_horizontal_dock = enabled
	_layout()


func _add_button(consumable_type: String, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = consumable_type.capitalize().replace("_", "")
	button.set_meta("label", label)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	add_child(button)
	_buttons[consumable_type] = button


func _layout() -> void:
	if _buttons.is_empty():
		return
	if not _action_rects.is_empty():
		_background.visible = false
		_portrait_background.visible = false
		_title.visible = false
		_notice.visible = false
		for consumable_type in _buttons:
			var rect: Rect2 = _action_rects.get(consumable_type, Rect2())
			_buttons[consumable_type].position = rect.position
			_buttons[consumable_type].size = rect.size
			_buttons[consumable_type].add_theme_font_size_override("font_size", 16)
		refresh()
		return
	_background.visible = not _horizontal_dock
	_portrait_background.visible = _horizontal_dock
	if _horizontal_dock:
		_layout_portrait_background()
	_title.visible = false
	_notice.size = Vector2(maxf(100.0, size.x - 24.0), 46.0)
	var vertical := not _horizontal_dock and size.y > 180.0 and size.y > size.x
	_notice.visible = vertical
	var types := ["hint", "delete_pair", "shuffle", "undo"]
	if vertical:
		var button_height := 42.0
		var button_top := maxf(96.0, _notice.position.y + _notice.get_combined_minimum_size().y + 8.0)
		for index in types.size():
			_buttons[types[index]].position = Vector2(12.0, button_top + index * 50.0)
			_buttons[types[index]].size = Vector2(maxf(80.0, size.x - 24.0), button_height)
	else:
		var gap := 8.0
		var available_width := maxf(240.0, size.x - 24.0 - gap * float(types.size() - 1))
		var button_width := available_width / float(types.size())
		var button_x := 12.0
		for index in types.size():
			_buttons[types[index]].position = Vector2(button_x, 8.0)
			_buttons[types[index]].size = Vector2(button_width, maxf(44.0, size.y - 16.0))
			_buttons[types[index]].add_theme_font_size_override("font_size", 14)
			button_x += button_width + gap
	refresh()


func _layout_portrait_background() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var source_size := PORTRAIT_BACKGROUND.get_size()
	var art_scale := size.y / source_size.y
	_portrait_background.position = Vector2.ZERO
	_portrait_background.size = Vector2(size.x / art_scale, source_size.y)
	_portrait_background.scale = Vector2.ONE * art_scale
