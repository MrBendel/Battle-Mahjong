extends Control

const CALLOUT_FONT := preload("res://assets/fonts/mila-script-sans-bold-tight.tres")
const REFERENCE_BOARD_SIZE := Vector2(390.0, 560.0)
const BASE_FONT_SIZE := 36.0
const BASE_OUTLINE_SIZE := 9.0
const BASE_CALLOUT_HEIGHT := 84.0
const BASE_RISE_DISTANCE := 18.0

const TYPE_COLORS := {
	"difficulty": Color("fff27a"),
	"combo": Color("7af2bd"),
	"score": Color("72d8ff"),
	"board_progress": Color("ff91bd"),
}

var play_count := 0
var last_callout_key := ""
var last_alert_type := ""
var last_text := ""
var _label: Label
var _active_tween: Tween
var _base_label_position := Vector2.ZERO
var _display_scale := 1.0
var _rise_distance := BASE_RISE_DISTANCE


func _init() -> void:
	name = "PerformanceCallout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1200
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", CALLOUT_FONT)
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color("fff27a"))
	_label.add_theme_color_override("font_outline_color", Color("16131f"))
	_label.add_theme_constant_override("outline_size", 9)
	_label.visible = false
	add_child(_label)


func place_over(board_rect: Rect2) -> void:
	position = board_rect.position
	size = board_rect.size
	_display_scale = maxf(0.72, minf(
		size.x / REFERENCE_BOARD_SIZE.x,
		size.y / REFERENCE_BOARD_SIZE.y
	))
	var callout_height := minf(BASE_CALLOUT_HEIGHT * _display_scale, size.y * 0.24)
	_base_label_position = Vector2(0.0, maxf(10.0, size.y * 0.16))
	_label.position = _base_label_position
	_label.size = Vector2(size.x, callout_height)
	_label.pivot_offset = _label.size * 0.5
	_rise_distance = BASE_RISE_DISTANCE * _display_scale
	_apply_responsive_text_style()


func play_alert(alert: Dictionary) -> void:
	var key := str(alert.get("key", ""))
	var alert_type := str(alert.get("type", ""))
	var text := str(alert.get("text", ""))
	if key.is_empty() or text.is_empty() or not TYPE_COLORS.has(alert_type):
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	play_count += 1
	last_callout_key = key
	last_alert_type = alert_type
	last_text = text
	_label.text = last_text
	_apply_responsive_text_style()
	_label.add_theme_color_override("font_color", TYPE_COLORS[alert_type])
	_label.visible = true
	_label.position = _base_label_position
	_label.modulate = Color.WHITE
	_label.scale = Vector2(0.55, 0.55)
	_label.rotation = deg_to_rad(-3.0 if play_count % 2 == 0 else 3.0)
	_active_tween = create_tween()
	_active_tween.tween_property(_label, "scale", Vector2(1.08, 1.08), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_label, "scale", Vector2.ONE, 0.08)
	_active_tween.tween_interval(0.48)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_label, "modulate:a", 0.0, 0.22)
	_active_tween.tween_property(_label, "position:y", _label.position.y - _rise_distance, 0.22)
	_active_tween.finished.connect(_finish_callout)


func play_reward(reward: Dictionary) -> void:
	var key := str(reward.get("callout_key", ""))
	var alert_key := "well_hidden" if key == "great" else key
	var text := "WELL HIDDEN!" if key == "great" else ("EAGLE EYES!" if key == "eagle_eyes" else "")
	play_alert({"type": "difficulty", "key": alert_key, "text": text})


func reset() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_finish_callout()


func _finish_callout() -> void:
	_label.visible = false
	_label.modulate = Color.WHITE
	_label.scale = Vector2.ONE
	_label.rotation = 0.0
	_label.position = _base_label_position


func _apply_responsive_text_style() -> void:
	var font_size := maxi(18, roundi(BASE_FONT_SIZE * _display_scale))
	var available_width := size.x * 0.94
	var font: Font = _label.get_theme_font("font")
	while font_size > 18 and not _label.text.is_empty() \
			and font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		font_size -= 1
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_constant_override(
		"outline_size",
		maxi(4, roundi(BASE_OUTLINE_SIZE * _display_scale))
	)
