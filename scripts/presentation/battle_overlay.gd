extends "res://scripts/presentation/game_overlay.gd"

signal resumed
signal restarted
signal town_requested
var title: Label
var resume_button: Button
var retry_button: Button
var town_button: Button
var _reaction_art: TextureRect
var _reaction_line: Label

func _build_overlay_content() -> void:
	title = _make_title("PREPARING BATTLE")
	_content.add_child(title)
	_reaction_art = TextureRect.new()
	_reaction_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reaction_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reaction_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_reaction_art)
	_reaction_line = _make_title("")
	_reaction_line.clip_text = true
	_reaction_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_content.add_child(_reaction_line)
	clear_reaction()
	resume_button = _make_command_button("Resume")
	retry_button = _make_command_button("New Battle")
	town_button = _make_command_button("Town")
	for button in [resume_button, retry_button, town_button]:
		_content.add_child(button)
	resume_button.pressed.connect(func() -> void: resumed.emit())
	retry_button.pressed.connect(func() -> void: restarted.emit())
	town_button.pressed.connect(func() -> void: town_requested.emit())

func show_message(message: String, can_resume: bool) -> void:
	title.text = message
	resume_button.visible = can_resume
	visible = true

func _layout_overlay_content(s: float) -> void:
	_apply_title_layout(title, s, 24)
	_reaction_art.custom_minimum_size.y = 76 * s
	_apply_title_layout(_reaction_line, s, 17)
	for button in [resume_button, retry_button, town_button]:
		_apply_command_button_layout(button, s, 20)

func clear_reaction() -> void:
	_reaction_art.hide()
	_reaction_line.hide()

func show_reaction(texture: Texture2D, text: String) -> void:
	_reaction_art.texture = texture
	_reaction_art.visible = texture != null
	_reaction_line.text = text
	_reaction_line.visible = not text.is_empty()
	_layout()
