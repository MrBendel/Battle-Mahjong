extends Control
class_name BoardView

const TileSkinScript := preload("res://scripts/presentation/tile_skin.gd")

signal tile_selected(tile_id: String)
signal locked_tile_tapped(tile_id: String)

const HEADER_HEIGHT := 48.0
const BOARD_MARGIN := 14.0
const COMPACT_HEADER_HEIGHT := 6.0
const COMPACT_BOARD_MARGIN := 4.0
const DEPTH_Z_STRIDE := 2
const TILE_SURFACE_Z_OFFSET := 1
const SHADOW_Z_OFFSET := -1
const HINT_CYCLE_SECONDS := 1.2
const HINT_BRIGHTNESS_GAIN := 0.10
const HINT_GLOW_MIN_ALPHA := 0.04
const HINT_GLOW_MAX_ALPHA := 0.18
const HINT_BOB_RATIO := 0.035

var _game: Variant
var _tile_buttons: Dictionary = {}
var _shadow_art: Dictionary = {}
var _ink_outlines: Dictionary = {}
var _base_art: Dictionary = {}
var _back_art: Dictionary = {}
var _back_design_art: Dictionary = {}
var _face_art: Dictionary = {}
var _hint_glows: Dictionary = {}
var _blocked_overlays: Dictionary = {}
var _modifier_labels: Dictionary = {}
var _title_label: Label
var _status_label: Label
var _tile_layer: Control
var _tile_skin: Variant
var _delete_pair_armed := false
var _audio_player: AudioStreamPlayer
var _audio_playback: Variant
var _negative_feedback_count := 0
var _suppressed_tile_ids := {}
var _compact_mode := false
var _hinted_tile_ids := {}
var _tile_layout_positions := {}
var _hint_elapsed := 0.0
var _flip_tweens: Dictionary = {}


func _init(game_state: Variant, tile_skin: Variant = null) -> void:
	_game = game_state
	_tile_skin = TileSkinScript.new() if tile_skin == null else tile_skin


func _ready() -> void:
	_build()
	_rebuild_tiles()
	resized.connect(_layout_tiles)
	_layout_tiles()
	set_process(false)


func _process(delta: float) -> void:
	_hint_elapsed = fmod(_hint_elapsed + delta, HINT_CYCLE_SECONDS)
	_apply_hint_presentation()


func set_game_state(game_state: Variant) -> void:
	_game = game_state
	_delete_pair_armed = false
	_suppressed_tile_ids.clear()
	_rebuild_tiles()
	_layout_tiles()


func reset_input_state() -> void:
	_rebuild_tiles()
	_layout_tiles()


func set_delete_pair_armed(armed: bool) -> void:
	_delete_pair_armed = armed
	refresh()


func set_compact_mode(compact: bool) -> void:
	if _compact_mode == compact:
		return
	_compact_mode = compact
	_title_label.visible = not compact
	_status_label.visible = not compact
	_layout_tiles()


func suppress_tile(tile_id: String) -> void:
	_suppressed_tile_ids[tile_id] = true
	refresh()


