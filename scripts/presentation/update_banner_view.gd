extends PanelContainer

signal update_requested()
signal dismissed()

var _message_label: Label
var _update_button: Button
var _dismiss_button: Button
var _store_url: String = "https://play.google.com/apps/internaltest/4701554282456194202"
var _is_mandatory := false

var _fade_tween: Tween = null


func _init() -> void:
	name = "UpdateBannerView"
	z_index = 1200
	_build_ui()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.12, 0.16, 0.95)
	style.border_color = Color(0.2, 0.7, 0.65, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)

	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.text = "🚀 New version available!"
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.clip_text = true
	_message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_message_label.add_theme_font_size_override("font_size", 13)
	_message_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox.add_child(_message_label)

	_update_button = Button.new()
	_update_button.name = "UpdateButton"
	_update_button.text = "Update"
	_update_button.focus_mode = Control.FOCUS_NONE
	_update_button.add_theme_font_size_override("font_size", 13)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.55, 0.45, 1.0)
	btn_style.border_color = Color(0.3, 0.85, 0.7, 1.0)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	btn_style.content_margin_top = 4
	btn_style.content_margin_bottom = 4
	_update_button.add_theme_stylebox_override("normal", btn_style)
	_update_button.pressed.connect(_on_update_pressed)
	hbox.add_child(_update_button)

	_dismiss_button = Button.new()
	_dismiss_button.name = "DismissButton"
	_dismiss_button.text = "✕"
	_dismiss_button.focus_mode = Control.FOCUS_NONE
	_dismiss_button.add_theme_font_size_override("font_size", 13)
	_dismiss_button.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_dismiss_button.pressed.connect(_on_dismiss_pressed)
	hbox.add_child(_dismiss_button)


func apply_scale(ui_scale: float) -> void:
	var font_size := roundi(clampf(14.0 * ui_scale, 12.0, 18.0))
	var btn_font_size := roundi(clampf(13.0 * ui_scale, 11.0, 16.0))
	_message_label.add_theme_font_size_override("font_size", font_size)
	_update_button.add_theme_font_size_override("font_size", btn_font_size)
	_dismiss_button.add_theme_font_size_override("font_size", btn_font_size)

	var pad_h := roundi(clampf(14.0 * ui_scale, 10.0, 24.0))
	var pad_v := roundi(clampf(8.0 * ui_scale, 6.0, 14.0))
	var corner := roundi(clampf(8.0 * ui_scale, 6.0, 14.0))

	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.set_corner_radius_all(corner)
		style.content_margin_left = pad_h
		style.content_margin_right = pad_h
		style.content_margin_top = pad_v
		style.content_margin_bottom = pad_v

	var btn_pad_h := roundi(clampf(12.0 * ui_scale, 8.0, 20.0))
	var btn_pad_v := roundi(clampf(4.0 * ui_scale, 3.0, 10.0))
	var btn_style: StyleBoxFlat = _update_button.get_theme_stylebox("normal") as StyleBoxFlat
	if btn_style != null:
		btn_style.content_margin_left = btn_pad_h
		btn_style.content_margin_right = btn_pad_h
		btn_style.content_margin_top = btn_pad_v
		btn_style.content_margin_bottom = btn_pad_v


func show_update(version_name: String, store_url: String, mandatory: bool = false, custom_message: String = "") -> void:
	_kill_fade_tween()
	modulate.a = 1.0
	_store_url = store_url
	_is_mandatory = mandatory
	if not custom_message.is_empty():
		_message_label.text = custom_message
	elif version_name.is_empty():
		_message_label.text = "🚀 New version available!"
	else:
		var display_vname := version_name
		if display_vname.contains("-internal."):
			display_vname = display_vname.split("-internal.")[0]
		_message_label.text = "🚀 Update available: v%s" % display_vname

	_update_button.visible = true
	if mandatory:
		_dismiss_button.visible = false
	else:
		_dismiss_button.visible = true
	visible = true



func show_status_toast(message: String, duration_sec: float = 4.5) -> void:
	_kill_fade_tween()
	modulate.a = 1.0
	_message_label.text = message
	_update_button.visible = false
	_dismiss_button.visible = true
	visible = true

	if duration_sec > 0.0:
		_fade_tween = create_tween()
		_fade_tween.tween_interval(duration_sec)
		_fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
		_fade_tween.tween_callback(func():
			visible = false
			modulate.a = 1.0
			dismissed.emit()
		)


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null


func _on_update_pressed() -> void:
	_kill_fade_tween()
	modulate.a = 1.0
	update_requested.emit()


func _on_dismiss_pressed() -> void:
	_kill_fade_tween()
	modulate.a = 1.0
	visible = false
	dismissed.emit()

