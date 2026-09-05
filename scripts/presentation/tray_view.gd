extends Control
class_name TrayView

const TileSkinScript := preload("res://scripts/presentation/tile_skin.gd")
const QUEUE_REPEAT_PATH := "res://assets/UI/tile-queue/queue-repeat.png"
const QUEUE_CAP_PATH := "res://assets/UI/tile-queue/queue-cap.png"
const TRAY_PLUS_ONE_ICON_PATH := "res://game-assets/modifiers/tile-overlays/tray_plus_one.png"
const MILA_BOLD_PATH := "res://assets/fonts/mila-script-sans-bold-tight.tres"

const MIN_SLOT_COUNT := 2
const MAX_SLOT_COUNT := 6
const MARGIN := 10.0
const GAP := 8.0
const FIGMA_CAP_SIZE := Vector2(24.968, 115.0)
const FIGMA_SLOT_SIZE := Vector2(62.42, 115.0)
const FIGMA_TILE_RECT := Rect2(7.11, 17.7, 46.685, 60.121)
const QUEUE_ART_SEAM_OVERLAP := 1.0
const PORTRAIT_TILE_X_NUDGE := -1.5

var _game: Variant
var _status_label: Label
var _legacy_background: Panel
var _title_label: Label
var _slots: Array[Panel] = []
var _slot_ink_outlines: Array[TextureRect] = []
var _slot_bases: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _slot_art: Array[TextureRect] = []
var _slot_modifiers: Array[TextureRect] = []
var _tile_skin: Variant
var _tile_visual_size := Vector2(32.0, 40.0)
var _suppressed_tile_ids := {}
var _portrait_style := false
var _queue_left_cap: TextureRect
var _queue_right_cap: TextureRect
var _queue_repeats: Array[TextureRect] = []
var _bonus_icon: TextureRect
var _bonus_label: Label
var _rendered_capacity := -1
var _bonus_tween: Tween
var capacity_feedback_count := 0


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


func set_portrait_style(enabled: bool) -> void:
	_portrait_style = enabled
	_update_style_visibility()
	_layout()


func set_tile_visual_size(tile_size: Vector2) -> void:
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return
	_tile_visual_size = tile_size
	_layout()


func minimum_height_for_tile(tile_size: Vector2) -> float:
	if _portrait_style:
		return ceilf(FIGMA_CAP_SIZE.y * _portrait_scale(tile_size))
	var expansion: Array = _tile_skin.layout_presentation.get("ink_outline_expansion_ratio", [0.055, 0.04])
	var offset: Array = _tile_skin.layout_presentation.get("ink_outline_offset_ratio", [-0.004, 0.006])
	var outline_bottom_ratio := float(expansion[1]) * 0.5 + maxf(0.0, float(offset[1]))
	return ceilf(26.0 + tile_size.y * (1.0 + outline_bottom_ratio) + 8.0)


func minimum_width_for_tile(tile_size: Vector2) -> float:
	if _portrait_style:
		return ceilf((FIGMA_CAP_SIZE.x * 2.0 + FIGMA_SLOT_SIZE.x * _slot_count()) * _portrait_scale(tile_size))
	var expansion: Array = _tile_skin.layout_presentation.get("ink_outline_expansion_ratio", [0.055, 0.04])
	return ceilf(tile_size.x * (float(_slot_count()) + float(expansion[0])) + GAP * float(_slot_count() - 1))


func suppress_tile(tile_id: String) -> void:
	_suppressed_tile_ids[tile_id] = true
	refresh()


func reveal_tile(tile_id: String) -> void:
	_suppressed_tile_ids.erase(tile_id)
	refresh()