func reveal_tile(tile_id: String) -> void:
	_suppressed_tile_ids.erase(tile_id)
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
	for tween in _flip_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_flip_tweens.clear()
	for button in _tile_buttons.values():
		if button.get_parent() == _tile_layer:
			_tile_layer.remove_child(button)
		button.queue_free()
	_tile_buttons.clear()
	_shadow_art.clear()
	_ink_outlines.clear()
	_base_art.clear()
	_back_art.clear()
	_back_design_art.clear()
	_face_art.clear()
	_hint_glows.clear()
	_blocked_overlays.clear()
	_modifier_labels.clear()
	_tile_layout_positions.clear()
	_hinted_tile_ids.clear()
	_hint_elapsed = 0.0
	set_process(false)

	for tile in _game.board.tiles:
		var button := Button.new()
		button.name = tile.id
		button.tooltip_text = _tile_tooltip(tile)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_tile_pressed.bind(tile.id))
		button.button_down.connect(_set_tile_interaction_brightness.bind(tile.id, true))
		button.button_up.connect(_set_tile_interaction_brightness.bind(tile.id, false))
		button.mouse_entered.connect(_set_tile_interaction_brightness.bind(tile.id, true))
		button.mouse_exited.connect(_set_tile_interaction_brightness.bind(tile.id, false))

		var shadow_art := TextureRect.new()
		shadow_art.name = "DepthShadow"
		shadow_art.z_index = SHADOW_Z_OFFSET
		shadow_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(shadow_art)

		var ink_outline := TextureRect.new()
		ink_outline.name = "InkOutline"
		_tile_skin.configure_ink_outline(ink_outline)
		button.add_child(ink_outline)

		var base_art := TextureRect.new()
		base_art.name = "BaseArt"
		base_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		base_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		base_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(base_art)

		var back_art := TextureRect.new()
		back_art.name = "BackArt"
		back_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(back_art)

		var back_design_art := TextureRect.new()
		back_design_art.name = "BackDesignArt"
		_tile_skin.configure_back_design(back_design_art)
		button.add_child(back_design_art)

		var face_art := TextureRect.new()
		face_art.name = "FaceArt"
		face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(face_art)

		var hint_glow := TextureRect.new()
		hint_glow.name = "HintGlow"
		hint_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hint_glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hint_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var glow_material := CanvasItemMaterial.new()
		glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		hint_glow.material = glow_material
		hint_glow.visible = false
		button.add_child(hint_glow)

		var blocked_overlay := TextureRect.new()
		blocked_overlay.name = "BlockedOverlay"
		blocked_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blocked_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		blocked_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		blocked_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(blocked_overlay)

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
		_shadow_art[tile.id] = shadow_art
		_ink_outlines[tile.id] = ink_outline
		_base_art[tile.id] = base_art
		_back_art[tile.id] = back_art
		_back_design_art[tile.id] = back_design_art
		_face_art[tile.id] = face_art
		_hint_glows[tile.id] = hint_glow
		_blocked_overlays[tile.id] = blocked_overlay
		_modifier_labels[tile.id] = modifier_label

	refresh()


