extends Control
class_name ModifierLoadoutPicker

signal start_requested(loadout: Array)

const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const PresentationScaleScript := preload("res://scripts/presentation/presentation_scale.gd")
const ModifierLoadoutScript := preload("res://scripts/simulation/modifier_loadout.gd")
const BOLD_FONT := preload("res://assets/fonts/mila-script-sans-bold-tight.tres")
const REGULAR_FONT := preload("res://assets/fonts/mila-script-sans-regular-tight.tres")
const TILE_BASE := preload("res://game-assets/tiles/default/bases/tile_base_portrait.png")
const REFERENCE_SIZE := Vector2(390.0, 844.0)

const MODIFIERS := [
	{"option_id": "extra_life", "type": ModifierLoadoutScript.EXTRA_LIFE, "level": 0, "label": "EXTRA LIFE", "icon": "res://game-assets/modifiers/tile-overlays/extra_life.png"},
	{"option_id": "cold_snap", "type": ModifierLoadoutScript.COLD_SNAP, "level": 0, "label": "COLD SNAP", "icon": "res://game-assets/modifiers/tile-overlays/cold_snap.png"},
	{"option_id": "score_boost", "type": ModifierLoadoutScript.SCORE_MULTIPLIER, "level": 0, "label": "SCORE BOOST", "icon": "res://game-assets/modifiers/tile-overlays/score_multiplier.png"},
	{"option_id": "tray_plus_one", "type": ModifierLoadoutScript.TRAY_PLUS_ONE, "level": 0, "label": "TRAY +1", "icon": "res://game-assets/modifiers/tile-overlays/tray_plus_one.png"},
	{"option_id": "bomb_1", "type": ModifierLoadoutScript.BOMB, "level": 0, "label": "BOMB 1", "icon": "res://game-assets/modifiers/tile-overlays/bomb.png"},
	{"option_id": "bomb_2", "type": ModifierLoadoutScript.BOMB, "level": 1, "label": "BOMB 2", "icon": "res://game-assets/modifiers/tile-overlays/bomb.png"},
	{"option_id": "bomb_3", "type": ModifierLoadoutScript.BOMB, "level": 2, "label": "BOMB 3", "icon": "res://game-assets/modifiers/tile-overlays/bomb.png"},
	{"option_id": "bomb_4", "type": ModifierLoadoutScript.BOMB, "level": 3, "label": "BOMB 4", "icon": "res://game-assets/modifiers/tile-overlays/bomb.png"},
	{"option_id": "bomb_5", "type": ModifierLoadoutScript.BOMB, "level": 4, "label": "BOMB 5", "icon": "res://game-assets/modifiers/tile-overlays/bomb.png"},
	{"option_id": "bomb_6", "type": ModifierLoadoutScript.BOMB, "level": 5, "label": "BOMB 6", "icon": "res://game-assets/modifiers/tile-overlays/bomb.png"},
	{"option_id": "match_1", "type": ModifierLoadoutScript.THREE_PAIR_CLEAR, "level": 0, "label": "MATCH 1", "icon": "res://game-assets/modifiers/tile-overlays/three_pair_clear.png"},
	{"option_id": "match_2", "type": ModifierLoadoutScript.THREE_PAIR_CLEAR, "level": 1, "label": "MATCH 2", "icon": "res://game-assets/modifiers/tile-overlays/three_pair_clear.png"},
	{"option_id": "match_3", "type": ModifierLoadoutScript.THREE_PAIR_CLEAR, "level": 2, "label": "MATCH 3", "icon": "res://game-assets/modifiers/tile-overlays/three_pair_clear.png"},
	{"option_id": "match_4", "type": ModifierLoadoutScript.THREE_PAIR_CLEAR, "level": 3, "label": "MATCH 4", "icon": "res://game-assets/modifiers/tile-overlays/three_pair_clear.png"},
	{"option_id": "match_5", "type": ModifierLoadoutScript.THREE_PAIR_CLEAR, "level": 4, "label": "MATCH 5", "icon": "res://game-assets/modifiers/tile-overlays/three_pair_clear.png"},
]

var _safe_area_insets := Rect2()
var _panel: PanelContainer
var _content: VBoxContainer
var _handle: ColorRect
var _title: Label
var _selected_label: Label
var _selected_row: HBoxContainer
var _grid: GridContainer
var _start_button: Button
var _buttons := {}
var _tile_visuals := {}
var _option_labels := {}
var _selected := {}
var _display_scale := 1.0
var _entrance_played := false


