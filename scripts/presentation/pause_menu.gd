extends Control
class_name PauseMenu

signal resumed
signal restart_requested
signal sound_changed(enabled: bool)
signal haptics_changed(enabled: bool)

const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const BOLD_FONT := preload("res://assets/fonts/mila-script-sans-bold-tight.tres")
const REGULAR_FONT := preload("res://assets/fonts/mila-script-sans-regular-tight.tres")
const REFERENCE_SIZE := Vector2(390.0, 844.0)
const PANEL_REFERENCE_SIZE := Vector2(330.0, 340.0)

var _panel: PanelContainer
var _content: VBoxContainer
var _title: Label
var _sound_toggle: CheckButton
var _haptics_toggle: CheckButton
var _resume_button: Button
var _restart_button: Button
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
	_panel.name = "PausePanel"
	add_child(_panel)

	_content = VBoxContainer.new()
	_panel.add_child(_content)

	_title = Label.new()
	_title.text = "PAUSED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", BOLD_FONT)
	_title.add_theme_color_override("font_color", Color("f5e4a4"))
	_content.add_child(_title)

	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", Color("9f7b28"))
	_content.add_child(rule)

	_sound_toggle = _make_toggle("SOUND")
	_sound_toggle.toggled.connect(func(enabled: bool) -> void:
		_update_toggle_text(_sound_toggle, "SOUND", enabled)
		sound_changed.emit(enabled)
	)
	_content.add_child(_sound_toggle)

	_haptics_toggle = _make_toggle("HAPTICS")
	_haptics_toggle.toggled.connect(func(enabled: bool) -> void:
		_update_toggle_text(_haptics_toggle, "HAPTICS", enabled)
		haptics_changed.emit(enabled)
	)
	_content.add_child(_haptics_toggle)

	_resume_button = _make_command_button("RESUME")
	_resume_button.pressed.connect(func() -> void: resumed.emit())
	_content.add_child(_resume_button)

	_restart_button = _make_command_button("RESTART GAME")
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_content.add_child(_restart_button)

	resized.connect(_layout)
	_layout()


func open() -> void:
	visible = true
	_layout()
	_resume_button.grab_focus()


func close() -> void:
	_resume_button.release_focus()
	_restart_button.release_focus()
	_sound_toggle.release_focus()
	_haptics_toggle.release_focus()
	visible = false


func set_preferences(sound_enabled: bool, haptics_enabled: bool) -> void:
	_sound_toggle.set_pressed_no_signal(sound_enabled)
	_haptics_toggle.set_pressed_no_signal(haptics_enabled)
	_update_toggle_text(_sound_toggle, "SOUND", sound_enabled)
	_update_toggle_text(_haptics_toggle, "HAPTICS", haptics_enabled)


func set_safe_area_insets(insets: Rect2) -> void:
	_safe_area_insets = insets
	_layout()


func _make_toggle(label_text: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.button_pressed = true
	toggle.text = "%s    ON" % label_text
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.add_theme_font_override("font", REGULAR_FONT)
	toggle.add_theme_color_override("font_color", Color("f2e8c8"))
	toggle.add_theme_color_override("font_pressed_color", Color("fff3bd"))
	return toggle


func _make_command_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_color_override("font_color", Color("f5e4a4"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("fff3bd"))
	return button


func _update_toggle_text(toggle: CheckButton, label_text: String, enabled: bool) -> void:
	toggle.text = "%s    %s" % [label_text, "ON" if enabled else "OFF"]


func _layout() -> void:
	if _panel == null:
		return
	var insets := _safe_area_insets
	if insets == Rect2():
		insets = SafeAreaScript.insets(size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var safe_rect := SafeAreaScript.content_rect(size, insets)
	_display_scale = maxf(0.78, minf(safe_rect.size.x / REFERENCE_SIZE.x, safe_rect.size.y / REFERENCE_SIZE.y))

	var panel_size := PANEL_REFERENCE_SIZE * _display_scale
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
	_title.add_theme_font_size_override("font_size", roundi(27.0 * _display_scale))

	for toggle in [_sound_toggle, _haptics_toggle]:
		toggle.custom_minimum_size.y = 44.0 * _display_scale
		toggle.add_theme_font_size_override("font_size", roundi(18.0 * _display_scale))
		toggle.add_theme_constant_override("h_separation", roundi(10.0 * _display_scale))
	for button in [_resume_button, _restart_button]:
		button.custom_minimum_size.y = 48.0 * _display_scale
		button.add_theme_font_size_override("font_size", roundi(19.0 * _display_scale))
		button.add_theme_stylebox_override("normal", _button_style(_display_scale, Color("102c27"), Color("9f7b28")))
		button.add_theme_stylebox_override("hover", _button_style(_display_scale, Color("174039"), Color("e1b84b")))
		button.add_theme_stylebox_override("pressed", _button_style(_display_scale, Color("0b211e"), Color("f5d56d")))
		button.add_theme_stylebox_override("focus", _button_style(_display_scale, Color.TRANSPARENT, Color("f5d56d")))


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
	return style
