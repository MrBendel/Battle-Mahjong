extends Control

const CALLOUT_TEXT := {
	"great": "GREAT!",
	"eagle_eyes": "EAGLE EYES!",
}

var play_count := 0
var last_callout_key := ""
var last_text := ""
var _label: Label
var _active_tween: Tween
var _base_label_position := Vector2.ZERO


func _init() -> void:
	name = "PerformanceCallout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1200
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color("fff27a"))
	_label.add_theme_color_override("font_outline_color", Color("16131f"))
	_label.add_theme_constant_override("outline_size", 9)
	_label.visible = false
	add_child(_label)


func place_over(board_rect: Rect2) -> void:
	position = board_rect.position
	size = board_rect.size
	var callout_height := minf(84.0, maxf(56.0, size.y * 0.18))
	_base_label_position = Vector2(0.0, maxf(10.0, size.y * 0.16))
	_label.position = _base_label_position
	_label.size = Vector2(size.x, callout_height)
	_label.pivot_offset = _label.size * 0.5


func play_reward(reward: Dictionary) -> void:
	var key := str(reward.get("callout_key", ""))
	if not CALLOUT_TEXT.has(key):
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	play_count += 1
	last_callout_key = key
	last_text = str(CALLOUT_TEXT[key])
	_label.text = last_text
	_label.visible = true
	_label.position = _base_label_position
	_label.modulate = Color.WHITE
	_label.scale = Vector2(0.55, 0.55)
	_label.rotation = deg_to_rad(-3.0 if key == "great" else 3.0)
	_active_tween = create_tween()
	_active_tween.tween_property(_label, "scale", Vector2(1.08, 1.08), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_label, "scale", Vector2.ONE, 0.08)
	_active_tween.tween_interval(0.48)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_label, "modulate:a", 0.0, 0.22)
	_active_tween.tween_property(_label, "position:y", _label.position.y - 18.0, 0.22)
	_active_tween.finished.connect(_finish_callout)


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
