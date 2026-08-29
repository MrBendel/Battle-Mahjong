extends Control
class_name GameOverlay

const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const PresentationScaleScript := preload("res://scripts/presentation/presentation_scale.gd")
const BOLD_FONT := preload("res://assets/fonts/mila-script-sans-bold-tight.tres")
const REGULAR_FONT := preload("res://assets/fonts/mila-script-sans-regular-tight.tres")
const REFERENCE_SIZE := Vector2(390.0, 844.0)

var _panel: PanelContainer
var _content: VBoxContainer
var _safe_area_insets := Rect2()
var _display_scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2000

	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.005, 0.018, 0.016, 0.86)
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(wash)

	_panel = PanelContainer.new()
	_panel.name = _panel_name()
	add_child(_panel)
	_content = VBoxContainer.new()
	_panel.add_child(_content)
	_build_overlay_content()

	resized.connect(_layout)
	_layout()


func set_safe_area_insets(insets: Rect2) -> void:
	_safe_area_insets = insets
	_layout()


func _panel_name() -> String:
	return "GameOverlayPanel"


func _panel_reference_size() -> Vector2:
	return Vector2(330.0, 340.0)


func _build_overlay_content() -> void:
	pass


func _layout_overlay_content(_scale_factor: float) -> void:
	pass


func _make_title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", BOLD_FONT)
	title.add_theme_color_override("font_color", Color("f5e4a4"))
	return title


func _make_rule() -> HSeparator:
	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", Color("9f7b28"))
	return rule


func _make_command_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_color_override("font_color", Color("f5e4a4"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("fff3bd"))
	return button


func _apply_title_layout(title: Label, scale_factor: float, reference_font_size: float = 27.0) -> void:
	title.add_theme_font_size_override("font_size", roundi(reference_font_size * scale_factor))


func _apply_command_button_layout(
	button: Button,
	scale_factor: float,
	reference_font_size: float = 19.0
) -> void:
	button.custom_minimum_size.y = 48.0 * scale_factor
	button.add_theme_font_size_override("font_size", roundi(reference_font_size * scale_factor))
	button.add_theme_stylebox_override("normal", _button_style(scale_factor, Color("102c27"), Color("9f7b28")))
	button.add_theme_stylebox_override("hover", _button_style(scale_factor, Color("174039"), Color("e1b84b")))
	button.add_theme_stylebox_override("pressed", _button_style(scale_factor, Color("0b211e"), Color("f5d56d")))
	button.add_theme_stylebox_override("focus", _button_style(scale_factor, Color.TRANSPARENT, Color("f5d56d")))


func _layout() -> void:
	if _panel == null:
		return
	var insets := _safe_area_insets
	if insets == Rect2():
		insets = SafeAreaScript.insets(size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var safe_rect := SafeAreaScript.content_rect(size, insets)
	_display_scale = PresentationScaleScript.limiting_scale(safe_rect.size, REFERENCE_SIZE, 0.78)

	var panel_size := _panel_reference_size() * _display_scale
	panel_size.x = minf(panel_size.x, maxf(1.0, safe_rect.size.x - 24.0 * _display_scale))
	panel_size.y = minf(panel_size.y, maxf(1.0, safe_rect.size.y - 24.0 * _display_scale))
	_panel.position = safe_rect.position + (safe_rect.size - panel_size) * 0.5
	_panel.size = panel_size

	var pad := 18.0 * _display_scale
	var panel_style := _panel_style(_display_scale)
	panel_style.content_margin_left = pad
	panel_style.content_margin_right = pad
	panel_style.content_margin_top = 16.0 * _display_scale
	panel_style.content_margin_bottom = 18.0 * _display_scale
	_panel.add_theme_stylebox_override("panel", panel_style)
	_content.add_theme_constant_override("separation", roundi(10.0 * _display_scale))
	_layout_overlay_content(_display_scale)


func _panel_style(scale_factor: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("071e1a")
	style.border_color = Color("d6a83a")
	style.set_border_width_all(maxi(2, roundi(2.0 * scale_factor)))
	style.set_corner_radius_all(roundi(7.0 * scale_factor))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = roundi(8.0 * scale_factor)
	return style


func _button_style(scale_factor: float, background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(scale_factor)))
	style.set_corner_radius_all(roundi(5.0 * scale_factor))
	style.content_margin_left = 12.0 * scale_factor
	style.content_margin_right = 12.0 * scale_factor
	return style