func refresh() -> void:
	var active_count: int = _game.board.call("active_tiles").size()
	var max_depth := 0
	for board_tile in _game.board.tiles:
		max_depth = maxi(max_depth, board_tile.position.z)
	var selectable_ids := {}
	var revealable_ids := {}
	var visible_ids := {}
	var hinted_ids := {}
	for hinted_tile_id in _game.call("hinted_tile_ids"):
		hinted_ids[hinted_tile_id] = true
	_hinted_tile_ids = hinted_ids
	if _hinted_tile_ids.is_empty():
		_hint_elapsed = 0.0
	set_process(not _hinted_tile_ids.is_empty())
	for tile in _game.board.call("selectable_tiles"):
		selectable_ids[tile.id] = true
	for tile in _game.board.call("revealable_tiles"):
		revealable_ids[tile.id] = true
	for tile in _game.board.call("visible_tiles"):
		visible_ids[tile.id] = true

	for tile in _game.board.tiles:
		var button: Button = _tile_buttons[tile.id]
		var active: bool = _game.board.call("is_tile_active", tile.id)
		button.visible = active and not _suppressed_tile_ids.has(tile.id)
		if not active:
			continue

		var face_down: bool = _game.board.call("is_tile_face_down", tile.id)
		var revealed_flipped: bool = _game.board.call("is_tile_revealed_flipped", tile.id)
		var revealed_tray_match: bool = revealed_flipped \
			and not _game.call("flipped_match_candidate", tile.id).is_empty()
		var revealed_playable: bool = revealed_flipped \
			and _game.definition.rules_version >= 12 \
			and _game.board.call("is_tile_accessible", tile.id)
		var selectable: bool = (_delete_pair_armed and visible_ids.has(tile.id) and not face_down \
			or not _delete_pair_armed and (selectable_ids.has(tile.id) \
				or revealable_ids.has(tile.id) or revealed_playable \
				or _game.definition.rules_version < 12 and revealed_tray_match)) \
			and _game.status == "playing"
		var visually_active: bool = selectable or revealed_flipped
		button.tooltip_text = _tile_tooltip(tile)
		button.disabled = _game.status != "playing"
		button.set_meta("targetable", selectable)
		button.set_meta("face_down", face_down)
		button.set_meta("revealed_flipped", revealed_flipped)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if selectable else Control.CURSOR_FORBIDDEN
		var depth_brightness := _depth_brightness(tile.position.z, max_depth)
		var presentation_brightness := 1.0 if visually_active else depth_brightness
		button.modulate = Color(presentation_brightness, presentation_brightness, presentation_brightness)
		button.set_meta("presentation_brightness", presentation_brightness)
		button.set_meta("depth_brightness", depth_brightness)
		_apply_tile_style(button, visually_active, face_down)
		if _delete_pair_armed and selectable:
			button.add_theme_stylebox_override("normal", _tile_style(Color("fff8e8"), Color("ef496f"), 4, Vector2(0.0, 3.0)))
		var texture: Texture2D = _tile_skin.texture_for_face(tile.face)
		var shadow_art: TextureRect = _shadow_art[tile.id]
		shadow_art.texture = _tile_skin.tile_base_texture()
		shadow_art.modulate = Color(0.02, 0.025, 0.025, float(_tile_skin.depth_presentation.get("shadow_opacity", 0.42)))
		shadow_art.visible = shadow_art.texture != null
		var ink_outline: TextureRect = _ink_outlines[tile.id]
		_tile_skin.configure_ink_outline(ink_outline)
		var base_art: TextureRect = _base_art[tile.id]
		base_art.texture = _tile_skin.tile_base_texture()
		var back_art: TextureRect = _back_art[tile.id]
		back_art.texture = _tile_skin.tile_back_texture()
		back_art.visible = face_down and back_art.texture != null
		var back_design_art: TextureRect = _back_design_art[tile.id]
		_tile_skin.configure_back_design(back_design_art)
		back_design_art.visible = face_down and back_design_art.texture != null
		base_art.visible = (not face_down or back_art.texture == null) and base_art.texture != null
		var face_art: TextureRect = _face_art[tile.id]
		face_art.texture = texture
		face_art.visible = not face_down and texture != null
		var hint_glow: TextureRect = _hint_glows[tile.id]
		hint_glow.texture = _tile_skin.tile_base_texture()
		hint_glow.visible = false
		var blocked_overlay: TextureRect = _blocked_overlays[tile.id]
		blocked_overlay.texture = _tile_skin.tile_base_texture()
		blocked_overlay.modulate = _blocked_overlay_color()
		blocked_overlay.visible = not visually_active
		button.text = "" if face_down or texture != null else _tile_label(tile)
		var modifier_label: Label = _modifier_labels[tile.id]
		modifier_label.text = _modifier_symbol(tile)
		modifier_label.visible = not modifier_label.text.is_empty()

	if active_count == 0:
		_status_label.text = "Board cleared"
	else:
		_status_label.text = "%d tiles  |  %d free" % [active_count, selectable_ids.size() + revealable_ids.size()]
	_layout_tiles()
	_apply_hint_presentation()


func _on_tile_pressed(tile_id: String) -> void:
	var targetable: bool = (_game.board.call("is_tile_visible", tile_id) \
		and not _game.board.call("is_tile_face_down", tile_id)) if _delete_pair_armed \
		else (_game.board.call("is_tile_selectable", tile_id) \
			or _game.board.call("is_tile_revealable", tile_id) \
			or _game.definition.rules_version >= 12 \
				and _game.board.call("is_tile_revealed_flipped", tile_id) \
				and _game.board.call("is_tile_accessible", tile_id) \
			or _game.definition.rules_version < 12 \
				and _game.board.call("is_tile_revealed_flipped", tile_id) \
				and not _game.call("flipped_match_candidate", tile_id).is_empty())
	if _game.status != "playing":
		return
	var button: Button = _tile_buttons.get(tile_id)
	if button != null and bool(button.get_meta("flip_animating", false)):
		return
	if not targetable:
		if not _delete_pair_armed:
			locked_tile_tapped.emit(tile_id)
		_play_negative_feedback(tile_id)
		return

	tile_selected.emit(tile_id)