func _init(initial_loadout: Array = []) -> void:
	for entry in initial_loadout:
		if entry is Dictionary:
			var type := str(entry.get("type", ""))
			if type in ModifierLoadoutScript.TYPES:
				_selected[type] = int(entry.get("level", 0))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2500

	var wash := ColorRect.new()
	wash.name = "PickerWash"
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.005, 0.018, 0.016, 0.58)
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(wash)

	_panel = PanelContainer.new()
	_panel.name = "ModifierLoadoutSheet"
	add_child(_panel)
	_content = VBoxContainer.new()
	_panel.add_child(_content)

	var handle_center := CenterContainer.new()
	_content.add_child(handle_center)
	_handle = ColorRect.new()
	_handle.name = "SheetHandle"
	_handle.color = Color("d6a83a")
	_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle_center.add_child(_handle)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "CHOOSE MODIFIERS"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", BOLD_FONT)
	_title.add_theme_color_override("font_color", Color("f5e4a4"))
	_content.add_child(_title)

	_selected_label = Label.new()
	_selected_label.name = "SelectedLabel"
	_selected_label.text = "SELECTED"
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.add_theme_font_override("font", REGULAR_FONT)
	_selected_label.add_theme_color_override("font_color", Color("b8d7bd"))
	_content.add_child(_selected_label)

	var selected_center := CenterContainer.new()
	selected_center.name = "SelectedCenter"
	_content.add_child(selected_center)
	_selected_row = HBoxContainer.new()
	_selected_row.name = "SelectedModifiers"
	_selected_row.alignment = BoxContainer.ALIGNMENT_CENTER
	selected_center.add_child(_selected_row)

	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", Color("9f7b28"))
	_content.add_child(rule)

	_grid = GridContainer.new()
	_grid.name = "ModifierGrid"
	_grid.columns = 3
	_content.add_child(_grid)
	for definition in MODIFIERS:
		_grid.add_child(_make_modifier_option(definition))

	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "START GAME"
	_start_button.focus_mode = Control.FOCUS_ALL
	_start_button.add_theme_font_override("font", BOLD_FONT)
	_start_button.add_theme_color_override("font_color", Color("071e1a"))
	_start_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_start_button.pressed.connect(_confirm)
	_content.add_child(_start_button)

	resized.connect(_layout)
	_refresh_selection()
	_layout()
	call_deferred("_play_entrance")


func set_safe_area_insets(insets: Rect2) -> void:
	_safe_area_insets = insets
	_layout()


func selected_loadout() -> Array:
	var loadout: Array = []
	for type in ModifierLoadoutScript.TYPES:
		if _selected.has(type):
			loadout.append({
				"modifier_id": "selected_%s_%d" % [type, int(_selected[type])],
				"type": type,
				"level": int(_selected[type]),
			})
	return loadout


func toggle_for_testing(type: String, level: int = -1) -> void:
	var default_level := 4 if type == ModifierLoadoutScript.BOMB else \
		2 if type == ModifierLoadoutScript.THREE_PAIR_CLEAR else 0
	_toggle_modifier(type, default_level if level < 0 else level)


func confirm_for_testing() -> void:
	_confirm()


