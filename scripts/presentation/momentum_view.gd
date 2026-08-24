extends Control
class_name MomentumView

const SCORE_BOX := preload("res://game-assets/ui/portrait/score_box.png")
const MOMENTUM_FRAME := preload("res://game-assets/ui/portrait/momentum_frame.png")
const MOMENTUM_FILL := preload("res://game-assets/ui/portrait/momentum_fill.png")
const MOMENTUM_BADGE := preload("res://game-assets/ui/portrait/momentum_badge.png")
const MILA_REGULAR := preload("res://assets/fonts/mila-script-sans-regular-tight.tres")
const MILA_BOLD := preload("res://assets/fonts/mila-script-sans-bold-tight.tres")

const PORTRAIT_REFERENCE_SIZE := Vector2(322.0, 81.0)
const PORTRAIT_FRAME_RECT := Rect2(118.0, 30.0, 173.3, 25.3)

var _game: Variant
var _portrait_style := false
var _legacy_background: Panel
var _title: Label
var _multiplier: Label
var _score: Label
var _combo: Label
var _meter: ProgressBar
var _score_art: TextureRect
var _score_title: Label
var _timer: Label
var _momentum_frame: TextureRect
var _fill_clip: Control
var _momentum_fill: TextureRect
var _momentum_badge: TextureRect
var _ticks: Array[Label] = []
var _audio_player: AudioStreamPlayer
var _audio_playback: Variant


func _init(game_state: Variant) -> void:
	_game = game_state


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)
	_layout()
	refresh(_game.elapsed_time_ms)


func set_game_state(game_state: Variant) -> void:
	_game = game_state
	refresh(_game.elapsed_time_ms)


func set_portrait_style(enabled: bool) -> void:
	_portrait_style = enabled
	_update_style_visibility()
	_layout()


func refresh(playback_time_ms: int) -> void:
	if _meter == null:
		return
	var momentum: int = _game.call("momentum_at", playback_time_ms)
	var multiplier: int = _game.call("multiplier_at", playback_time_ms)
	var maximum: int = int(_game.definition.configuration.momentum_max)
	_meter.max_value = maximum
	_meter.value = momentum
	_multiplier.text = "x%d" % multiplier
	_score.text = _format_score(_game.score) if _portrait_style else "Score  %d" % _game.score
	_timer.text = _format_time(playback_time_ms)
	var combo: int = _game.call("combo_at", playback_time_ms)
	_combo.text = "STREAK %dX" % combo if _portrait_style and combo > 0 \
		else "STREAK READY" if _portrait_style \
		else "Combo x%d" % combo if combo > 0 else "Combo ready"
	var ratio := clampf(float(momentum) / float(maximum), 0.0, 1.0) if maximum > 0 else 0.0
	_fill_clip.size.x = _momentum_fill.size.x * ratio


func play_pair_feedback(multiplier: int) -> void:
	if _multiplier == null:
		return
	var tween := create_tween()
	tween.tween_property(_multiplier, "modulate", Color("7af2bd"), 0.06)
	tween.tween_property(_multiplier, "modulate", Color.WHITE, 0.18)
	_play_tone(multiplier)


func _build() -> void:
	_legacy_background = Panel.new()
	_legacy_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_legacy_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241b2e")
	style.border_color = Color("76578b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_legacy_background.add_theme_stylebox_override("panel", style)
	add_child(_legacy_background)

	_score_art = _art(SCORE_BOX)
	add_child(_score_art)
	_momentum_frame = _art(MOMENTUM_FRAME)
	add_child(_momentum_frame)
	_fill_clip = Control.new()
	_fill_clip.clip_contents = true
	_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill_clip)
	_momentum_fill = _art(MOMENTUM_FILL)
	_fill_clip.add_child(_momentum_fill)
	_momentum_badge = _art(MOMENTUM_BADGE)
	add_child(_momentum_badge)

	_title = _label("Momentum", MILA_REGULAR, 14, Color("cbbbd3"))
	add_child(_title)
	_multiplier = _label("", MILA_BOLD, 25, Color("fce8cd"))
	_multiplier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_multiplier)
	_score_title = _label("SCORE", MILA_BOLD, 9, Color("fdf1d8"))
	_score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_score_title)
	_score = _label("", MILA_REGULAR, 15, Color("fdf1d8"))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_score)
	_timer = _label("", MILA_REGULAR, 11, Color("fdf1d8"))
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_timer)
	_combo = _label("", MILA_BOLD, 12, Color("fcf0d6"))
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_combo)

	var colors := ["1e8b59", "5b9f45", "88ad35", "f5ba33", "ea9734", "e07136", "d75348"]
	for index in range(7):
		var tick := _label("%dX" % (index + 2), MILA_BOLD, 8, Color(colors[index]))
		tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tick)
		_ticks.append(tick)

	_meter = ProgressBar.new()
	_meter.show_percentage = false
	_meter.add_theme_stylebox_override("background", _meter_style(Color("100d16")))
	_meter.add_theme_stylebox_override("fill", _meter_style(Color("cf596d")))
	add_child(_meter)
	_update_style_visibility()

	if DisplayServer.get_name() == "headless":
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.2
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = generator
	_audio_player.volume_db = -12.0
	add_child(_audio_player)
	_audio_player.play()
	_audio_playback = _audio_player.get_stream_playback()