func _set_tile_interaction_brightness(tile_id: String, highlighted: bool) -> void:
	var button: Button = _tile_buttons.get(tile_id)
	if button == null or not bool(button.get_meta("targetable", false)):
		return
	var base_brightness := float(button.get_meta("presentation_brightness", 1.0))
	var brightness := base_brightness * (1.16 if highlighted else 1.0)
	button.modulate = Color(brightness, brightness, brightness)


func _apply_hint_presentation() -> void:
	var wave := 0.5 + 0.5 * sin(_hint_elapsed / HINT_CYCLE_SECONDS * TAU)
	for tile_id in _tile_buttons:
		var button: Button = _tile_buttons[tile_id]
		var base_position: Vector2 = _tile_layout_positions.get(tile_id, button.position)
		var hint_glow: TextureRect = _hint_glows[tile_id]
		if not button.visible or not _hinted_tile_ids.has(tile_id):
			hint_glow.visible = false
			continue
		var bob_height := clampf(button.size.y * HINT_BOB_RATIO, 1.5, 3.5)
		button.position = base_position + Vector2(0.0, -bob_height * wave)
		var base_brightness := float(button.get_meta("presentation_brightness", 1.0))
		var brightness := base_brightness * (1.0 + HINT_BRIGHTNESS_GAIN * wave)
		button.modulate = Color(brightness, brightness, brightness)
		hint_glow.visible = hint_glow.texture != null
		hint_glow.modulate = Color(1.0, 0.92, 0.68, lerpf(HINT_GLOW_MIN_ALPHA, HINT_GLOW_MAX_ALPHA, wave))


func create_tile_preview(tile_id: String, force_face_up: bool = false) -> Control:
	var button: Button = _tile_buttons.get(tile_id)
	if button == null or not button.visible:
		return null
	var preview := Panel.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color.WHITE
	var preview_style: StyleBox = button.get_theme_stylebox("normal").duplicate()
	if force_face_up and bool(button.get_meta("face_down", false)):
		preview_style = _art_backing_style()
	preview.add_theme_stylebox_override("panel", preview_style)
	var ink_outline := TextureRect.new()
	ink_outline.name = "InkOutline"
	_tile_skin.configure_ink_outline(ink_outline)
	preview.add_child(ink_outline)
	var base_art := TextureRect.new()
	base_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_art.texture = _tile_skin.tile_base_texture() if force_face_up \
		or not bool(button.get_meta("face_down", false)) else _tile_skin.tile_back_texture()
	base_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(base_art)
	if not force_face_up and bool(button.get_meta("face_down", false)):
		var back_design_art := TextureRect.new()
		back_design_art.name = "BackDesignArt"
		_tile_skin.configure_back_design(back_design_art)
		preview.add_child(back_design_art)
	var source_art: TextureRect = _face_art[tile_id]
	if (not bool(button.get_meta("face_down", false)) or force_face_up) and source_art.texture != null:
		var face_art := TextureRect.new()
		face_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face_art.set_anchors_preset(Control.PRESET_FULL_RECT)
		var active_geometry: Dictionary = _tile_skin.active_geometry()
		var safe_area: Array = active_geometry.get("face_safe_area", [92, 104, 328, 400])
		var source_size: Array = active_geometry.get("source_size", [512, 640])
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


func tile_visual_size() -> Vector2:
	for button in _tile_buttons.values():
		return button.size
	return Vector2.ZERO


func negative_feedback_count() -> int:
	return _negative_feedback_count


func play_flip(tile_id: String, revealing: bool = true) -> void:
	var button: Button = _tile_buttons.get(tile_id)
	if button == null or not button.visible:
		return
	if _flip_tweens.has(tile_id):
		var active_tween: Tween = _flip_tweens[tile_id]
		if active_tween != null and active_tween.is_valid():
			active_tween.kill()
	_set_flip_side(tile_id, not revealing)
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE
	button.set_meta("flip_animating", true)
	var tween := create_tween()
	_flip_tweens[tile_id] = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(button, "scale:x", 0.06, 0.075)
	tween.tween_callback(_set_flip_side.bind(tile_id, revealing))
	tween.tween_callback(_show_flip_blur.bind(tile_id))
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale:x", 1.0, 0.11)
	tween.tween_callback(_finish_flip.bind(tile_id))


