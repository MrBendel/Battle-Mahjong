extends Control
class_name ConsumablesView

const PORTRAIT_BACKGROUND := preload("res://game-assets/ui/portrait/bottom_tray_background.png")
const PORTRAIT_TILE_CAP := preload("res://game-assets/ui/portrait/bottom_tray_tile_cap.png")
const PORTRAIT_NUMBER_BACKGROUND := preload("res://game-assets/ui/portrait/bottom_tray_number_bg.png")
const PORTRAIT_FONT := preload("res://assets/fonts/mila-script-sans-bold.ttf")
const PORTRAIT_ICONS := {
	"hint": preload("res://game-assets/ui/portrait/bottom_tray_icon_hint.png"),
	"shuffle": preload("res://game-assets/ui/portrait/bottom_tray_icon_shuffle.png"),
	"delete_pair": preload("res://game-assets/ui/portrait/bottom_tray_icon_delete.png"),
	"undo": preload("res://game-assets/ui/portrait/bottom_tray_icon_undo.png"),
}
const HORIZONTAL_PATCH_RATIO := 0.30
const VERTICAL_PATCH_RATIO := 0.50
const PORTRAIT_REFERENCE_SIZE := Vector2(366.0, 149.2696)
const PORTRAIT_BACKGROUND_RECT := Rect2(0.0, 7.2696, 366.0, 136.0)
const PORTRAIT_ACTION_TYPES := ["hint", "shuffle", "delete_pair", "undo"]
const PORTRAIT_ACTION_X := [18.1238, 100.1843, 181.9931, 263.8019]
const PORTRAIT_LABELS := ["HINT", "Shuffle", "Delete", "Undo"]
const PORTRAIT_LABEL_RECTS := [
	Rect2(41.7854, 19.1307, 34.7373, 19.1307),
	Rect2(113.0220, 19.1307, 56.1334, 19.1307),
	Rect2(200.3686, 19.1307, 47.0715, 19.1307),
	Rect2(285.9532, 19.1307, 37.7579, 19.1307),
]

signal hint_requested
signal delete_pair_requested
signal shuffle_requested
signal undo_requested

var _game: Variant
var _buttons: Dictionary = {}
var _portrait_art: Dictionary = {}
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
	_add_button("shuffle", "Shuffle", func() -> void: shuffle_requested.emit())
	_add_button("delete_pair", "Delete Pair", func() -> void: delete_pair_requested.emit())
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
	_portrait_art.clear()
	_add_button("hint", "Hint", func() -> void: hint_requested.emit())
	_add_button("shuffle", "Shuffle", func() -> void: shuffle_requested.emit())
	_add_button("delete_pair", "Delete Pair", func() -> void: delete_pair_requested.emit())
	_add_button("undo", "Undo", func() -> void: undo_requested.emit())
	refresh()
	_layout()


func refresh() -> void:
	if _buttons.is_empty():
		return
	for consumable_type in _buttons:
		var button: Button = _buttons[consumable_type]
		var count: int = _game.call("consumable_count", consumable_type)
		var label: String = str(button.get_meta("label"))
		if size.y <= 180.0 and consumable_type == "delete_pair":
			label = "Delete"
		button.text = "" if _horizontal_dock and _action_rects.is_empty() else "%s (%d)" % [label, count]
		button.disabled = _game.status != "playing" \
			or count <= 0 \
			or consumable_type == "undo" and not _game.call("can_undo")
		var art: Dictionary = _portrait_art[consumable_type]
		art.quantity.text = str(count)
		art.root.modulate = Color(0.48, 0.5, 0.49, 0.78) if button.disabled else Color.WHITE


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
	_portrait_art[consumable_type] = _create_portrait_art(button, consumable_type)


func _create_portrait_art(button: Button, consumable_type: String) -> Dictionary:
	var root := Control.new()
	root.name = "PortraitArt"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(root)
	var cap := TextureRect.new()
	cap.name = "TileCap"
	cap.texture = PORTRAIT_TILE_CAP
	cap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cap.stretch_mode = TextureRect.STRETCH_SCALE
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cap)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = PORTRAIT_ICONS[consumable_type]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	var number_background := TextureRect.new()
	number_background.name = "NumberBackground"
	number_background.texture = PORTRAIT_NUMBER_BACKGROUND
	number_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	number_background.stretch_mode = TextureRect.STRETCH_SCALE
	number_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(number_background)
	var title := Label.new()
	title.name = "Title"
	title.text = PORTRAIT_LABELS[PORTRAIT_ACTION_TYPES.find(consumable_type)]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", PORTRAIT_FONT)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("f2dab2"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var quantity := Label.new()
	quantity.name = "Quantity"
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity.add_theme_font_override("font", PORTRAIT_FONT)
	quantity.add_theme_font_size_override("font_size", 16)
	quantity.add_theme_color_override("font_color", Color("f2dab2"))
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(quantity)
	return {
		"root": root,
		"cap": cap,
		"icon": icon,
		"number_background": number_background,
		"title": title,
		"quantity": quantity,
	}


