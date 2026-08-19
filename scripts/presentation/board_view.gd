extends Control
class_name BoardView

const TileSkinScript := preload("res://scripts/presentation/tile_skin.gd")

signal tile_selected(tile_id: String)
signal locked_tile_tapped(tile_id: String)

const TILE_ASPECT := 1.26
const HEADER_HEIGHT := 48.0
const BOARD_MARGIN := 14.0

var _game: Variant
var _tile_buttons: Dictionary = {}
var _face_art: Dictionary = {}
var _modifier_labels: Dictionary = {}
var _title_label: Label
var _status_label: Label
var _tile_layer: Control
var _tile_skin: Variant
var _delete_pair_armed := false
var _audio_player: AudioStreamPlayer
var _audio_playback: Variant
var _negative_feedback_count := 0


func _init(game_state: Variant, tile_skin: Variant = null) -> void:
	_game = game_state
	_tile_skin = TileSkinScript.new() if tile_skin == null else tile_skin


func _ready() -> void:
	_build()
	_rebuild_tiles()
	resized.connect(_layout_tiles)
	_layout_tiles()


func set_game_state(game_state: Variant) -> void:
	_game = game_state
	_delete_pair_armed = false
	_rebuild_tiles()
	_layout_tiles()


func set_delete_pair_armed(armed: bool) -> void:
	_delete_pair_armed = armed
	refresh()


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

	if DisplayServer.get_name() == "headless":
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.2
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = generator
	_audio_player.volume_db = -11.0
	add_child(_audio_player)
	_audio_player.play()
	_audio_playback = _audio_player.get_stream_playback()


func _rebuild_tiles() -> void:
	for button in _tile_buttons.values():
		button.queue_free()
	_tile_buttons.clear()
	_face_art.clear()
	_modifier_labels.clear()

	for tile in _game.board.tiles:
		var button := Button.new()
		button.name = tile.id
		button.tooltip_text = _tile_tooltip(tile)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_tile_pressed.bind(tile.id))

		var face_art := TextureRect.new()
		face_art.name = "FaceArt"
		face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(face_art)

		var modifier_label := Label.new()
		modifier_label.name = "Modifier"
		modifier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modifier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		modifier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modifier_label.add_theme_color_override("font_color", Color("fff7cf"))
		modifier_label.add_theme_color_override("font_shadow_color", Color("17343b"))
		modifier_label.add_theme_constant_override("shadow_offset_x", 1)
		modifier_label.add_theme_constant_override("shadow_offset_y", 1)
		button.add_child(modifier_label)

		_tile_layer.add_child(button)
		_tile_buttons[tile.id] = button
		_face_art[tile.id] = face_art
		_modifier_labels[tile.id] = modifier_label

	refresh()


func refresh() -> void:
	var active_count: int = _game.board.call("active_tiles").size()
	var selectable_ids := {}
	var visible_ids := {}
	var hinted_ids := {}
	for hinted_tile_id in _game.call("hinted_tile_ids"):
		hinted_ids[hinted_tile_id] = true
	for tile in _game.board.call("selectable_tiles"):
		selectable_ids[tile.id] = true
	for tile in _game.board.call("visible_tiles"):
		visible_ids[tile.id] = true

	for tile in _game.board.tiles:
		var button: Button = _tile_buttons[tile.id]
		var active: bool = _game.board.call("is_tile_active", tile.id)
		button.visible = active
		if not active:
			continue

		var selectable: bool = (_delete_pair_armed and visible_ids.has(tile.id) \
			or not _delete_pair_armed and selectable_ids.has(tile.id)) \
			and _game.status == "playing"
		button.disabled = _game.status != "playing"
		button.set_meta("targetable", selectable)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if selectable else Control.CURSOR_FORBIDDEN
		button.modulate = Color.WHITE if selectable else Color(0.72, 0.73, 0.70)
		_apply_tile_style(button, selectable)
		if _delete_pair_armed and selectable:
			button.add_theme_stylebox_override("normal", _tile_style(Color("fff8e8"), Color("ef496f"), 4, Vector2(0.0, 3.0)))
		var texture: Texture2D = _tile_skin.texture_for_face(tile.face)
		var face_art: TextureRect = _face_art[tile.id]
		face_art.texture = texture
		face_art.visible = texture != null
		button.text = "" if texture != null else _tile_label(tile)
		var modifier_label: Label = _modifier_labels[tile.id]
		modifier_label.text = _modifier_symbol(tile)
		modifier_label.visible = not modifier_label.text.is_empty()
		if hinted_ids.has(tile.id):
			button.add_theme_stylebox_override("normal", _tile_style(Color("fffdf4"), Color("ffd166"), 5, Vector2(0.0, 3.0)))

	if active_count == 0:
		_status_label.text = "Board cleared"
	else:
		_status_label.text = "%d tiles  |  %d free" % [active_count, selectable_ids.size()]
	_layout_tiles()


