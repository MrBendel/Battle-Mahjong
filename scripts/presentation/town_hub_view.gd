extends Control
class_name TownHubView

signal destination_requested(destination_id: String)

const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const PresentationScaleScript := preload("res://scripts/presentation/presentation_scale.gd")
const TownDestinationSignScript := preload("res://scripts/presentation/town_destination_sign.gd")
const REFERENCE_SIZE := Vector2(390.0, 844.0)

const DESTINATIONS := [
	{
		"id": "tower", "label": "THE TOWER", "available": true, "sign_tilt": -0.5,
		"portrait": Rect2(0.23, 0.09, 0.54, 0.27),
		"landscape": Rect2(0.36, 0.03, 0.28, 0.40),
	},
	{
		"id": "home", "label": "YOUR HOME", "available": false, "sign_tilt": 0.8,
		"portrait": Rect2(0.01, 0.29, 0.43, 0.23),
		"landscape": Rect2(0.03, 0.09, 0.27, 0.39),
	},
	{
		"id": "game_hall", "label": "GAME HALL", "available": false, "sign_tilt": -0.7,
		"portrait": Rect2(0.56, 0.29, 0.43, 0.23),
		"landscape": Rect2(0.70, 0.09, 0.27, 0.39),
	},
	{
		"id": "daily_shrine", "label": "DAILY SHRINE", "available": false, "sign_tilt": -0.9,
		"portrait": Rect2(0.01, 0.51, 0.43, 0.23),
		"landscape": Rect2(0.03, 0.55, 0.27, 0.39),
	},
	{
		"id": "dojo", "label": "THE DOJO", "available": false, "sign_tilt": 0.7,
		"portrait": Rect2(0.56, 0.51, 0.43, 0.23),
		"landscape": Rect2(0.70, 0.55, 0.27, 0.39),
	},
	{
		"id": "downtown", "label": "DOWNTOWN", "available": false, "sign_tilt": -0.4,
		"portrait": Rect2(0.23, 0.71, 0.54, 0.27),
		"landscape": Rect2(0.36, 0.57, 0.28, 0.40),
	},
]

const DECORATIONS := [
	{
		"art": "cherry", "portrait": Rect2(-0.04, 0.02, 0.27, 0.18),
		"landscape": Rect2(-0.02, 0.00, 0.18, 0.30),
	},
	{
		"art": "tree_tall", "portrait": Rect2(0.79, 0.01, 0.25, 0.18),
		"landscape": Rect2(0.84, -0.01, 0.18, 0.31),
	},
	{
		"art": "hedge", "portrait": Rect2(0.37, 0.43, 0.26, 0.13),
		"landscape": Rect2(0.42, 0.40, 0.16, 0.18),
	},
	{
		"art": "bamboo", "portrait": Rect2(-0.04, 0.74, 0.27, 0.20),
		"landscape": Rect2(-0.01, 0.70, 0.18, 0.30),
	},
	{
		"art": "tree_a", "portrait": Rect2(0.78, 0.75, 0.27, 0.20),
		"landscape": Rect2(0.84, 0.70, 0.18, 0.30),
	},
]

var _theme: Resource
var _map: TextureRect
var _map_tint: ColorRect
var _foreground: TextureRect
var _decoration_layer: Control
var _destination_layer: Control
var _destination_buttons: Dictionary = {}
var _destination_visuals: Dictionary = {}
var _destination_signs: Dictionary = {}
var _decorations: Array[TextureRect] = []
var _map_rect := Rect2()
var _safe_area_insets := Rect2()
var _animation_time := 0.0


func _init(theme: Resource = null) -> void:
	_theme = theme


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_build_view()
	get_viewport().size_changed.connect(_layout)
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_animation_time += delta
	var pulse := (sin(_animation_time * 1.8) + 1.0) * 0.5
	for destination in DESTINATIONS:
		if not bool(destination.available):
			continue
		var visual: Sprite2D = _destination_visuals.get(destination.id)
		if visual == null:
			continue
		visual.modulate = Color(1.0 + pulse * 0.14, 1.0 + pulse * 0.12, 1.0 + pulse * 0.05, 1.0)
		var base_position: Vector2 = visual.get_meta("base_position", visual.position)
		visual.position = base_position + Vector2(0.0, sin(_animation_time * 1.20) * 4.0 * _display_scale())


func set_safe_area_insets(insets: Rect2) -> void:
	_safe_area_insets = insets
	_layout()


func destination_button(destination_id: String) -> TextureButton:
	return _destination_buttons.get(destination_id)


func open_destination_for_testing(destination_id: String) -> void:
	_on_destination_pressed(destination_id)


