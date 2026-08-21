extends Control
class_name PauseMenu

signal resumed
signal restart_requested

const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")

var _panel: PanelContainer
var _resume_button: Button
var _restart_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2000

	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.01, 0.02, 0.02, 0.78)
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(wash)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_panel.add_child(content)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	_resume_button = Button.new()
	_resume_button.text = "Resume"
	_resume_button.focus_mode = Control.FOCUS_ALL
	_resume_button.pressed.connect(func() -> void: resumed.emit())
	content.add_child(_resume_button)

	_restart_button = Button.new()
	_restart_button.text = "Restart Game"
	_restart_button.focus_mode = Control.FOCUS_ALL
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	content.add_child(_restart_button)

	resized.connect(_layout)
	_layout()


func open() -> void:
	visible = true
	_resume_button.grab_focus()


func close() -> void:
	_resume_button.release_focus()
	_restart_button.release_focus()
	visible = false


func _layout() -> void:
	if _panel == null:
		return
	var insets := SafeAreaScript.insets(size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var safe_top := insets.position.y

	var panel_size := Vector2(minf(280.0, maxf(220.0, size.x - 28.0)), 174.0)
	var top_pos := maxf(14.0 + safe_top, (size.y - panel_size.y) * 0.4)
	_panel.position = Vector2((size.x - panel_size.x) * 0.5, top_pos)
	_panel.size = panel_size


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171d1d")
	style.border_color = Color("d8b44a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
