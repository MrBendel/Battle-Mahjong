extends PanelContainer
class_name DebugPanel

var _seed_value: Label
var _viewport_value: Label
var _orientation_value: Label
var _layout_value: Label

func _ready() -> void:
	_build()


func set_info(seed: int, viewport_size: Vector2i, orientation: String, layout_id: String = "") -> void:
	if _seed_value == null:
		return

	_seed_value.text = "Seed: %d" % seed
	_viewport_value.text = "Viewport: %d x %d" % [viewport_size.x, viewport_size.y]
	_orientation_value.text = "Orientation: %s" % orientation
	_layout_value.text = "Layout: %s" % layout_id


func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.035, 0.82)
	style.border_color = Color(0.55, 0.65, 0.85, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	add_child(list)

	var title := Label.new()
	title.text = "Debug"
	title.add_theme_font_size_override("font_size", 14)
	list.add_child(title)

	_seed_value = Label.new()
	_viewport_value = Label.new()
	_orientation_value = Label.new()
	_layout_value = Label.new()

	for label in [_seed_value, _viewport_value, _orientation_value, _layout_value]:
		label.add_theme_font_size_override("font_size", 12)
		list.add_child(label)