func _on_tile_pressed(tile_id: String) -> void:
	var targetable: bool = _game.board.call("is_tile_visible", tile_id) if _delete_pair_armed \
		else _game.board.call("is_tile_selectable", tile_id)
	if _game.status != "playing":
		return
	if not targetable:
		if not _delete_pair_armed:
			locked_tile_tapped.emit(tile_id)
		_play_negative_feedback(tile_id)
		return

	tile_selected.emit(tile_id)


func create_tile_preview(tile_id: String) -> Control:
	var button: Button = _tile_buttons.get(tile_id)
	if button == null or not button.visible:
		return null
	var preview := Panel.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color.WHITE
	preview.add_theme_stylebox_override("panel", button.get_theme_stylebox("normal").duplicate())
	var source_art: TextureRect = _face_art[tile_id]
	if source_art.texture != null:
		var face_art := TextureRect.new()
		face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face_art.set_anchors_preset(Control.PRESET_FULL_RECT)
		var safe_area: Array = _tile_skin.geometry.get("face_safe_area", [92, 104, 328, 400])
		var source_size: Array = _tile_skin.geometry.get("source_size", [512, 640])
		face_art.anchor_left = float(safe_area[0]) / float(source_size[0])
		face_art.anchor_top = float(safe_area[1]) / float(source_size[1])
		face_art.anchor_right = float(safe_area[0] + safe_area[2]) / float(source_size[0])
		face_art.anchor_bottom = float(safe_area[1] + safe_area[3]) / float(source_size[1])
		preview.add_child(face_art)
		face_art.texture = source_art.texture
	var source_modifier: Label = _modifier_labels[tile_id]
	if source_modifier.visible:
		var modifier := Label.new()
		modifier.text = source_modifier.text
		modifier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modifier.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		modifier.anchor_left = 0.68
		modifier.anchor_top = 0.02
		modifier.anchor_right = 0.98
		modifier.anchor_bottom = 0.25
		modifier.add_theme_color_override("font_color", Color("fff7cf"))
		preview.add_child(modifier)
	return preview


func tile_global_rect(tile_id: String) -> Rect2:
	var button: Button = _tile_buttons.get(tile_id)
	return Rect2() if button == null else button.get_global_rect()


func negative_feedback_count() -> int:
	return _negative_feedback_count


func _play_negative_feedback(tile_id: String) -> void:
	var button: Button = _tile_buttons.get(tile_id)
	if button == null:
		return
	_negative_feedback_count += 1
	var origin := button.position
	var distance := clampf(button.size.x * 0.11, 3.0, 7.0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "position:x", origin.x - distance, 0.045)
	tween.tween_property(button, "position:x", origin.x + distance, 0.07)
	tween.tween_property(button, "position:x", origin.x - distance * 0.5, 0.055)
	tween.tween_property(button, "position:x", origin.x, 0.045)
	_play_negative_tone()


