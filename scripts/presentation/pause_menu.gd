extends "res://scripts/presentation/game_overlay.gd"
class_name PauseMenu

signal resumed
signal restart_requested
signal sound_changed(enabled: bool)
signal haptics_changed(enabled: bool)

const PANEL_REFERENCE_SIZE := Vector2(330.0, 340.0)

var _title: Label
var _sound_toggle: CheckButton
var _haptics_toggle: CheckButton
var _resume_button: Button
var _restart_button: Button
var _transparent_toggle_icon: ImageTexture


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


func _panel_name() -> String:
	return "PausePanel"


func _panel_reference_size() -> Vector2:
	return PANEL_REFERENCE_SIZE


func _build_overlay_content() -> void:
	_title = _make_title("PAUSED")
	_content.add_child(_title)
	_content.add_child(_make_rule())

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


func _make_toggle(label_text: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.button_pressed = true
	toggle.text = "%s    ON" % label_text
	toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.add_theme_font_override("font", REGULAR_FONT)
	toggle.add_theme_color_override("font_color", Color("f2e8c8"))
	toggle.add_theme_color_override("font_hover_color", Color.WHITE)
	toggle.add_theme_color_override("font_pressed_color", Color("fff3bd"))
	var transparent_icon := _toggle_icon()
	for icon_name in ["checked", "checked_disabled", "unchecked", "unchecked_disabled"]:
		toggle.add_theme_icon_override(icon_name, transparent_icon)
	return toggle


func _toggle_icon() -> ImageTexture:
	if _transparent_toggle_icon == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		_transparent_toggle_icon = ImageTexture.create_from_image(image)
	return _transparent_toggle_icon


func _update_toggle_text(toggle: CheckButton, label_text: String, enabled: bool) -> void:
	toggle.text = "%s    %s" % [label_text, "ON" if enabled else "OFF"]


func _layout_overlay_content(scale_factor: float) -> void:
	_apply_title_layout(_title, scale_factor)
	for toggle in [_sound_toggle, _haptics_toggle]:
		toggle.custom_minimum_size.y = 44.0 * scale_factor
		toggle.add_theme_font_size_override("font_size", roundi(18.0 * scale_factor))
		toggle.add_theme_constant_override("h_separation", 0)
		toggle.add_theme_stylebox_override("normal", _button_style(scale_factor, Color("0b2520"), Color("426b52")))
		toggle.add_theme_stylebox_override("hover", _button_style(scale_factor, Color("12352e"), Color("d6a83a")))
		toggle.add_theme_stylebox_override("pressed", _button_style(scale_factor, Color("081b18"), Color("f5d56d")))
		toggle.add_theme_stylebox_override("focus", _button_style(scale_factor, Color.TRANSPARENT, Color("f5d56d")))
	for button in [_resume_button, _restart_button]:
		_apply_command_button_layout(button, scale_factor)
