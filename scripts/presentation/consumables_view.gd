extends Control
class_name ConsumablesView

signal hint_requested
signal delete_pair_requested
signal shuffle_requested

var _game: Variant
var _buttons: Dictionary = {}
var _notice: Label


func _init(game_state: Variant) -> void:
	_game = game_state


func _ready() -> void:
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.17, 0.13, 1.0)
	style.border_color = Color(0.42, 0.62, 0.47, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	background.add_theme_stylebox_override("panel", style)
	add_child(background)
	var title := Label.new()
	title.text = "Consumables"
	title.position = Vector2(12.0, 8.0)
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)
	_notice = Label.new()
	_notice.position = Vector2(12.0, 38.0)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_color_override("font_color", Color("d8e4d9"))
	add_child(_notice)
	_add_button("hint", "Hint", func() -> void: hint_requested.emit())
	_add_button("delete_pair", "Delete Pair", func() -> void: delete_pair_requested.emit())
	_add_button("shuffle", "Shuffle", func() -> void: shuffle_requested.emit())
	resized.connect(_layout)
	refresh()
	_layout()


func set_game_state(game_state: Variant) -> void:
	_game = game_state
	show_notice("")
	refresh()


func refresh() -> void:
	if _buttons.is_empty():
		return
	for consumable_type in _buttons:
		var button: Button = _buttons[consumable_type]
		button.text = "%s (%d)" % [button.get_meta("label"), _game.call("consumable_count", consumable_type)]
		button.disabled = _game.status != "playing" or _game.call("consumable_count", consumable_type) <= 0


func show_notice(message: String) -> void:
	if _notice != null:
		_notice.text = message


func _add_button(consumable_type: String, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.set_meta("label", label)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	add_child(button)
	_buttons[consumable_type] = button


func _layout() -> void:
	if _buttons.is_empty():
		return
	_notice.size = Vector2(maxf(100.0, size.x - 24.0), 46.0)
	var vertical := size.y > 180.0
	_notice.visible = vertical
	var types := ["hint", "delete_pair", "shuffle"]
	if vertical:
		var button_height := 42.0
		for index in types.size():
			_buttons[types[index]].position = Vector2(12.0, 88.0 + index * 50.0)
			_buttons[types[index]].size = Vector2(maxf(80.0, size.x - 24.0), button_height)
	else:
		var gap := 8.0
		var button_width := maxf(70.0, (size.x - 24.0 - gap * 2.0) / 3.0)
		for index in types.size():
			_buttons[types[index]].position = Vector2(12.0 + index * (button_width + gap), maxf(42.0, size.y - 44.0))
			_buttons[types[index]].size = Vector2(button_width, 36.0)