func _play_negative_tone() -> void:
	if _audio_playback == null:
		return
	var frames := PackedVector2Array()
	var frame_count := 2425
	for frame in range(frame_count):
		var progress := float(frame) / float(frame_count)
		var frequency := lerpf(190.0, 105.0, progress)
		var envelope := (1.0 - progress) * 0.18
		var sample := sin(TAU * frequency * float(frame) / 22050.0) * envelope
		frames.append(Vector2(sample, sample))
	_audio_playback.push_buffer(frames)


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

	var bounds := _grid_bounds()
	var grid_width: float = float(bounds.size.x) * 0.5
	var grid_height: float = float(bounds.size.y) * 0.5
	var max_depth := 0
	for tile in _game.board.tiles:
		max_depth = maxi(max_depth, tile.position.z)
	var depth_extent := Vector2(float(max_depth) * 4.0, float(max_depth) * 5.0)
	var control_allowance := Vector2(12.0, 12.0)
	var tile_width: float = minf(
		(area.size.x - depth_extent.x - control_allowance.x) / grid_width,
		(area.size.y - depth_extent.y - control_allowance.y) / (grid_height * TILE_ASPECT)
	)
	var tile_size := Vector2(maxf(16.0, tile_width), maxf(20.0, tile_width * TILE_ASPECT))
	var board_size := Vector2(tile_size.x * grid_width, tile_size.y * grid_height)
	var origin := (area.size - board_size - depth_extent) * 0.5 + Vector2(0.0, depth_extent.y)

	for tile in _game.board.tiles:
		var button: Button = _tile_buttons[tile.id]
		var depth_offset := Vector2(tile.position.z * 4.0, tile.position.z * -5.0)
		button.position = origin + Vector2(
			float(tile.position.x - bounds.position.x) * tile_size.x * 0.5,
			float(tile.position.y - bounds.position.y) * tile_size.y * 0.5
		) + depth_offset
		button.size = tile_size - Vector2(3.0, 3.0)
		button.z_index = tile.position.z * 100 + int(tile.position.y)
		button.add_theme_font_size_override("font_size", clampi(int(tile_size.x * 0.25), 10, 18))
		var safe_area: Array = _tile_skin.geometry.get("face_safe_area", [92, 104, 328, 400])
		var source_size: Array = _tile_skin.geometry.get("source_size", [512, 640])
		var face_art: TextureRect = _face_art[tile.id]
		face_art.position = Vector2(
			float(safe_area[0]) / float(source_size[0]) * button.size.x,
			float(safe_area[1]) / float(source_size[1]) * button.size.y
		)
		face_art.size = Vector2(
			float(safe_area[2]) / float(source_size[0]) * button.size.x,
			float(safe_area[3]) / float(source_size[1]) * button.size.y
		)
		var modifier_label: Label = _modifier_labels[tile.id]
		modifier_label.position = Vector2(button.size.x * 0.68, button.size.y * 0.02)
		modifier_label.size = Vector2(button.size.x * 0.30, button.size.y * 0.23)
		modifier_label.add_theme_font_size_override("font_size", clampi(int(tile_size.x * 0.19), 8, 15))


func _grid_bounds() -> Rect2i:
	if _game.board.tiles.is_empty():
		return Rect2i(0, 0, 2, 2)
	var first_position: Variant = _game.board.tiles[0].position
	var minimum := Vector2i(first_position.x, first_position.y)
	var maximum := minimum + Vector2i(2, 2)
	for tile in _game.board.tiles:
		minimum.x = mini(minimum.x, tile.position.x)
		minimum.y = mini(minimum.y, tile.position.y)
		maximum.x = maxi(maximum.x, tile.position.x + 2)
		maximum.y = maxi(maximum.y, tile.position.y + 2)
	return Rect2i(minimum, maximum - minimum)


func _tile_label(tile: Variant) -> String:
	return _tile_skin.label_for_face(tile.face)


func _modifier_symbol(tile: Variant) -> String:
	var modifier: Dictionary = _game.definition.modifier_for_tile(tile.id)
	if modifier.is_empty():
		return ""
	var symbols := {
		"extra_life": "♥",
		"cold_snap": "❄",
		"score_multiplier": "×",
		"tray_plus_one": "+1",
	}
	return "%s%d" % [symbols.get(modifier.type, "★"), int(modifier.level)]


func _tile_tooltip(tile: Variant) -> String:
	var label: String = _tile_skin.label_for_face(tile.face).replace("\n", " ")
	var modifier: Dictionary = _game.definition.modifier_for_tile(tile.id)
	if modifier.is_empty():
		return label
	return "%s | %s level %d" % [label, str(modifier.type).replace("_", " ").capitalize(), int(modifier.level)]


func _apply_tile_style(button: Button, selectable: bool) -> void:
	var normal := _tile_style(Color("fffdf4"), Color("35636b"), 2, Vector2(0.0, 4.0))
	var hover := _tile_style(Color("ffffff"), Color("57d8b0"), 3, Vector2(0.0, 4.0))
	var pressed := _tile_style(Color("e6f2e7"), Color("ef496f"), 4, Vector2(0.0, 1.0))
	if not selectable:
		normal = _tile_style(Color("a7a99f"), Color("3d4746"), 2, Vector2(0.0, 3.0))
		hover = normal
		pressed = normal
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", _tile_style(Color("8f9189"), Color("394140"), 2, Vector2(0.0, 2.0)))
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
