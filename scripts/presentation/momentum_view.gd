extends Control
class_name MomentumView

var _game: Variant
var _style: StyleBoxFlat
var _title: Label
var _multiplier: Label
var _score: Label
var _combo: Label
var _meter: ProgressBar
var _audio_player: AudioStreamPlayer
var _audio_playback: Variant


func _init(game_state: Variant) -> void:
	_game = game_state


func _ready() -> void:
	_build()
	resized.connect(_layout)
	_layout()
	refresh(_game.elapsed_time_ms)


func set_game_state(game_state: Variant) -> void:
	_game = game_state
	refresh(_game.elapsed_time_ms)


func refresh(playback_time_ms: int) -> void:
	if _meter == null:
		return
	var momentum: int = _game.call("momentum_at", playback_time_ms)
	var multiplier: int = _game.call("multiplier_at", playback_time_ms)
	_meter.max_value = int(_game.definition.configuration.momentum_max)
	_meter.value = momentum
	_multiplier.text = "x%d" % multiplier
	_score.text = "Score  %d" % _game.score
	var combo: int = _game.call("combo_at", playback_time_ms)
	_combo.text = "Combo x%d" % combo if combo > 0 else "Combo ready"


func play_pair_feedback(multiplier: int) -> void:
	if _multiplier == null:
		return
	var tween := create_tween()
	tween.tween_property(_multiplier, "modulate", Color("7af2bd"), 0.06)
	tween.tween_property(_multiplier, "modulate", Color.WHITE, 0.18)
	_play_tone(multiplier)


func _build() -> void:
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("241b2e")
	_style.border_color = Color("76578b")
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(8)
	background.add_theme_stylebox_override("panel", _style)
	add_child(background)

	_title = Label.new()
	_title.text = "Momentum"
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color("cbbbd3"))
	add_child(_title)

	_multiplier = Label.new()
	_multiplier.add_theme_font_size_override("font_size", 25)
	_multiplier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_multiplier)

	_score = Label.new()
	_score.add_theme_font_size_override("font_size", 14)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score)

	_combo = Label.new()
	_combo.add_theme_font_size_override("font_size", 12)
	_combo.add_theme_color_override("font_color", Color("ffd166"))
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_combo)

	_meter = ProgressBar.new()
	_meter.show_percentage = false
	_meter.add_theme_stylebox_override("background", _meter_style(Color("100d16")))
	_meter.add_theme_stylebox_override("fill", _meter_style(Color("cf596d")))
	add_child(_meter)

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


func _layout() -> void:
	if _title == null:
		return
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