func refresh() -> void:
	if _game == null or _slots.is_empty():
		return
	var current_capacity := _slot_count()
	if current_capacity != _rendered_capacity:
		_rendered_capacity = current_capacity
		_layout()

	for index in range(MAX_SLOT_COUNT):
		var enabled := index < current_capacity
		_slots[index].visible = enabled
		_queue_repeats[index].visible = _portrait_style and enabled
		_queue_repeats[index].modulate = Color("baffd8") \
			if _is_bonus_slot(index) else Color.WHITE
		if not enabled:
			continue
		var occupied: bool = index < _game.tray.tiles.size()
		var label := _slot_labels[index]
		var ink_outline := _slot_ink_outlines[index]
		var base_art := _slot_bases[index]
		var face_art := _slot_art[index]
		var modifier_art: TextureRect = _slot_modifiers[index]
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
			var modifier: Dictionary = _game.definition.modifier_for_tile(tile.id)
			_tile_skin.configure_modifier_art(modifier_art)
			modifier_art.texture = null if modifier.is_empty() else _tile_skin.modifier_texture(str(modifier.type))
			modifier_art.visible = modifier_art.texture != null
			_slots[index].add_theme_stylebox_override("panel", _tile_style())
		else:
			ink_outline.visible = false
			base_art.texture = _tile_skin.tile_base_texture() if occupied else null
			base_art.visible = false
			face_art.texture = _tile_skin.texture_for_face(tile.face) if occupied else null
			face_art.visible = false
			modifier_art.texture = null
			modifier_art.visible = false
			label.text = str(index + 1)
			label.visible = not _portrait_style
			_slots[index].add_theme_stylebox_override("panel", _tile_style() if _portrait_style else _empty_slot_style())

		label.add_theme_color_override("font_color", Color("202625") if presented else Color("68716f"))
	var snapshot: Variant = _game.call("current_snapshot")
	var bonus_active := int(snapshot.tray_bonus_capacity) > 0
	_bonus_icon.visible = bonus_active
	_bonus_label.visible = bonus_active
	_bonus_label.text = "+1  %d PAIRS" % int(snapshot.tray_bonus_pairs_remaining)

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
	_legacy_background = Panel.new()
	_legacy_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_legacy_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legacy_background.add_theme_stylebox_override("panel", _panel_style())
	add_child(_legacy_background)

	_title_label = Label.new()
	_title_label.text = "Tray"
	_title_label.position = Vector2(MARGIN, 4.0)
	_title_label.add_theme_font_size_override("font_size", 18)
	add_child(_title_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.position = Vector2(70.0, 6.0)
	_status_label.add_theme_color_override("font_color", Color("bdc9c6"))
	add_child(_status_label)

	_queue_left_cap = _queue_art(_load_texture(QUEUE_CAP_PATH))
	add_child(_queue_left_cap)
	for index in range(MAX_SLOT_COUNT):
		var repeat := _queue_art(_load_texture(QUEUE_REPEAT_PATH))
		add_child(repeat)
		_queue_repeats.append(repeat)
	_queue_right_cap = _queue_art(_load_texture(QUEUE_CAP_PATH))
	_queue_right_cap.flip_h = true
	add_child(_queue_right_cap)
	_bonus_icon = _queue_art(_load_texture(TRAY_PLUS_ONE_ICON_PATH))
	_bonus_icon.visible = false
	add_child(_bonus_icon)
	_bonus_label = Label.new()
	var font := _load_font(MILA_BOLD_PATH)
	if font != null:
		_bonus_label.add_theme_font_override("font", font)
	_bonus_label.add_theme_font_size_override("font_size", 9)
	_bonus_label.add_theme_color_override("font_color", Color("baffd8"))
	_bonus_label.add_theme_color_override("font_outline_color", Color("081a12"))
	_bonus_label.add_theme_constant_override("outline_size", 3)
	_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bonus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bonus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus_label.visible = false
	add_child(_bonus_label)

	for index in range(MAX_SLOT_COUNT):
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
		var modifier_art := TextureRect.new()
		modifier_art.name = "ModifierArt"
		_tile_skin.configure_modifier_art(modifier_art)
		slot.add_child(ink_outline)
		slot.add_child(base_art)
		slot.add_child(face_art)
		slot.add_child(label)
		slot.add_child(modifier_art)
		add_child(slot)
		_slots.append(slot)
		_slot_ink_outlines.append(ink_outline)
		_slot_bases.append(base_art)
		_slot_labels.append(label)
		_slot_art.append(face_art)
		_slot_modifiers.append(modifier_art)
	move_child(_bonus_icon, get_child_count() - 1)
	move_child(_bonus_label, get_child_count() - 1)
	_update_style_visibility()


func _layout() -> void:
	if _slots.is_empty():
		return
	for slot in _slots:
		slot.size = _tile_visual_size
	if _portrait_style:
		_layout_portrait()
		return

	_status_label.size = Vector2(maxf(80.0, size.x - 80.0 - MARGIN), 24.0)
	var group_width := _tile_visual_size.x * _slot_count() + GAP * (_slot_count() - 1)
	var group_x := (size.x - group_width) * 0.5
	var body_y := maxf(26.0, size.y - _tile_visual_size.y - 6.0)
	var active_geometry: Dictionary = _tile_skin.active_geometry()
	var safe_area: Array = active_geometry.get("face_safe_area", [92, 104, 328, 400])
	var source_size: Array = active_geometry.get("source_size", [512, 640])

	for index in range(_slot_count()):
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
		_tile_skin.configure_modifier_art(_slot_modifiers[index])
	_layout_bonus_legacy(group_x, body_y)


func _layout_portrait() -> void:
	var scale := minf(_portrait_scale(_tile_visual_size), size.y / FIGMA_CAP_SIZE.y)
	var queue_width := (FIGMA_CAP_SIZE.x * 2.0 + FIGMA_SLOT_SIZE.x * _slot_count()) * scale
	var queue_height := FIGMA_CAP_SIZE.y * scale
	var origin := Vector2((size.x - queue_width) * 0.5, (size.y - queue_height) * 0.5)
	_queue_left_cap.position = origin
	_queue_left_cap.size = Vector2(FIGMA_CAP_SIZE.x + QUEUE_ART_SEAM_OVERLAP, FIGMA_CAP_SIZE.y) * scale
	for index in range(MAX_SLOT_COUNT):
		_queue_repeats[index].position = origin + Vector2((FIGMA_CAP_SIZE.x + FIGMA_SLOT_SIZE.x * index) * scale, 0.0)
		_queue_repeats[index].size = Vector2(FIGMA_SLOT_SIZE.x + QUEUE_ART_SEAM_OVERLAP, FIGMA_SLOT_SIZE.y) * scale
	_queue_right_cap.position = origin + Vector2((FIGMA_CAP_SIZE.x + FIGMA_SLOT_SIZE.x * _slot_count() - QUEUE_ART_SEAM_OVERLAP) * scale, 0.0)
	_queue_right_cap.size = Vector2(FIGMA_CAP_SIZE.x + QUEUE_ART_SEAM_OVERLAP, FIGMA_CAP_SIZE.y) * scale

	var active_geometry: Dictionary = _tile_skin.active_geometry()
	var safe_area: Array = active_geometry.get("face_safe_area", [92, 104, 328, 400])
	var source_size: Array = active_geometry.get("source_size", [512, 640])
	for index in range(_slot_count()):
		var repeat_origin := origin + Vector2((FIGMA_CAP_SIZE.x + FIGMA_SLOT_SIZE.x * index) * scale, 0.0)
		var tile_center := repeat_origin + Vector2(
			(FIGMA_SLOT_SIZE.x * 0.5 + PORTRAIT_TILE_X_NUDGE) * scale,
			FIGMA_TILE_RECT.get_center().y * scale
		)
		var slot_rect := Rect2(
			tile_center - _tile_visual_size * 0.5,
			_tile_visual_size
		)
		_slots[index].position = slot_rect.position
		_slots[index].size = slot_rect.size
		_slots[index].add_theme_stylebox_override("panel", _tile_style())
		_slot_bases[index].position = Vector2.ZERO
		_slot_bases[index].size = slot_rect.size
		_slot_art[index].position = Vector2(
			float(safe_area[0]) / float(source_size[0]) * slot_rect.size.x,
			float(safe_area[1]) / float(source_size[1]) * slot_rect.size.y
		)
		_slot_art[index].size = Vector2(
			float(safe_area[2]) / float(source_size[0]) * slot_rect.size.x,
			float(safe_area[3]) / float(source_size[1]) * slot_rect.size.y
		)
		_slot_labels[index].position = Vector2.ZERO
		_slot_labels[index].size = slot_rect.size
		_tile_skin.configure_modifier_art(_slot_modifiers[index])
	_layout_bonus_portrait(origin, scale)


func play_capacity_feedback() -> void:
	if not _bonus_icon.visible:
		return
	if _bonus_tween != null and _bonus_tween.is_valid():
		_bonus_tween.kill()
	capacity_feedback_count += 1
	_bonus_icon.pivot_offset = _bonus_icon.size * 0.5
	_bonus_icon.scale = Vector2(0.45, 0.45)
	_bonus_tween = create_tween()
	_bonus_tween.tween_property(_bonus_icon, "scale", Vector2(1.22, 1.22), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bonus_tween.tween_property(_bonus_icon, "scale", Vector2.ONE, 0.12)


func slot_global_rect(index: int) -> Rect2:
	if index < 0 or index >= _slot_count():
		return Rect2()
	return _slots[index].get_global_rect()


func slot_visual_global_rect(index: int) -> Rect2:
	if index < 0 or index >= _slot_count():
		return Rect2()
	return _slots[index].get_global_rect().merge(_slot_ink_outlines[index].get_global_rect())


func create_tile_preview(index: int) -> Control:
	if index < 0 or index >= _slot_count() or index >= _game.tray.tiles.size():
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
	var source_modifier: TextureRect = _slot_modifiers[index]
	if source_modifier.visible and source_modifier.texture != null:
		var modifier_art := TextureRect.new()
		modifier_art.name = "ModifierArt"
		_tile_skin.configure_modifier_art(modifier_art)
		modifier_art.texture = source_modifier.texture
		preview.add_child(modifier_art)
	return preview


func _slot_count() -> int:
	return clampi(_game.tray.capacity, MIN_SLOT_COUNT, MAX_SLOT_COUNT)


func _is_bonus_slot(index: int) -> bool:
	if _game == null:
		return false
	var snapshot: Variant = _game.call("current_snapshot")
	return int(snapshot.tray_bonus_capacity) > 0 \
		and index == int(_game.definition.tray_capacity())


func _layout_bonus_portrait(origin: Vector2, scale: float) -> void:
	if not _bonus_icon.visible and int(_game.call("current_snapshot").tray_bonus_capacity) <= 0:
		return
	var bonus_index := clampi(int(_game.definition.tray_capacity()), 0, MAX_SLOT_COUNT - 1)
	var repeat_origin := origin + Vector2(
		(FIGMA_CAP_SIZE.x + FIGMA_SLOT_SIZE.x * bonus_index) * scale,
		0.0
	)
	_bonus_icon.position = repeat_origin + Vector2(5.0, 86.0) * scale
	_bonus_icon.size = Vector2(17.0, 17.0) * scale
	_bonus_label.position = repeat_origin + Vector2(20.0, 86.0) * scale
	_bonus_label.size = Vector2(39.0, 17.0) * scale
	_bonus_label.add_theme_font_size_override("font_size", maxi(7, roundi(8.0 * scale)))


func _layout_bonus_legacy(group_x: float, body_y: float) -> void:
	var bonus_index := clampi(int(_game.definition.tray_capacity()), 0, MAX_SLOT_COUNT - 1)
	_bonus_icon.position = Vector2(
		group_x + bonus_index * (_tile_visual_size.x + GAP),
		body_y - 18.0
	)
	_bonus_icon.size = Vector2(18.0, 18.0)
	_bonus_label.position = _bonus_icon.position + Vector2(17.0, 0.0)
	_bonus_label.size = Vector2(maxf(38.0, _tile_visual_size.x - 17.0), 18.0)


func _portrait_scale(tile_size: Vector2) -> float:
	return maxf(tile_size.x / FIGMA_TILE_RECT.size.x, tile_size.y / FIGMA_TILE_RECT.size.y)


func _update_style_visibility() -> void:
	if _legacy_background == null:
		return
	_legacy_background.visible = not _portrait_style
	_title_label.visible = not _portrait_style
	_status_label.visible = not _portrait_style
	_queue_left_cap.visible = _portrait_style
	_queue_right_cap.visible = _portrait_style
	for index in range(_queue_repeats.size()):
		_queue_repeats[index].visible = _portrait_style and index < _slot_count()


func _queue_art(texture: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	art.material = material
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


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


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a281c")
	style.border_color = Color("7b7041")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


static func _load_texture(asset_path: String) -> Texture2D:
	if ResourceLoader.exists(asset_path):
		return load(asset_path) as Texture2D
	elif FileAccess.file_exists(asset_path):
		var img := Image.load_from_file(asset_path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


static func _load_font(asset_path: String) -> Font:
	if ResourceLoader.exists(asset_path):
		return load(asset_path) as Font
	elif FileAccess.file_exists(asset_path):
		var font := FontFile.new()
		if font.load_dynamic_font(asset_path) == OK:
			return font
	return null
