extends Control
class_name ConsumablesView

const PresentationScaleScript := preload("res://scripts/presentation/presentation_scale.gd")
const GameplayThemeScript := preload("res://scripts/presentation/gameplay_theme.gd")
const ConsumableButtonScript := preload("res://scripts/presentation/consumable_button.gd")
const PORTRAIT_REFERENCE_SIZE := Vector2(400.0, 120.0)
const VERTICAL_REFERENCE_SIZE := Vector2(78.0, 320.0)
const PORTRAIT_BACKGROUND_RECT := Rect2(0.0, 8.0, 400.0, 104.0)
const PORTRAIT_CAP_WIDTH := 36.0
const PORTRAIT_ACTION_MARGIN := 12.0
const PORTRAIT_COMPONENT_Y_OFFSET := 0.0
const PORTRAIT_ACTION_TYPES := ["hint", "shuffle", "delete_pair", "undo"]
const PORTRAIT_STACK_OFFSET := Vector2(0.0, -5.0)

signal hint_requested
signal delete_pair_requested
signal shuffle_requested
signal undo_requested

var _game: Variant
var _gameplay_theme: Resource
var _buttons: Dictionary = {}
var _portrait_art: Dictionary = {}
var _notice: Label
var _background: Panel
var _portrait_tray_shadow: Panel
var _portrait_background: Control
var _portrait_background_pieces: Array[TextureRect] = []
var _presented_action_types: Array[String] = ["hint", "shuffle", "delete_pair", "undo"]
var _title: Label
var _action_rects: Dictionary = {}
var _horizontal_dock := false
var _vertical_dock := false


func _init(game_state: Variant, gameplay_theme: Resource = null) -> void:
	_game = game_state
	_gameplay_theme = GameplayThemeScript.new() if gameplay_theme == null else gameplay_theme


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
	_portrait_tray_shadow = Panel.new()
	_portrait_tray_shadow.name = "PortraitTrayShadow"
	_portrait_tray_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray_shadow_style := StyleBoxFlat.new()
	tray_shadow_style.bg_color = Color(0.0, 0.0, 0.0, 0.01)
	tray_shadow_style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	tray_shadow_style.shadow_size = 8
	tray_shadow_style.shadow_offset = Vector2(0.0, 5.0)
	tray_shadow_style.set_corner_radius_all(22)
	_portrait_tray_shadow.add_theme_stylebox_override("panel", tray_shadow_style)
	add_child(_portrait_tray_shadow)
	_portrait_background = Control.new()
	_portrait_background.name = "PortraitBackground"
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
	_rebuild_portrait_background()
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
	for consumable_type in _buttons:
		_buttons[consumable_type].visible = _presented_action_types.has(consumable_type)
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
		var visible_layers := _stack_layer_count(count)
		for index in art.tile_layers.size():
			art.tile_layers[index].visible = index >= art.tile_layers.size() - visible_layers
		art.root.modulate = Color(0.48, 0.5, 0.49, 0.78) if button.disabled else Color.WHITE


func _stack_layer_count(count: int) -> int:
	return clampi(count, 1, 3)


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


func set_presented_action_types(action_types: Array) -> void:
	var accepted: Array[String] = []
	for consumable_type in action_types:
		if _buttons.has(consumable_type) and not accepted.has(consumable_type):
			accepted.append(consumable_type)
	if accepted.is_empty():
		return
	_presented_action_types = accepted
	for consumable_type in _buttons:
		_buttons[consumable_type].visible = _presented_action_types.has(consumable_type)
	_rebuild_portrait_background()
	_layout()


func set_horizontal_dock(enabled: bool) -> void:
	_horizontal_dock = enabled
	_vertical_dock = false
	_layout()


func set_dock_layout(vertical: bool) -> void:
	_horizontal_dock = true
	_vertical_dock = vertical
	_layout()


func disarm_all_gestures() -> void:
	for button in _buttons.values():
		if button != null and button.has_method("disarm"):
			button.call("disarm")


