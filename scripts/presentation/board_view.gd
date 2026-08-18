extends Control
class_name BoardView

signal tile_selected(tile_id: String)

const TILE_ASPECT := 1.26
const COLUMN_COUNT := 8
const ROW_COUNT := 6
const HEADER_HEIGHT := 48.0
const BOARD_MARGIN := 14.0

var _game: Variant
var _tile_buttons: Dictionary = {}
var _title_label: Label
var _status_label: Label
var _tile_layer: Control


func _init(game_state: Variant) -> void:
	_game = game_state


func _ready() -> void:
	_build()
	_rebuild_tiles()
	resized.connect(_layout_tiles)
	_layout_tiles()


func set_game_state(game_state: Variant) -> void:
	_game = game_state
	_rebuild_tiles()
	_layout_tiles()


func _build() -> void:
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override("panel", _panel_style())
	add_child(background)

	_title_label = Label.new()
	_title_label.text = "Board"
	_title_label.position = Vector2(BOARD_MARGIN, 8.0)
	_title_label.add_theme_font_size_override("font_size", 20)
	add_child(_title_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.position = Vector2(120.0, 10.0)
	_status_label.add_theme_color_override("font_color", Color(0.74, 0.80, 0.79))
	add_child(_status_label)

	_tile_layer = Control.new()
	_tile_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_tile_layer)


func _rebuild_tiles() -> void:
	for button in _tile_buttons.values():
		button.queue_free()
	_tile_buttons.clear()

	for tile in _game.board.tiles:
		var button := Button.new()
		button.name = tile.id
		button.text = _face_label(tile.face.value)
		button.tooltip_text = _face_label(tile.face.value).replace("\n", " ")
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_tile_pressed.bind(tile.id))
		_tile_layer.add_child(button)
		_tile_buttons[tile.id] = button

	refresh()


func refresh() -> void:
	var active_count: int = _game.board.call("active_tiles").size()
	var selectable_ids := {}
	for tile in _game.board.call("selectable_tiles"):
		selectable_ids[tile.id] = true

	for tile in _game.board.tiles:
		var button: Button = _tile_buttons[tile.id]
		button.visible = not tile.removed
		if tile.removed:
			continue

		var selectable: bool = selectable_ids.has(tile.id) and _game.status == "playing"
		button.disabled = not selectable
		button.modulate = Color.WHITE if selectable else Color(0.58, 0.61, 0.60)
		_apply_tile_style(button, tile.face.value)

	if active_count == 0:
		_status_label.text = "Board cleared"
	else:
		_status_label.text = "%d tiles  |  %d free" % [active_count, selectable_ids.size()]


func _on_tile_pressed(tile_id: String) -> void:
	if _game.status != "playing" or not _game.board.call("is_tile_selectable", tile_id):
		return

	tile_selected.emit(tile_id)


func _layout_tiles() -> void:
	if _tile_layer == null or _game == null:
		return

	_status_label.size = Vector2(maxf(80.0, size.x - 140.0 - BOARD_MARGIN), 30.0)
	var area := Rect2(
		BOARD_MARGIN,
		HEADER_HEIGHT,
		maxf(1.0, size.x - BOARD_MARGIN * 2.0),
		maxf(1.0, size.y - HEADER_HEIGHT - BOARD_MARGIN)
	)
	_tile_layer.position = area.position
	_tile_layer.size = area.size

	var layer_allowance := 10.0
	var tile_width: float = minf(
		(area.size.x - layer_allowance) / COLUMN_COUNT,
		(area.size.y - layer_allowance) / (ROW_COUNT * TILE_ASPECT)
	)
	var tile_size := Vector2(maxf(16.0, tile_width), maxf(20.0, tile_width * TILE_ASPECT))
	var board_size := Vector2(tile_size.x * COLUMN_COUNT, tile_size.y * ROW_COUNT)
	var origin := (area.size - board_size) * 0.5

	for tile in _game.board.tiles:
		var button: Button = _tile_buttons[tile.id]
		var depth_offset := Vector2(tile.position.z * 4.0, tile.position.z * -5.0)
		button.position = origin + Vector2(
			float(tile.position.x) * tile_size.x * 0.5,
			float(tile.position.y) * tile_size.y * 0.5
		) + depth_offset
		button.size = tile_size - Vector2(3.0, 3.0)
		button.z_index = tile.position.z * 100 + int(tile.position.y)
		button.add_theme_font_size_override("font_size", clampi(int(tile_size.x * 0.25), 10, 18))


func _face_label(value: String) -> String:
	var identity := int(value) - 1
	var families := ["BAM", "DOT", "CHR", "HON"]
	return "%s\n%d" % [families[identity / 6], identity % 6 + 1]


func _apply_tile_style(button: Button, value: String) -> void:
	var identity := int(value) - 1
	var face_colors := [
		Color("d8ead6"),
		Color("f0d7d2"),
		Color("d4e3f2"),
		Color("f1e1b8"),
	]
	var face_color: Color = face_colors[identity / 6]
	var border_color := Color("6c7775")
	var border_width := 2

	button.add_theme_stylebox_override("normal", _tile_style(face_color, border_color, border_width, Vector2(0.0, 3.0)))
	button.add_theme_stylebox_override("hover", _tile_style(face_color.lightened(0.08), Color("e8f2ef"), 3, Vector2(0.0, 3.0)))
	button.add_theme_stylebox_override("pressed", _tile_style(face_color.darkened(0.08), Color("56d6a5"), 4, Vector2(0.0, 1.0)))
	button.add_theme_stylebox_override("disabled", _tile_style(face_color.darkened(0.18), Color("4b5554"), 2, Vector2(0.0, 2.0)))
	button.add_theme_color_override("font_color", Color("202625"))
	button.add_theme_color_override("font_hover_color", Color("111615"))
	button.add_theme_color_override("font_pressed_color", Color("111615"))
	button.add_theme_color_override("font_disabled_color", Color("59615f"))


func _tile_style(face_color: Color, border_color: Color, border_width: int, shadow_offset: Vector2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 3
	style.shadow_offset = shadow_offset
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182326")
	style.border_color = Color("426267")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