func _set_flip_side(tile_id: String, face_up: bool) -> void:
	var base_art: TextureRect = _base_art.get(tile_id)
	var back_art: TextureRect = _back_art.get(tile_id)
	var back_design_art: TextureRect = _back_design_art.get(tile_id)
	var face_art: TextureRect = _face_art.get(tile_id)
	if base_art == null or back_art == null or back_design_art == null or face_art == null:
		return
	back_art.visible = not face_up and back_art.texture != null
	back_design_art.visible = not face_up and back_design_art.texture != null
	base_art.visible = (face_up or back_art.texture == null) and base_art.texture != null
	face_art.visible = face_up and face_art.texture != null


func _show_flip_blur(tile_id: String) -> void:
	var button: Button = _tile_buttons.get(tile_id)
	if button == null:
		return
	var blur := TextureRect.new()
	blur.name = "FlipBlur"
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur.texture = _tile_skin.tile_base_texture()
	blur.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blur.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	blur.anchor_left = -0.12
	blur.anchor_top = -0.02
	blur.anchor_right = 1.12
	blur.anchor_bottom = 1.02
	blur.modulate = Color(1.0, 0.94, 0.78, 0.24)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	blur.material = material
	button.add_child(blur)
	var blur_tween := create_tween()
	blur_tween.tween_property(blur, "modulate:a", 0.0, 0.10)
	blur_tween.tween_callback(blur.queue_free)


func _finish_flip(tile_id: String) -> void:
	_flip_tweens.erase(tile_id)
	var button: Button = _tile_buttons.get(tile_id)
	if button == null:
		return
	button.scale = Vector2.ONE
	button.set_meta("flip_animating", false)


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

	var header_height := COMPACT_HEADER_HEIGHT if _compact_mode else HEADER_HEIGHT
	var board_margin := COMPACT_BOARD_MARGIN if _compact_mode else BOARD_MARGIN
	_status_label.size = Vector2(maxf(80.0, size.x - 140.0 - board_margin), 30.0)
	var area := Rect2(
		board_margin,
		header_height,
		maxf(1.0, size.x - board_margin * 2.0),
		maxf(1.0, size.y - header_height - board_margin)
	)
	_tile_layer.position = area.position
	_tile_layer.size = area.size

	var bounds := _grid_bounds()
	var grid_width: float = float(bounds.size.x) * 0.5
	var grid_height: float = float(bounds.size.y) * 0.5
	var max_depth := 0
	for tile in _game.board.tiles:
		max_depth = maxi(max_depth, tile.position.z)
	var layer_offset_ratio: Array = _tile_skin.depth_presentation.get(
		"layer_offset_ratio",
		[0.05, -0.08]
	)
	var control_allowance := Vector2(12.0, 12.0)
	var depth_width_units := float(max_depth) * absf(float(layer_offset_ratio[0]))
	var depth_height_units := float(max_depth) * absf(float(layer_offset_ratio[1]))
	var tile_width: float = minf(
		(area.size.x - control_allowance.x) / (grid_width + depth_width_units),
		(area.size.y - control_allowance.y) \
			/ ((grid_height + depth_height_units) * _tile_skin.tile_aspect())
	)
	var tile_size := Vector2(maxf(16.0, tile_width), maxf(16.0, tile_width * _tile_skin.tile_aspect()))
	var adjacent_gap_ratio := float(_tile_skin.layout_presentation.get("adjacent_gap_ratio", 0.0))
	var tile_gap := tile_size * adjacent_gap_ratio
	var board_size := Vector2(tile_size.x * grid_width, tile_size.y * grid_height)
	var per_layer_offset := Vector2(
		tile_size.x * float(layer_offset_ratio[0]),
		tile_size.y * float(layer_offset_ratio[1])
	)
	var maximum_depth_offset := per_layer_offset * float(max_depth)
	var depth_min := Vector2(minf(0.0, maximum_depth_offset.x), minf(0.0, maximum_depth_offset.y))
	var depth_max := Vector2(maxf(0.0, maximum_depth_offset.x), maxf(0.0, maximum_depth_offset.y))
	var depth_extent := depth_max - depth_min
	var origin := (area.size - board_size - depth_extent) * 0.5 - depth_min

	for tile in _game.board.tiles:
		var button: Button = _tile_buttons[tile.id]
		var depth_offset := per_layer_offset * float(tile.position.z)
		button.position = origin + Vector2(
			float(tile.position.x - bounds.position.x) * tile_size.x * 0.5,
			float(tile.position.y - bounds.position.y) * tile_size.y * 0.5
		) + depth_offset + tile_gap * 0.5
		_tile_layout_positions[tile.id] = button.position
		button.size = tile_size - tile_gap
		button.z_index = tile.position.z * DEPTH_Z_STRIDE + TILE_SURFACE_Z_OFFSET
		button.add_theme_font_size_override("font_size", clampi(int(tile_size.x * 0.25), 10, 18))
		var shadow_offset_ratio: Array = _tile_skin.depth_presentation.get("shadow_offset_ratio", [0.05, 0.07])
		var shadow_art: TextureRect = _shadow_art[tile.id]
		shadow_art.position = Vector2(
			button.size.x * float(shadow_offset_ratio[0]),
			button.size.y * float(shadow_offset_ratio[1])
		)
		shadow_art.size = button.size
		var active_geometry: Dictionary = _tile_skin.active_geometry()
		var safe_area: Array = active_geometry.get("face_safe_area", [92, 104, 328, 400])
		var source_size: Array = active_geometry.get("source_size", [512, 640])
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
	_sync_tile_input_order()
	_apply_hint_presentation()