func _add_button(consumable_type: String, label: String, callback: Callable) -> void:
	var button: Button = ConsumableButtonScript.new()
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
	var tile_shadow := TextureRect.new()
	tile_shadow.name = "TileShadow"
	tile_shadow.texture = _load_texture(str(_gameplay_theme.consumable_tile_path))
	tile_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile_shadow.modulate = Color(0.0, 0.0, 0.0, 0.52)
	tile_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tile_shadow)
	var tile_layers: Array[TextureRect] = []
	for index in 3:
		var tile := TextureRect.new()
		tile.name = "TileLayer%d" % index
		tile.texture = _load_texture(str(_gameplay_theme.consumable_tile_path))
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tile)
		tile_layers.append(tile)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = _load_texture(_gameplay_theme.call("consumable_icon_path", consumable_type))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	var quantity := Label.new()
	quantity.name = "Quantity"
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity.add_theme_font_override("font", _load_font(str(_gameplay_theme.bold_font_path)))
	quantity.add_theme_font_size_override("font_size", 16)
	quantity.add_theme_color_override("font_color", Color("111714"))
	quantity.add_theme_color_override("font_outline_color", Color("f7e6c7"))
	quantity.add_theme_constant_override("outline_size", 1)
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(quantity)
	return {
		"root": root,
		"tile_shadow": tile_shadow,
		"cap": tile_layers.back(),
		"tile_layers": tile_layers,
		"icon": icon,
		"quantity": quantity,
	}


func _add_portrait_background_piece(piece_name: String, asset_path: String) -> void:
	var piece := TextureRect.new()
	piece.name = piece_name
	piece.texture = _load_texture(asset_path)
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_SCALE
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_background.add_child(piece)
	_portrait_background_pieces.append(piece)


func _rebuild_portrait_background() -> void:
	for piece in _portrait_background_pieces:
		_portrait_background.remove_child(piece)
		piece.queue_free()
	_portrait_background_pieces.clear()
	_add_portrait_background_piece("LeftCap", str(_gameplay_theme.consumables_left_cap_path))
	for index in _presented_action_types.size():
		_add_portrait_background_piece("Repeat%d" % index, str(_gameplay_theme.consumables_repeat_path))
	_add_portrait_background_piece("RightCap", str(_gameplay_theme.consumables_right_cap_path))


func _layout() -> void:
	if _buttons.is_empty():
		return
	if not _action_rects.is_empty():
		_background.visible = false
		_portrait_tray_shadow.visible = false
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
	_portrait_tray_shadow.visible = false
	_portrait_background.visible = false
	if _horizontal_dock:
		if _vertical_dock:
			_layout_vertical_actions()
		else:
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
	_portrait_background.visible = true
	var component_scale := PresentationScaleScript.limiting_scale(size, PORTRAIT_REFERENCE_SIZE)
	var origin := (size - PORTRAIT_REFERENCE_SIZE * component_scale) * 0.5 \
		+ Vector2(0.0, PORTRAIT_COMPONENT_Y_OFFSET * component_scale)
	var target_rect := Rect2(origin + PORTRAIT_BACKGROUND_RECT.position * component_scale, PORTRAIT_BACKGROUND_RECT.size * component_scale)
	_portrait_background.position = target_rect.position
	_portrait_background.size = target_rect.size
	_portrait_tray_shadow.visible = true
	_portrait_tray_shadow.position = target_rect.position + Vector2(4.0, 4.0) * component_scale
	_portrait_tray_shadow.size = target_rect.size - Vector2(8.0, 8.0) * component_scale
	var cap_width := PORTRAIT_CAP_WIDTH * component_scale
	var repeat_width := (target_rect.size.x - cap_width * 2.0) / float(_presented_action_types.size())
	var piece_x := 0.0
	for index in _portrait_background_pieces.size():
		var piece := _portrait_background_pieces[index]
		var piece_width := cap_width if index == 0 or index == _portrait_background_pieces.size() - 1 else repeat_width
		var seam_overlap := 0.0 if index == 0 else maxf(1.0, component_scale)
		piece.position = Vector2(piece_x - seam_overlap, 0.0)
		piece.size = Vector2(piece_width + seam_overlap, target_rect.size.y)
		piece_x += piece_width


