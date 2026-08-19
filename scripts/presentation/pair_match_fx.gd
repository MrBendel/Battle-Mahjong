extends Control
class_name PairMatchFx

const DEFAULT_SIZE := Vector2(104.0, 104.0)

var _accent := Color("ffd166")


func _init(effect_size: Vector2 = DEFAULT_SIZE, accent: Color = Color("ffd166")) -> void:
	size = effect_size
	pivot_offset = effect_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_accent = accent


func _ready() -> void:
	modulate.a = 0.0
	scale = Vector2(0.35, 0.35)
	queue_redraw()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.04)
	tween.tween_property(self, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.05)
	tween.chain().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)


func _draw() -> void:
	var center := size * 0.5
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var direction := Vector2.from_angle(angle)
		var inner_radius := 22.0 if index % 2 == 0 else 29.0
		var outer_radius := 46.0 if index % 2 == 0 else 40.0
		draw_line(center + direction * inner_radius, center + direction * outer_radius, _accent, 3.0, true)
	draw_arc(center, 24.0, 0.0, TAU, 32, Color(_accent, 0.78), 4.0, true)
	draw_circle(center, 8.0, Color("fff8df"))
