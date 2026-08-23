extends Control
class_name TrayView

const TileSkinScript := preload("res://scripts/presentation/tile_skin.gd")

const SLOT_COUNT := 4
const MARGIN := 10.0
const GAP := 8.0

var _game: Variant
var _status_label: Label
var _slots: Array[Panel] = []
var _slot_ink_outlines: Array[TextureRect] = []
var _slot_bases: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _slot_art: Array[TextureRect] = []
var _slot_modifiers: Array[Label] = []
var _tile_skin: Variant
var _tile_visual_size := Vector2(32.0, 40.0)
var _suppressed_tile_ids := {}


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
	_suppressed_tile_ids.clear()
	refresh()


func set_tile_visual_size(tile_size: Vector2) -> void:
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return
	_tile_visual_size = tile_size
	_layout()


func minimum_height_for_tile(tile_size: Vector2) -> float:
	var expansion: Array = _tile_skin.layout_presentation.get("ink_outline_expansion_ratio", [0.055, 0.04])
	var offset: Array = _tile_skin.layout_presentation.get("ink_outline_offset_ratio", [-0.004, 0.006])
	var outline_bottom_ratio := float(expansion[1]) * 0.5 + maxf(0.0, float(offset[1]))
	return ceilf(26.0 + tile_size.y * (1.0 + outline_bottom_ratio) + 8.0)


func minimum_width_for_tile(tile_size: Vector2) -> float:
	var expansion: Array = _tile_skin.layout_presentation.get("ink_outline_expansion_ratio", [0.055, 0.04])
	return ceilf(tile_size.x * (float(SLOT_COUNT) + float(expansion[0])) + GAP * float(SLOT_COUNT - 1))


func suppress_tile(tile_id: String) -> void:
	_suppressed_tile_ids[tile_id] = true
	refresh()


func reveal_tile(tile_id: String) -> void:
	_suppressed_tile_ids.erase(tile_id)
	refresh()


func refresh() -> void:
	if _game == null or _slots.is_empty():
		return

	for index in range(SLOT_COUNT):
		var occupied: bool = index < _game.tray.tiles.size()
		var label := _slot_labels[index]
		var ink_outline := _slot_ink_outlines[index]
		var base_art := _slot_bases[index]
		var face_art := _slot_art[index]
		var modifier_label := _slot_modifiers[index]
		var tile: Variant = _game.tray.tiles[index] if occupied else null
		var presented: bool = occupied and not _suppressed_tile_ids.has(tile.id)
		if presented:
			_tile_skin.configure_ink_outline(ink_outline)
			base_art.texture = _tile_skin.tile_base_texture()
			base_art.visible = base_art.texture != null
			face_art.texture = _tile_skin.texture_for_face(tile.face)
			face_art.visible = face_art.texture != null
			label.text = _tile_skin.label_for_face(tile.face)
			label.visible = not face_art.visible
			modifier_label.text = _modifier_symbol(tile)
			modifier_label.visible = not modifier_label.text.is_empty()
			_slots[index].add_theme_stylebox_override("panel", _tile_style())
		else:
			ink_outline.visible = false
			base_art.texture = _tile_skin.tile_base_texture() if occupied else null
			base_art.visible = false
			face_art.texture = _tile_skin.texture_for_face(tile.face) if occupied else null
			face_art.visible = false
			modifier_label.text = _modifier_symbol(tile) if occupied else ""
			modifier_label.visible = false
			label.text = str(index + 1)
			label.visible = true
			_slots[index].add_theme_stylebox_override("panel", _empty_slot_style())

		label.add_theme_color_override("font_color", Color("202625") if presented else Color("68716f"))

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
		var slot := Panel.new()
		var ink_outline := TextureRect.new()
		ink_outline.name = "InkOutline"
		_tile_skin.configure_ink_outline(ink_outline)
		ink_outline.visible = false
		var base_art := TextureRect.new()
		base_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		base_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var face_art := TextureRect.new()
		face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		var modifier_label := Label.new()
		modifier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modifier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		modifier_label.add_theme_color_override("font_color", Color("fff7cf"))
		slot.add_child(ink_outline)
		slot.add_child(base_art)
		slot.add_child(face_art)
		slot.add_child(label)
		slot.add_child(modifier_label)
		add_child(slot)
		_slots.append(slot)
		_slot_ink_outlines.append(ink_outline)
		_slot_bases.append(base_art)
		_slot_labels.append(label)
		_slot_art.append(face_art)
		_slot_modifiers.append(modifier_label)