func _layout_portrait_actions() -> void:
	var component_scale := PresentationScaleScript.limiting_scale(size, PORTRAIT_REFERENCE_SIZE)
	var origin := (size - PORTRAIT_REFERENCE_SIZE * component_scale) * 0.5 \
		+ Vector2(0.0, PORTRAIT_COMPONENT_Y_OFFSET * component_scale)
	for index in _presented_action_types.size():
		var consumable_type: String = _presented_action_types[index]
		var button: Button = _buttons[consumable_type]
		var repeat_width := (PORTRAIT_BACKGROUND_RECT.size.x - PORTRAIT_ACTION_MARGIN * 2.0) / float(_presented_action_types.size())
		var action_x := PORTRAIT_ACTION_MARGIN + repeat_width * float(index)
		button.position = origin + Vector2(action_x, 8.0) * component_scale
		button.size = Vector2(repeat_width, 84.0) * component_scale
		if button.has_method("set_scale_factor"):
			button.call("set_scale_factor", component_scale)
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var art: Dictionary = _portrait_art[consumable_type]
		art.root.visible = true
		art.root.position = Vector2.ZERO
		art.root.size = button.size
		var tile_width := minf(76.0, repeat_width - 4.0)
		var tile_x := (repeat_width - tile_width) * 0.5
		var tile_rect := Rect2(Vector2(tile_x, 17.0) * component_scale, Vector2(tile_width, 82.0) * component_scale)
		_layout_tile_stack(art, tile_rect, component_scale)
		art.icon.position = Vector2(tile_x + (tile_width - 43.0) * 0.5, 33.0) * component_scale
		art.icon.size = Vector2(43.0, 43.0) * component_scale
		art.quantity.position = Vector2(tile_x + tile_width - 24.0, 73.0) * component_scale
		art.quantity.size = Vector2(20.0, 22.0) * component_scale
		art.quantity.add_theme_font_size_override("font_size", maxi(12, roundi(17.0 * component_scale)))


func _layout_vertical_actions() -> void:
	var component_scale := PresentationScaleScript.limiting_scale(size, VERTICAL_REFERENCE_SIZE)
	var origin := (size - VERTICAL_REFERENCE_SIZE * component_scale) * 0.5
	for index in PORTRAIT_ACTION_TYPES.size():
		var consumable_type: String = PORTRAIT_ACTION_TYPES[index]
		var action_y := 2.0 + float(index) * 79.0
		var button: Button = _buttons[consumable_type]
		button.position = origin + Vector2(4.0, action_y) * component_scale
		button.size = Vector2(70.0, 76.0) * component_scale
		if button.has_method("set_scale_factor"):
			button.call("set_scale_factor", component_scale)
		for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		var art: Dictionary = _portrait_art[consumable_type]
		art.root.visible = true
		art.root.position = Vector2.ZERO
		art.root.size = button.size
		_layout_tile_stack(art, Rect2(Vector2(4.0, 4.0) * component_scale, Vector2(62.0, 68.0) * component_scale), component_scale)
		art.icon.position = Vector2(22.0, 20.0) * component_scale
		art.icon.size = Vector2(34.0, 34.0) * component_scale
		art.quantity.position = Vector2(47.0, 51.0) * component_scale
		art.quantity.size = Vector2(19.0, 20.0) * component_scale
		art.quantity.add_theme_font_size_override("font_size", maxi(11, roundi(15.0 * component_scale)))


func _layout_tile_stack(art: Dictionary, front_rect: Rect2, component_scale: float) -> void:
	art.tile_shadow.position = front_rect.position + Vector2(0.0, 7.0) * component_scale
	art.tile_shadow.size = front_rect.size
	for index in art.tile_layers.size():
		var depth := float(art.tile_layers.size() - 1 - index)
		art.tile_layers[index].position = front_rect.position + PORTRAIT_STACK_OFFSET * depth * component_scale
		art.tile_layers[index].size = front_rect.size


func _set_portrait_art_visible(consumable_type: String, visible: bool) -> void:
	_portrait_art[consumable_type].root.visible = visible
	if not visible:
		var button: Button = _buttons[consumable_type]
		for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.remove_theme_stylebox_override(style_name)


static func _load_texture(asset_path: String) -> Texture2D:
	if ResourceLoader.exists(asset_path):
		return load(asset_path) as Texture2D
	elif FileAccess.file_exists(asset_path):
		var image := Image.load_from_file(asset_path)
		if image != null:
			return ImageTexture.create_from_image(image)
	return null


static func _load_font(asset_path: String) -> Font:
	if ResourceLoader.exists(asset_path):
		return load(asset_path) as Font
	return null