func _sync_tile_input_order() -> void:
	var ordered_tiles: Array = _game.board.tiles.duplicate()
	ordered_tiles.sort_custom(_tile_precedes_for_input)
	for index in range(ordered_tiles.size()):
		_tile_layer.move_child(_tile_buttons[ordered_tiles[index].id], index)


func _tile_precedes_for_input(first: Variant, second: Variant) -> bool:
	if first.position.z != second.position.z:
		return first.position.z < second.position.z
	if first.position.y != second.position.y:
		return first.position.y < second.position.y
	if first.position.x != second.position.x:
		return first.position.x < second.position.x
	return first.id < second.id


func _depth_brightness(depth: int, max_depth: int) -> float:
	if max_depth <= 0:
		return 1.0
	var floor := float(_tile_skin.depth_presentation.get("lowest_layer_brightness", 0.70))
	return lerpf(floor, 1.0, float(depth) / float(max_depth))


func _blocked_overlay_color() -> Color:
	var channels: Array = _tile_skin.depth_presentation.get(
		"blocked_overlay_color",
		[0.06, 0.16, 0.18, 0.46]
	)
	return Color(float(channels[0]), float(channels[1]), float(channels[2]), float(channels[3]))


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
	if _game.board.call("is_tile_face_down", tile.id):
		var hidden_modifier: Dictionary = _game.definition.modifier_for_tile(tile.id)
		if hidden_modifier.is_empty():
			return "Face-down tile"
		return "Face-down tile | %s level %d" % [
			str(hidden_modifier.type).replace("_", " ").capitalize(),
			int(hidden_modifier.level),
		]
	var label: String = _tile_skin.label_for_face(tile.face).replace("\n", " ")
	var modifier: Dictionary = _game.definition.modifier_for_tile(tile.id)
	if modifier.is_empty():
		return label
	return "%s | %s level %d" % [label, str(modifier.type).replace("_", " ").capitalize(), int(modifier.level)]


func _apply_tile_style(button: Button, _selectable: bool, _face_down: bool = false) -> void:
	var normal := _art_backing_style()
	var hover := _art_backing_style()
	var pressed := _art_backing_style()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", _tile_style(Color("8f9189"), Color("394140"), 2, Vector2(0.0, 2.0)))
	button.add_theme_color_override("font_color", Color("202625"))
	button.add_theme_color_override("font_hover_color", Color("111615"))
	button.add_theme_color_override("font_pressed_color", Color("111615"))
	button.add_theme_color_override("font_disabled_color", Color("59615f"))
	if _face_down:
		button.add_theme_color_override("font_color", Color("fff7cf"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _art_backing_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	return style


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
