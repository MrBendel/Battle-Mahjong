extends Control
class_name TrayView

signal undo_requested
signal restart_requested

const SLOT_COUNT := 4
const HEADER_HEIGHT := 32.0
const MARGIN := 10.0
const GAP := 6.0

var _game: Variant
var _status_label: Label
var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _undo_button: Button
var _restart_button: Button


func _init(game_state: Variant) -> void:
	_game = game_state


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
		if occupied:
			var tile: Variant = _game.tray.tiles[index]
			label.text = _face_label(tile.face.value)
			_slots[index].add_theme_stylebox_override("panel", _slot_style(_face_color(tile.face.value), Color("687673")))
		else:
			label.text = str(index + 1)
			_slots[index].add_theme_stylebox_override("panel", _slot_style(Color("202827"), Color("46504e")))

		label.add_theme_color_override("font_color", Color("202625") if occupied else Color("68716f"))

	_undo_button.disabled = not _game.call("can_undo")
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
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		slot.add_child(label)
		add_child(slot)
		_slots.append(slot)
		_slot_labels.append(label)

	_undo_button = Button.new()
	_undo_button.text = "Undo"
	_undo_button.tooltip_text = "Return the latest unresolved tile"
	_undo_button.focus_mode = Control.FOCUS_NONE
	_undo_button.pressed.connect(func() -> void: undo_requested.emit())
	add_child(_undo_button)

	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.tooltip_text = "Restart this seeded deal"
	_restart_button.focus_mode = Control.FOCUS_NONE
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	add_child(_restart_button)


func _layout() -> void:
	if _slots.is_empty():
		return

	_status_label.size = Vector2(maxf(80.0, size.x - 80.0 - MARGIN), 24.0)
	var body_y := HEADER_HEIGHT
	var body_height := maxf(34.0, size.y - body_y - MARGIN)
	var undo_width := 58.0
	var restart_width := 70.0
	var controls_width := undo_width + restart_width + GAP
	var slots_width := maxf(120.0, size.x - MARGIN * 2.0 - controls_width - GAP)
	var slot_width := (slots_width - GAP * (SLOT_COUNT - 1)) / SLOT_COUNT

	for index in range(SLOT_COUNT):
		_slots[index].position = Vector2(MARGIN + index * (slot_width + GAP), body_y)
		_slots[index].size = Vector2(slot_width, body_height)

	var controls_x := MARGIN + slots_width + GAP
	_undo_button.position = Vector2(controls_x, body_y)
	_undo_button.size = Vector2(undo_width, body_height)
	_restart_button.position = Vector2(controls_x + undo_width + GAP, body_y)
	_restart_button.size = Vector2(restart_width, body_height)


func _face_label(value: String) -> String:
	var identity := int(value) - 1
	var families := ["BAM", "DOT", "CHR", "HON"]
	return "%s\n%d" % [families[identity / 6], identity % 6 + 1]


func _face_color(value: String) -> Color:
	var identity := int(value) - 1
	var colors := [Color("d8ead6"), Color("f0d7d2"), Color("d4e3f2"), Color("f1e1b8")]
	return colors[identity / 6]


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