func _layout() -> void:
	if _slots.is_empty():
		return

	_status_label.size = Vector2(maxf(80.0, size.x - 80.0 - MARGIN), 24.0)
	var group_width := _tile_visual_size.x * SLOT_COUNT + GAP * (SLOT_COUNT - 1)
	var group_x := (size.x - group_width) * 0.5
	var body_y := maxf(26.0, size.y - _tile_visual_size.y - 6.0)
	var active_geometry: Dictionary = _tile_skin.active_geometry()
	var safe_area: Array = active_geometry.get("face_safe_area", [92, 104, 328, 400])
	var source_size: Array = active_geometry.get("source_size", [512, 640])

	for index in range(SLOT_COUNT):
		_slots[index].position = Vector2(group_x + index * (_tile_visual_size.x + GAP), body_y)
		_slots[index].size = _tile_visual_size
		_slot_bases[index].position = Vector2.ZERO
		_slot_bases[index].size = _tile_visual_size
		_slot_art[index].position = Vector2(
			float(safe_area[0]) / float(source_size[0]) * _tile_visual_size.x,
			float(safe_area[1]) / float(source_size[1]) * _tile_visual_size.y
		)
		_slot_art[index].size = Vector2(
			float(safe_area[2]) / float(source_size[0]) * _tile_visual_size.x,
			float(safe_area[3]) / float(source_size[1]) * _tile_visual_size.y
		)
		_slot_labels[index].position = Vector2.ZERO
		_slot_labels[index].size = _tile_visual_size
		_slot_modifiers[index].position = Vector2(_tile_visual_size.x * 0.68, _tile_visual_size.y * 0.02)
		_slot_modifiers[index].size = Vector2(_tile_visual_size.x * 0.30, _tile_visual_size.y * 0.23)
		_slot_modifiers[index].add_theme_font_size_override("font_size", clampi(int(_tile_visual_size.x * 0.19), 8, 15))


func slot_global_rect(index: int) -> Rect2:
	if index < 0 or index >= _slots.size():
		return Rect2()
	return _slots[index].get_global_rect()


func slot_visual_global_rect(index: int) -> Rect2:
	if index < 0 or index >= _slots.size():
		return Rect2()
	return _slots[index].get_global_rect().merge(_slot_ink_outlines[index].get_global_rect())


func create_tile_preview(index: int) -> Control:
	if index < 0 or index >= _slots.size() or index >= _game.tray.tiles.size():
		return null
	var preview := Panel.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override("panel", _tile_style())
	var ink_outline := TextureRect.new()
	ink_outline.name = "InkOutline"
	_tile_skin.configure_ink_outline(ink_outline)
	preview.add_child(ink_outline)
	var base_art := TextureRect.new()
	base_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_art.texture = _tile_skin.tile_base_texture()
	base_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(base_art)
	var source_art: TextureRect = _slot_art[index]
	if source_art.texture != null:
		var face_art := TextureRect.new()
		face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face_art.position = source_art.position
		face_art.size = source_art.size
		preview.add_child(face_art)
		face_art.texture = source_art.texture
	var source_modifier: Label = _slot_modifiers[index]
	if not source_modifier.text.is_empty():
		var modifier := Label.new()
		modifier.text = source_modifier.text
		modifier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modifier.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		modifier.position = source_modifier.position
		modifier.size = source_modifier.size
		modifier.add_theme_color_override("font_color", Color("fff7cf"))
		modifier.add_theme_font_size_override("font_size", source_modifier.get_theme_font_size("font_size"))
		preview.add_child(modifier)
	return preview


func _tile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	return style


func _empty_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202827")
	style.border_color = Color("46504e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


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


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a281c")
	style.border_color = Color("7b7041")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
