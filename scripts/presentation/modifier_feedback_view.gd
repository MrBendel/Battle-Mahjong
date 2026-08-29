extends Control
class_name ModifierFeedbackView

const EXTRA_LIFE_ICON := preload("res://game-assets/modifiers/tile-overlays/extra_life.png")
const COLD_SNAP_ICON := preload("res://game-assets/modifiers/tile-overlays/cold_snap.png")
const SCORE_MULTIPLIER_ICON := preload("res://game-assets/modifiers/tile-overlays/score_multiplier.png")
const TRAY_PLUS_ONE_ICON := preload("res://game-assets/modifiers/tile-overlays/tray_plus_one.png")

const FEEDBACK := {
	"extra_life": {"color": Color("ff6f9f"), "texture": EXTRA_LIFE_ICON},
	"extra_life_save": {"color": Color("ff4f8b"), "texture": EXTRA_LIFE_ICON},
	"cold_snap": {"color": Color("73e7ff"), "texture": COLD_SNAP_ICON},
	"score_multiplier": {"color": Color("ffc84f"), "texture": SCORE_MULTIPLIER_ICON},
	"tray_plus_one": {"color": Color("68e7a6"), "texture": TRAY_PLUS_ONE_ICON},
}

var play_count := 0
var last_modifier_type := ""
var _flash: ColorRect
var _icon: TextureRect
var _edges: Array[ColorRect] = []
var _active_tween: Tween


func _init() -> void:
	name = "ModifierFeedback"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1150
	visible = false
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	for _index in range(4):
		var edge := ColorRect.new()
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(edge)
		_edges.append(edge)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	resized.connect(_layout)


func place_over(board_rect: Rect2) -> void:
	position = board_rect.position
	size = board_rect.size
	_layout()


func play_activation(modifier_type: String) -> void:
	if not FEEDBACK.has(modifier_type):
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	var feedback: Dictionary = FEEDBACK[modifier_type]
	var color: Color = feedback.color
	play_count += 1
	last_modifier_type = modifier_type
	visible = true
	_flash.color = Color(color, 0.16 if modifier_type != "extra_life_save" else 0.26)
	_icon.texture = feedback.texture
	_icon.modulate = Color.WHITE
	_icon.scale = Vector2(0.28, 0.28)
	_icon.rotation = deg_to_rad(-8.0)
	for edge in _edges:
		edge.color = Color(color, 0.62)
	_layout()
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_flash, "color:a", 0.0, 0.34)
	_active_tween.tween_property(_icon, "scale", Vector2(1.16, 1.16), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_icon, "rotation", 0.0, 0.18)
	for edge in _edges:
		_active_tween.tween_property(edge, "color:a", 0.0, 0.42)
	_active_tween.chain().tween_property(_icon, "scale", Vector2.ONE, 0.08)
	_active_tween.chain().tween_interval(0.22 if modifier_type != "extra_life_save" else 0.42)
	_active_tween.chain().set_parallel(true)
	_active_tween.tween_property(_icon, "modulate:a", 0.0, 0.20)
	_active_tween.tween_property(_icon, "position:y", _icon.position.y - size.y * 0.04, 0.20)
	_active_tween.finished.connect(reset)


func reset() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	visible = false
	_flash.color.a = 0.0
	_icon.modulate = Color.WHITE
	_icon.scale = Vector2.ONE
	_icon.rotation = 0.0
	for edge in _edges:
		edge.color.a = 0.0


func _layout() -> void:
	if _icon == null:
		return
	var icon_size := clampf(minf(size.x, size.y) * 0.18, 54.0, 104.0)
	_icon.size = Vector2.ONE * icon_size
	_icon.position = (size - _icon.size) * 0.5
	_icon.pivot_offset = _icon.size * 0.5
	var edge_size := clampf(minf(size.x, size.y) * 0.018, 4.0, 12.0)
	_edges[0].position = Vector2.ZERO
	_edges[0].size = Vector2(size.x, edge_size)
	_edges[1].position = Vector2(0.0, size.y - edge_size)
	_edges[1].size = Vector2(size.x, edge_size)
	_edges[2].position = Vector2.ZERO
	_edges[2].size = Vector2(edge_size, size.y)
	_edges[3].position = Vector2(size.x - edge_size, 0.0)
	_edges[3].size = Vector2(edge_size, size.y)