func _build_view() -> void:
	var clear := ColorRect.new()
	clear.name = "ThemeClear"
	clear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear.color = _theme.map_clear_color if _theme != null else Color("0b211e")
	clear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clear)

	_map = TextureRect.new()
	_map.name = "TownGround"
	_map.texture = _theme.map_texture if _theme != null else null
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)

	_map_tint = ColorRect.new()
	_map_tint.name = "AmbientTint"
	_map_tint.color = _theme.ambient_tint if _theme != null else Color.WHITE
	_map_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_tint.material = CanvasItemMaterial.new()
	_map_tint.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	add_child(_map_tint)

	_decoration_layer = Control.new()
	_decoration_layer.name = "SeasonalDecorations"
	_decoration_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_decoration_layer)
	for decoration in DECORATIONS:
		var art: Variant = _theme.decoration_overlays.get(decoration.art) if _theme != null else null
		if not art is Texture2D:
			continue
		var decoration_view := TextureRect.new()
		decoration_view.texture = art
		decoration_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		decoration_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		decoration_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decoration_view.set_meta("definition", decoration)
		_decoration_layer.add_child(decoration_view)
		_decorations.append(decoration_view)

	_destination_layer = Control.new()
	_destination_layer.name = "DestinationBuildings"
	_destination_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_destination_layer)
	for destination in DESTINATIONS:
		_build_destination(destination)

	_foreground = TextureRect.new()
	_foreground.name = "SeasonalForeground"
	_foreground.texture = _theme.foreground_texture if _theme != null else null
	_foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foreground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground.visible = _foreground.texture != null
	add_child(_foreground)

func _build_destination(destination: Dictionary) -> void:
	var texture: Variant = _theme.destination_overlays.get(destination.id) if _theme != null else null
	if not texture is Texture2D:
		return
	var button := TextureButton.new()
	button.name = "%sDestination" % str(destination.id).to_pascal_case()
	button.texture_normal = texture
	button.texture_disabled = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_click_mask = _click_mask(texture)
	button.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	button.disabled = not bool(destination.available)
	button.focus_mode = Control.FOCUS_ALL if bool(destination.available) else Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP if bool(destination.available) else Control.MOUSE_FILTER_IGNORE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if bool(destination.available) else Control.CURSOR_ARROW
	button.pressed.connect(_on_destination_pressed.bind(str(destination.id)))
	_destination_layer.add_child(button)
	_destination_buttons[destination.id] = button

	var visual := Sprite2D.new()
	visual.name = "BuildingVisual"
	visual.texture = texture
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visual.modulate = Color.WHITE if bool(destination.available) else _theme.locked_tint
	button.add_child(visual)
	_destination_visuals[destination.id] = visual

	var sign: Control = TownDestinationSignScript.new()
	sign.name = "DestinationSign"
	button.add_child(sign)
	var board_color: Color = _theme.destination_sign_colors.get(
		destination.id,
		Color("183f31")
	)
	var border_color: Color = _theme.available_accent if bool(destination.available) \
		else Color("a58d5a")
	sign.call("configure", str(destination.label), board_color, border_color)
	_destination_signs[destination.id] = sign


func _click_mask(texture: Texture2D) -> BitMap:
	var mask := BitMap.new()
	var image := texture.get_image()
	if image != null:
		mask.create_from_image_alpha(image, 0.08)
	return mask


func _layout() -> void:
	if _map == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var insets := _safe_area_insets
	if insets == Rect2():
		insets = SafeAreaScript.insets(size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var safe_rect := SafeAreaScript.content_rect(size, insets)
	_map_rect = safe_rect
	for layer in [_map, _map_tint, _decoration_layer, _destination_layer, _foreground]:
		layer.position = safe_rect.position
		layer.size = safe_rect.size

	var landscape := safe_rect.size.x > safe_rect.size.y
	var layout_key := "landscape" if landscape else "portrait"
	var ui_scale := _display_scale()
	for decoration_view in _decorations:
		var definition: Dictionary = decoration_view.get_meta("definition")
		var normalized_rect: Rect2 = definition[layout_key]
		decoration_view.position = normalized_rect.position * safe_rect.size
		decoration_view.size = normalized_rect.size * safe_rect.size

	for destination in DESTINATIONS:
		var button: TextureButton = _destination_buttons.get(destination.id)
		if button == null:
			continue
		var normalized_rect: Rect2 = destination[layout_key]
		button.position = normalized_rect.position * safe_rect.size
		button.size = normalized_rect.size * safe_rect.size
		button.pivot_offset = button.size * 0.5
		var visual: Sprite2D = _destination_visuals[destination.id]
		var texture_size := visual.texture.get_size()
		var visual_scale := minf(button.size.x / texture_size.x, button.size.y / texture_size.y)
		visual.scale = Vector2.ONE * visual_scale
		visual.position = button.size * 0.5
		visual.set_meta("base_position", visual.position)
		var sign: Control = _destination_signs[destination.id]
		sign.call("layout_sign", button.size.x * 0.82, ui_scale)
		sign.position = Vector2(
			(button.size.x - sign.size.x) * 0.5,
			button.size.y - sign.size.y * 1.10
		)
		sign.rotation = deg_to_rad(float(destination.get("sign_tilt", 0.0)))

func _display_scale() -> float:
	return PresentationScaleScript.limiting_scale(size, REFERENCE_SIZE, 0.72, 2.8)


func _on_destination_pressed(destination_id: String) -> void:
	for destination in DESTINATIONS:
		if destination.id == destination_id and bool(destination.available):
			destination_requested.emit(destination_id)
			return