func _make_modifier_option(definition: Dictionary) -> VBoxContainer:
	var type := str(definition.type)
	var level := int(definition.level)
	var option_id := str(definition.option_id)
	var option := VBoxContainer.new()
	option.name = "%sOption" % option_id.to_pascal_case()
	option.alignment = BoxContainer.ALIGNMENT_CENTER
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tile_center := CenterContainer.new()
	tile_center.name = "TileCenter"
	option.add_child(tile_center)
	var tile := _make_tile_visual(definition, "%sTile" % option_id.to_pascal_case())
	tile_center.add_child(tile)
	_tile_visuals[option_id] = tile

	var button := Button.new()
	button.name = "%sButton" % option_id.to_pascal_case()
	button.text = ""
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = str(definition.label)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_toggle_modifier.bind(type, level))
	tile.add_child(button)
	_buttons[option_id] = button

	var label := Label.new()
	label.name = "Label"
	label.text = str(definition.label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override("font", BOLD_FONT)
	label.add_theme_color_override("font_color", Color("e7e0c9"))
	option.add_child(label)
	_option_labels[option_id] = label
	return option


func _make_tile_visual(definition: Dictionary, node_name: String) -> Control:
	var tile := Control.new()
	tile.name = node_name
	tile.mouse_filter = Control.MOUSE_FILTER_PASS

	var base := TextureRect.new()
	base.name = "CeramicBase"
	base.texture = TILE_BASE
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(base)

	var icon := TextureRect.new()
	icon.name = "ModifierArt"
	icon.texture = load(str(definition.icon))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 13.0
	icon.offset_top = 13.0
	icon.offset_right = -13.0
	icon.offset_bottom = -13.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	return tile


func _toggle_modifier(type: String, level: int) -> void:
	if type not in ModifierLoadoutScript.TYPES:
		return
	if _selected.get(type, -1) == level:
		_selected.erase(type)
	else:
		_selected[type] = level
	_refresh_selection()


func _refresh_selection() -> void:
	if _selected_row == null:
		return
	for child in _selected_row.get_children():
		child.queue_free()
	for definition in MODIFIERS:
		var type: String = definition.type
		var level := int(definition.level)
		var option_id := str(definition.option_id)
		var selected: bool = _selected.get(type, -1) == level
		var button: Button = _buttons[option_id]
		button.set_pressed_no_signal(selected)
		_apply_button_style(button, selected)
		if not selected:
			continue
		var selected_tile := _make_tile_visual(definition, "%sSelected" % option_id.to_pascal_case())
		selected_tile.tooltip_text = str(definition.label)
		selected_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_selected_row.add_child(selected_tile)
	_layout_selection()


func _confirm() -> void:
	_start_button.disabled = true
	start_requested.emit(selected_loadout())


func _layout() -> void:
	if _panel == null:
		return
	var insets := _safe_area_insets
	if insets == Rect2():
		insets = SafeAreaScript.insets(size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var safe_rect := SafeAreaScript.content_rect(size, insets)
	_display_scale = PresentationScaleScript.limiting_scale(safe_rect.size, REFERENCE_SIZE, 0.78)
	var portrait := safe_rect.size.y >= safe_rect.size.x
	var panel_width := minf(safe_rect.size.x, 390.0 * _display_scale)
	var panel_height := minf(safe_rect.size.y * (0.76 if portrait else 0.92), 720.0 * _display_scale)
	_panel.position = Vector2(safe_rect.position.x + (safe_rect.size.x - panel_width) * 0.5, safe_rect.end.y - panel_height)
	_panel.size = Vector2(panel_width, panel_height)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("071e1a")
	style.border_color = Color("d6a83a")
	style.set_border_width_all(maxi(2, roundi(2.0 * _display_scale)))
	style.set_corner_radius_all(roundi(12.0 * _display_scale))
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 16.0 * _display_scale
	style.content_margin_right = 16.0 * _display_scale
	style.content_margin_top = 10.0 * _display_scale
	style.content_margin_bottom = 14.0 * _display_scale
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = roundi(10.0 * _display_scale)
	_panel.add_theme_stylebox_override("panel", style)
	_content.add_theme_constant_override("separation", roundi(7.0 * _display_scale))
	_handle.custom_minimum_size = Vector2(44.0, 4.0) * _display_scale
	_title.add_theme_font_size_override("font_size", roundi(25.0 * _display_scale))
	_selected_label.add_theme_font_size_override("font_size", roundi(12.0 * _display_scale))
	_grid.add_theme_constant_override("h_separation", roundi(8.0 * _display_scale))
	_grid.add_theme_constant_override("v_separation", roundi(8.0 * _display_scale))
	for option_id in _buttons:
		var button: Button = _buttons[option_id]
		_tile_visuals[option_id].custom_minimum_size = Vector2(56.0, 56.0) * _display_scale
		_option_labels[option_id].add_theme_font_size_override("font_size", roundi(9.0 * _display_scale))
		_apply_button_style(button, button.button_pressed)
	_start_button.custom_minimum_size.y = 48.0 * _display_scale
	_start_button.add_theme_font_size_override("font_size", roundi(19.0 * _display_scale))
	_start_button.add_theme_stylebox_override("normal", _style(Color("d6a83a"), Color("f5d56d")))
	_start_button.add_theme_stylebox_override("hover", _style(Color("e8bd4c"), Color.WHITE))
	_start_button.add_theme_stylebox_override("pressed", _style(Color("b88722"), Color("f5e4a4")))
	_layout_selection()


func _layout_selection() -> void:
	if _selected_row == null:
		return
	_selected_row.add_theme_constant_override("separation", roundi(5.0 * _display_scale))
	for tile in _selected_row.get_children():
		tile.custom_minimum_size = Vector2(32.0, 32.0) * _display_scale
		var icon: TextureRect = tile.get_node("ModifierArt")
		var inset := 6.0 * _display_scale
		icon.offset_left = inset
		icon.offset_top = inset
		icon.offset_right = -inset
		icon.offset_bottom = -inset


func _apply_button_style(button: Button, selected: bool) -> void:
	var option_id := ""
	for candidate in _buttons:
		if _buttons[candidate] == button:
			option_id = candidate
			break
	if not option_id.is_empty():
		_tile_visuals[option_id].modulate = Color.WHITE if selected else Color(0.82, 0.84, 0.82, 1.0)
		_option_labels[option_id].add_theme_color_override(
			"font_color",
			Color("f5e4a4") if selected else Color("c8c8b9")
		)
	button.add_theme_stylebox_override("normal", _tile_button_style(selected, false))
	button.add_theme_stylebox_override("hover", _tile_button_style(selected, true))
	button.add_theme_stylebox_override("pressed", _tile_button_style(true, true))
	button.add_theme_stylebox_override("focus", _tile_button_style(true, false))


func _tile_button_style(selected: bool, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.08) if highlighted else Color.TRANSPARENT
	style.border_color = Color("f5d56d") if selected or highlighted else Color.TRANSPARENT
	style.set_border_width_all(maxi(2, roundi(2.0 * _display_scale)) if selected or highlighted else 0)
	style.set_corner_radius_all(roundi(8.0 * _display_scale))
	return style


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(_display_scale)))
	style.set_corner_radius_all(roundi(6.0 * _display_scale))
	style.content_margin_left = 10.0 * _display_scale
	style.content_margin_right = 10.0 * _display_scale
	return style


func _play_entrance() -> void:
	if _entrance_played or _panel == null:
		return
	_entrance_played = true
	var final_y := _panel.position.y
	_panel.position.y = size.y + 12.0 * _display_scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "position:y", final_y, 0.28)
