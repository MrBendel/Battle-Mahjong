extends PanelContainer

signal update_requested()
signal dismissed()

var _message_label: Label
var _update_button: Button
var _dismiss_button: Button
var _store_url: String = "https://play.google.com/apps/internaltest/4701554282456194202"
var _is_mandatory := false

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
	_message_label.add_theme_font_size_override("font_size", 15)
	_message_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox.add_child(_message_label)

	_update_button = Button.new()
	_update_button.name = "UpdateButton"
	_update_button.text = "Update"
	_update_button.focus_mode = Control.FOCUS_NONE
	_update_button.add_theme_font_size_override("font_size", 14)

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
	_dismiss_button.add_theme_font_size_override("font_size", 14)
	_dismiss_button.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_dismiss_button.pressed.connect(_on_dismiss_pressed)
	hbox.add_child(_dismiss_button)


func show_update(version_name: String, store_url: String, mandatory: bool = false) -> void:
	_store_url = store_url
	_is_mandatory = mandatory
	if version_name.is_empty():
		_message_label.text = "🚀 New version available!"
	else:
		_message_label.text = "🚀 Update available: %s" % version_name

	if mandatory:
		_dismiss_button.visible = false
	else:
		_dismiss_button.visible = true
	visible = true


func _on_update_pressed() -> void:
	update_requested.emit()
	if not _store_url.is_empty():
		OS.shell_open(_store_url)


func _on_dismiss_pressed() -> void:
	visible = false
	dismissed.emit()