func _update_style_visibility() -> void:
	if _legacy_background == null:
		return
	_legacy_background.visible = not _portrait_style
	_title.visible = not _portrait_style
	_meter.visible = not _portrait_style
	_score_art.visible = _portrait_style
	_score_title.visible = _portrait_style
	_timer.visible = _portrait_style
	_momentum_frame.visible = _portrait_style
	_fill_clip.visible = _portrait_style
	_momentum_badge.visible = _portrait_style
	for tick in _ticks:
		tick.visible = _portrait_style


func _layout() -> void:
	if _title == null:
		return
	if not _portrait_style:
		_layout_legacy()
		return
	var scale := minf(size.x / PORTRAIT_REFERENCE_SIZE.x, size.y / PORTRAIT_REFERENCE_SIZE.y)
	var score_origin := Vector2(0.0, (size.y - PORTRAIT_REFERENCE_SIZE.y * scale) * 0.5)
	var frame_center_x := PORTRAIT_FRAME_RECT.get_center().x * scale
	var momentum_origin := score_origin + Vector2(size.x * 0.5 - frame_center_x, 0.0)
	_place_scaled(_score_art, Rect2(2.0, 5.0, 115.5, 77.0), score_origin, scale)
	_place_scaled(_score_title, Rect2(34.0, 15.0, 70.0, 13.0), score_origin, scale, 9)
	_place_scaled(_score, Rect2(14.0, 25.0, 110.0, 22.0), score_origin, scale, 15)
	_place_scaled(_timer, Rect2(35.0, 50.0, 70.0, 17.0), score_origin, scale, 11)
	_place_scaled(_momentum_frame, PORTRAIT_FRAME_RECT, momentum_origin, scale)
	_place_scaled(_fill_clip, Rect2(122.7, 32.9, 162.9, 18.6), momentum_origin, scale)
	_momentum_fill.position = Vector2.ZERO
	_momentum_fill.size = Vector2(162.9, 18.6) * scale
	_place_scaled(_momentum_badge, Rect2(275.9, 25.8, 34.2, 34.2), momentum_origin, scale)
	_place_scaled(_multiplier, Rect2(278.0, 31.0, 30.0, 22.0), momentum_origin, scale, 15)
	_place_scaled(_combo, Rect2(155.0, 7.0, 92.0, 18.0), momentum_origin, scale, 12)
	for index in range(_ticks.size()):
		var tick_center_x := 122.7 + 162.9 * float(index + 1) / 8.0
		_place_scaled(_ticks[index], Rect2(tick_center_x - 10.0, 55.0, 20.0, 14.0), momentum_origin, scale, 8)
	refresh(_game.elapsed_time_ms)


func _layout_legacy() -> void:
	var margin := 10.0
	var compact := size.y <= 72.0
	_title.position = Vector2(margin, 5.0 if compact else 8.0)
	_title.size = Vector2(90.0, 24.0)
	_multiplier.position = Vector2(96.0, 1.0 if compact else 5.0)
	_multiplier.size = Vector2(58.0, 34.0)
	_score.position = Vector2(154.0, 5.0 if compact else 8.0)
	_score.size = Vector2(maxf(56.0, size.x - 164.0), 20.0)
	_combo.position = Vector2(154.0, 24.0 if compact else 30.0)
	_combo.size = Vector2(maxf(56.0, size.x - 164.0), 18.0)
	_meter.position = Vector2(margin, 44.0 if compact else 55.0)
	_meter.size = Vector2(maxf(1.0, size.x - margin * 2.0), 12.0 if compact else 18.0)


func _place_scaled(control: Control, rect: Rect2, origin: Vector2, scale: float, font_size := 0) -> void:
	control.position = origin + rect.position * scale
	control.size = rect.size * scale
	if font_size > 0 and control is Label:
		control.add_theme_font_size_override("font_size", maxi(8, roundi(font_size * scale)))


func _art(texture: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _format_score(value: int) -> String:
	var digits := str(maxi(0, value))
	var formatted := ""
	while digits.length() > 3:
		formatted = ",%s%s" % [digits.right(3), formatted]
		digits = digits.left(digits.length() - 3)
	return digits + formatted


func _format_time(playback_time_ms: int) -> String:
	var total_centiseconds := maxi(0, playback_time_ms) / 10
	var minutes := total_centiseconds / 6000
	var seconds := total_centiseconds / 100 % 60
	var centiseconds := total_centiseconds % 100
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]


func _meter_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func _play_tone(multiplier: int) -> void:
	if _audio_playback == null:
		return
	var frames := PackedVector2Array()
	var frame_count := 1764
	var frequency := 420.0 + float(multiplier) * 70.0
	for frame in range(frame_count):
		var envelope := 1.0 - float(frame) / float(frame_count)
		var sample := sin(TAU * frequency * float(frame) / 22050.0) * envelope * 0.16
		frames.append(Vector2(sample, sample))
	_audio_playback.push_buffer(frames)
