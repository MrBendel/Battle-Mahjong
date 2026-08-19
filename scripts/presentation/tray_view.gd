extends Control
class_name TrayView

const TileSkinScript := preload("res://scripts/presentation/tile_skin.gd")

const SLOT_COUNT := 4
const HEADER_HEIGHT := 32.0
const MARGIN := 10.0
const GAP := 6.0

var _game: Variant
var _status_label: Label
var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _slot_art: Array[TextureRect] = []
var _tile_skin: Variant


func _init(game_state: Variant, tile_skin: Variant = null) -> void:
	_game = game_state
	_tile_skin = TileSkinScript.new() if tile_skin == null else tile_skin


func _ready() -> void:
	_build()
	resized.connect(_layout)
	refresh()
	_layout()


func set_game_state(game_state: Variant) -> void:
	_game = game_state
	refresh()


func refresh() -> void:
	if _game == null or _slots.is_empty():
		return

	for index in range(SLOT_COUNT):
		var occupied: bool = index < _game.tray.tiles.size()
		var label := _slot_labels[index]
		var face_art := _slot_art[index]
		if occupied:
			var tile: Variant = _game.tray.tiles[index]
			face_art.texture = _tile_skin.texture_for_face(tile.face)
			face_art.visible = face_art.texture != null
			label.text = _tile_skin.label_for_face(tile.face)
			label.visible = not face_art.visible
			_slots[index].add_theme_stylebox_override("panel", _slot_style(Color("fffdf4"), Color("35636b")))
		else:
			face_art.texture = null
			face_art.visible = false
			label.text = str(index + 1)
			label.visible = true
			_slots[index].add_theme_stylebox_override("panel", _slot_style(Color("202827"), Color("46504e")))

		label.add_theme_color_override("font_color", Color("202625") if occupied else Color("68716f"))

	match _game.status:
		"won":
			_status_label.text = "Victory - %d pairs" % _game.tray.resolved_pair_count
		"lost":
			_status_label.text = "Tray full - run over"
		_:
			_status_label.text = "%d / %d unresolved  |  %d pairs" % [
				_game.tray.tiles.size(),
				_game.tray.capacity,
				_game.tray.resolved_pair_count,
			]


func _build() -> void:
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override("panel", _panel_style())
	add_child(background)

	var title_label := Label.new()
	title_label.text = "Tray"
	title_label.position = Vector2(MARGIN, 4.0)
	title_label.add_theme_font_size_override("font_size", 18)
	add_child(title_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.position = Vector2(70.0, 6.0)
	_status_label.add_theme_color_override("font_color", Color("bdc9c6"))
	add_child(_status_label)

	for index in range(SLOT_COUNT):
		var slot := PanelContainer.new()
		var face_art := TextureRect.new()
		face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		slot.add_child(face_art)
		slot.add_child(label)
		add_child(slot)
		_slots.append(slot)
		_slot_labels.append(label)
		_slot_art.append(face_art)

func _layout() -> void:
	if _slots.is_empty():
		return

	_status_label.size = Vector2(maxf(80.0, size.x - 80.0 - MARGIN), 24.0)
	var body_y := HEADER_HEIGHT
	var body_height := maxf(34.0, size.y - body_y - MARGIN)
	var slots_width := maxf(120.0, size.x - MARGIN * 2.0)
	var slot_width := (slots_width - GAP * (SLOT_COUNT - 1)) / SLOT_COUNT

	for index in range(SLOT_COUNT):
		_slots[index].position = Vector2(MARGIN + index * (slot_width + GAP), body_y)
		_slots[index].size = Vector2(slot_width, body_height)
		_slot_art[index].position = Vector2(4.0, 3.0)
		_slot_art[index].size = Vector2(maxf(1.0, slot_width - 8.0), maxf(1.0, body_height - 6.0))

func slot_global_rect(index: int) -> Rect2:
	if index < 0 or index >= _slots.size():
		return Rect2()
	return _slots[index].get_global_rect()


func create_tile_preview(index: int) -> Control:
	if index < 0 or index >= _slots.size() or index >= _game.tray.tiles.size():
		return null
	var preview := Panel.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override("panel", _slot_style(Color("fffdf4"), Color("35636b")))
	var source_art: TextureRect = _slot_art[index]
	if source_art.texture != null:
		var face_art := TextureRect.new()
		face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.add_child(face_art)
		face_art.texture = source_art.texture
	return preview


func _slot_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a281c")
	style.border_color = Color("7b7041")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
