extends Control
class_name TownDestinationSign

const BOLD_FONT := preload("res://assets/fonts/mila-script-sans-bold-tight.tres")

var _label: Label
var _board_color := Color("183f31")
var _border_color := Color("f5d56d")
var _display_scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "SignLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", BOLD_FONT)
	_label.add_theme_color_override("font_color", Color("fff4cf"))
	add_child(_label)


func configure(text: String, board_color: Color, border_color: Color) -> void:
	_board_color = board_color
	_border_color = border_color
	if _label != null:
		_label.text = text
	queue_redraw()


func layout_sign(maximum_width: float, scale_factor: float) -> void:
	_display_scale = scale_factor
	var height := 31.0 * scale_factor
	var horizontal_padding := 24.0 * scale_factor
	var max_font_size := maxi(8, roundi(14.0 * scale_factor))
	var min_font_size := maxi(7, roundi(9.0 * scale_factor))
	var available_text_width := maxf(1.0, maximum_width - horizontal_padding)
	var font_size := max_font_size
	while font_size > min_font_size \
			and BOLD_FONT.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_text_width:
		font_size -= 1
	var text_width := BOLD_FONT.get_string_size(
		_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x
	var requested_width := text_width + horizontal_padding
	size = Vector2(clampf(requested_width, 82.0 * scale_factor, maximum_width), height)
	_label.position = Vector2(10.0, 2.0) * scale_factor
	_label.size = size - Vector2(20.0, 4.0) * scale_factor
	_label.add_theme_font_size_override("font_size", font_size)
	queue_redraw()


func fitted_font_size() -> int:
	return _label.get_theme_font_size("font_size") if _label != null else 0


func text_fits() -> bool:
	if _label == null:
		return false
	var measured := BOLD_FONT.get_string_size(
		_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fitted_font_size()
	).x
	return measured <= _label.size.x + 0.01


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var cut := 6.0 * _display_scale
	var shadow_offset := Vector2(0.0, 3.0) * _display_scale
	var outer := _sign_polygon(size, cut)
	var shadow := PackedVector2Array()
	for point in outer:
		shadow.append(point + shadow_offset)
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.48))
	draw_colored_polygon(outer, _border_color.darkened(0.30))
	var inset := 2.0 * _display_scale
	var inner_size := size - Vector2(inset * 2.0, inset * 2.0)
	var inner := _sign_polygon(inner_size, maxf(1.0, cut - inset))
	for index in inner.size():
		inner[index] += Vector2(inset, inset)
	draw_colored_polygon(inner, _board_color)
	draw_polyline(outer, _border_color, maxf(1.0, 1.2 * _display_scale), true)
	draw_polyline(inner, Color(_border_color, 0.65), maxf(1.0, 0.7 * _display_scale), true)
	var rivet_radius := maxf(1.0, 1.15 * _display_scale)
	for x in [8.0 * _display_scale, size.x - 8.0 * _display_scale]:
		draw_circle(Vector2(x, size.y * 0.5), rivet_radius, _border_color.lightened(0.15))


func _sign_polygon(bounds: Vector2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(cut, 0.0),
		Vector2(bounds.x - cut, 0.0),
		Vector2(bounds.x, cut),
		Vector2(bounds.x, bounds.y - cut),
		Vector2(bounds.x - cut, bounds.y),
		Vector2(cut, bounds.y),
		Vector2(0.0, bounds.y - cut),
		Vector2(0.0, cut),
		Vector2(cut, 0.0),
	])