func _layout() -> void:
	if _buttons.is_empty():
		return
	if not _action_rects.is_empty():
		_background.visible = false
		_portrait_background.visible = false
		_title.visible = false
		_notice.visible = false
		for consumable_type in _buttons:
			_set_portrait_art_visible(consumable_type, false)
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
		_layout_portrait_actions()
	_title.visible = false
	_notice.size = Vector2(maxf(100.0, size.x - 24.0), 46.0)
	var vertical := not _horizontal_dock and size.y > 180.0 and size.y > size.x
	_notice.visible = vertical
	var types := ["hint", "delete_pair", "shuffle", "undo"]
	if vertical:
		var button_height := 42.0
		var button_top := maxf(96.0, _notice.position.y + _notice.get_combined_minimum_size().y + 8.0)
		for index in types.size():
			_set_portrait_art_visible(types[index], false)
			_buttons[types[index]].position = Vector2(12.0, button_top + index * 50.0)
			_buttons[types[index]].size = Vector2(maxf(80.0, size.x - 24.0), button_height)
	elif not _horizontal_dock:
		var gap := 8.0
		var available_width := maxf(240.0, size.x - 24.0 - gap * float(types.size() - 1))
		var button_width := available_width / float(types.size())
		var button_x := 12.0
		for index in types.size():
			_set_portrait_art_visible(types[index], false)
			_buttons[types[index]].position = Vector2(button_x, 8.0)
			_buttons[types[index]].size = Vector2(button_width, maxf(44.0, size.y - 16.0))
			_buttons[types[index]].add_theme_font_size_override("font_size", 14)
			button_x += button_width + gap
	refresh()


func _layout_portrait_background() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var component_scale := minf(size.x / PORTRAIT_REFERENCE_SIZE.x, size.y / PORTRAIT_REFERENCE_SIZE.y)
	var origin := (size - PORTRAIT_REFERENCE_SIZE * component_scale) * 0.5
	var target_rect := Rect2(origin + PORTRAIT_BACKGROUND_RECT.position * component_scale, PORTRAIT_BACKGROUND_RECT.size * component_scale)
	var source_size := PORTRAIT_BACKGROUND.get_size()
	var art_scale := target_rect.size.y / source_size.y
	_portrait_background.position = target_rect.position
	_portrait_background.size = Vector2(target_rect.size.x / art_scale, source_size.y)
	_portrait_background.scale = Vector2.ONE * art_scale


func _layout_portrait_actions() -> void:
	var component_scale := minf(size.x / PORTRAIT_REFERENCE_SIZE.x, size.y / PORTRAIT_REFERENCE_SIZE.y)
	var origin := (size - PORTRAIT_REFERENCE_SIZE * component_scale) * 0.5
	for index in PORTRAIT_ACTION_TYPES.size():
		var consumable_type: String = PORTRAIT_ACTION_TYPES[index]
		var button: Button = _buttons[consumable_type]
		var action_x: float = PORTRAIT_ACTION_X[index]
		button.position = origin + Vector2(action_x, 14.0) * component_scale
		# Keep neighboring touch targets fractionally separated while their artwork meets exactly.
		button.size = Vector2(81.6, 113.0) * component_scale
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var art: Dictionary = _portrait_art[consumable_type]
		art.root.visible = true
		art.root.position = -Vector2(action_x, 14.0) * component_scale
		art.root.size = PORTRAIT_REFERENCE_SIZE * component_scale
		art.cap.position = Vector2(action_x, 35.4924) * component_scale
		art.cap.size = Vector2(82.0605, 75.0124) * component_scale
		var icon_rect := _portrait_icon_rect(index)
		art.icon.position = icon_rect.position * component_scale
		art.icon.size = icon_rect.size * component_scale
		art.number_background.position = Vector2(action_x + 15.8583, 89.1087) * component_scale
		art.number_background.size = Vector2(50.0922, 33.4787) * component_scale
		var label_rect: Rect2 = PORTRAIT_LABEL_RECTS[index]
		art.title.position = label_rect.position * component_scale
		art.title.size = label_rect.size * component_scale
		art.title.add_theme_font_size_override("font_size", maxi(9, roundi(12.083 * component_scale)))
		art.quantity.position = Vector2(action_x + 15.8583, 89.1087) * component_scale
		art.quantity.size = Vector2(50.0922, 27.0) * component_scale
		art.quantity.add_theme_font_size_override("font_size", maxi(11, roundi(16.11 * component_scale)))


func _portrait_icon_rect(index: int) -> Rect2:
	var rects := [
		Rect2(46.3164, 45.8129, 25.4237, 35.7442),
		Rect2(123.8459, 45.8129, 34.7373, 33.2270),
		Rect2(205.4030, 48.3301, 35.2407, 33.2270),
		Rect2(287.4636, 48.3301, 34.7373, 33.2270),
	]
	return rects[index]


func _set_portrait_art_visible(consumable_type: String, visible: bool) -> void:
	_portrait_art[consumable_type].root.visible = visible
	if not visible:
		var button: Button = _buttons[consumable_type]
		for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.remove_theme_stylebox_override(style_name)
