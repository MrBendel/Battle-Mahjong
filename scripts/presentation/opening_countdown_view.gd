extends Control

signal finished

const COUNTDOWN_FONT := preload("res://assets/fonts/mila-script-sans-bold-tight.tres")
const REFERENCE_BOARD_SIZE := Vector2(390.0, 560.0)
const REFERENCE_PULSE_SIZE := Vector2(230.0, 230.0)
const NUMBER_COLORS := [Color("ffe06a"), Color("ff8fbd"), Color("fff7dc")]

var play_count := 0
var last_text := ""
var _pulse: Control
var _main_label: Label
var _cyan_label: Label
var _pink_label: Label
var _streaks: Array[ColorRect] = []
var _active_tween: Tween
var _display_scale := 1.0


func _init() -> void:
	name = "OpeningCountdown"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1300
	visible = false
	_pulse = Control.new()
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pulse)
	for index in 12:
		var streak := ColorRect.new()
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak.color = Color("ffe06a") if index % 2 == 0 else Color("ff5d9e")
		_pulse.add_child(streak)
		_streaks.append(streak)
	_cyan_label = _make_label(Color(0.18, 0.9, 1.0, 0.72), 3)
	_pink_label = _make_label(Color(1.0, 0.2, 0.55, 0.72), 3)
	_main_label = _make_label(NUMBER_COLORS[0], 8)


func place_over(board_rect: Rect2) -> void:
	position = board_rect.position
	size = board_rect.size
	_display_scale = maxf(0.72, minf(size.x / REFERENCE_BOARD_SIZE.x, size.y / REFERENCE_BOARD_SIZE.y))
	_pulse.size = REFERENCE_PULSE_SIZE * _display_scale
	_pulse.position = (size - _pulse.size) * 0.5
	_pulse.pivot_offset = _pulse.size * 0.5
	var center := _pulse.size * 0.5
	var radius := 82.0 * _display_scale
	for index in _streaks.size():
		var streak := _streaks[index]
		var angle := TAU * float(index) / float(_streaks.size())
		streak.size = Vector2(34.0, 3.0 + float(index % 3)) * _display_scale
		streak.pivot_offset = Vector2(0.0, streak.size.y * 0.5)
		streak.position = center + Vector2.from_angle(angle) * radius
		streak.rotation = angle
	for label in [_cyan_label, _pink_label, _main_label]:
		label.size = _pulse.size
		label.add_theme_font_size_override("font_size", roundi(118.0 * _display_scale))
		label.add_theme_constant_override("outline_size", maxi(5, roundi(8.0 * _display_scale)))
	_cyan_label.position = Vector2(-3.0, 1.0) * _display_scale
	_pink_label.position = Vector2(3.0, -1.0) * _display_scale
	_main_label.position = Vector2.ZERO


func play(step_seconds: float = 0.55) -> void:
	cancel()
	play_count += 1
	visible = true
	var step := maxf(0.18, step_seconds)
	var pop_seconds := minf(0.16, step * 0.34)
	var fade_seconds := minf(0.13, step * 0.28)
	var hold_seconds := maxf(0.0, step - pop_seconds - fade_seconds)
	_active_tween = create_tween()
	for index in 3:
		_active_tween.tween_callback(_show_number.bind(3 - index, index))
		_active_tween.tween_property(_pulse, "scale", Vector2.ONE * 1.08, pop_seconds) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_active_tween.parallel().tween_property(_pulse, "modulate:a", 1.0, minf(0.06, pop_seconds))
		_active_tween.tween_interval(hold_seconds)
		_active_tween.tween_property(_pulse, "scale", Vector2.ONE * 1.28, fade_seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_active_tween.parallel().tween_property(_pulse, "modulate:a", 0.0, fade_seconds)
	_active_tween.finished.connect(_finish)


func cancel() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	visible = false
	_pulse.modulate = Color.WHITE
	_pulse.scale = Vector2.ONE


func _show_number(number: int, index: int) -> void:
	last_text = str(number)
	for label in [_cyan_label, _pink_label, _main_label]:
		label.text = last_text
	_main_label.add_theme_color_override("font_color", NUMBER_COLORS[index])
	_pulse.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_pulse.scale = Vector2.ONE * 0.48
	_pulse.rotation = deg_to_rad(-5.0 if index % 2 == 0 else 5.0)


func _finish() -> void:
	_active_tween = null
	visible = false
	_pulse.modulate = Color.WHITE
	_pulse.scale = Vector2.ONE
	_pulse.rotation = 0.0
	finished.emit()


func _make_label(color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", COUNTDOWN_FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("111018"))
	label.add_theme_constant_override("outline_size", outline_size)
	_pulse.add_child(label)
	return label
