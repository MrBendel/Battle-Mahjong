extends "res://scripts/presentation/game_overlay.gd"
class_name LayoutGeneratorPicker

signal seed_requested(seed: int)
signal accepted

var _seed: int
var _title: Label
var _seed_input: LineEdit
var _previous_button: Button
var _next_button: Button
var _roll_button: Button
var _generate_button: Button
var _motif_label: Label
var _metrics_label: Label
var _use_button: Button


func _init(initial_seed: int) -> void:
	_seed = maxi(1, initial_seed)


func _panel_name() -> String:
	return "LayoutGeneratorPanel"


func _panel_reference_size() -> Vector2:
	return Vector2(350.0, 390.0)


func _build_overlay_content() -> void:
	var wash := get_child(0) as ColorRect
	if wash != null:
		wash.color = Color(0.005, 0.018, 0.016, 0.58)
	_title = _make_title("BUILD A BOARD")
	_content.add_child(_title)
	_content.add_child(_make_rule())

	var seed_label := Label.new()
	seed_label.text = "LAYOUT SEED"
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_label.add_theme_font_override("font", REGULAR_FONT)
	seed_label.add_theme_color_override("font_color", Color("b8d7bd"))
	_content.add_child(seed_label)

	var seed_row := HBoxContainer.new()
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(seed_row)
	_previous_button = _make_command_button("-")
	_previous_button.pressed.connect(_step_seed.bind(-1))
	seed_row.add_child(_previous_button)
	_seed_input = LineEdit.new()
	_seed_input.text = str(_seed)
	_seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_seed_input.add_theme_font_override("font", BOLD_FONT)
	_seed_input.text_submitted.connect(func(_value: String) -> void: _request_current_seed())
	seed_row.add_child(_seed_input)
	_next_button = _make_command_button("+")
	_next_button.pressed.connect(_step_seed.bind(1))
	seed_row.add_child(_next_button)

	var command_row := HBoxContainer.new()
	command_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(command_row)
	_roll_button = _make_command_button("ROLL SEED")
	_roll_button.pressed.connect(_roll_seed)
	command_row.add_child(_roll_button)
	_generate_button = _make_command_button("GENERATE")
	_generate_button.pressed.connect(_request_current_seed)
	command_row.add_child(_generate_button)

	_motif_label = Label.new()
	_motif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_motif_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_motif_label.add_theme_font_override("font", BOLD_FONT)
	_motif_label.add_theme_color_override("font_color", Color("f5e4a4"))
	_content.add_child(_motif_label)
	_metrics_label = Label.new()
	_metrics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metrics_label.add_theme_font_override("font", REGULAR_FONT)
	_metrics_label.add_theme_color_override("font_color", Color("b8d7bd"))
	_content.add_child(_metrics_label)

	_use_button = _make_command_button("USE THIS BOARD")
	_use_button.disabled = true
	_use_button.pressed.connect(func() -> void: accepted.emit())
	_content.add_child(_use_button)


func set_result(seed: int, layout: Variant, error: String = "") -> void:
	_seed = maxi(1, seed)
	_seed_input.text = str(_seed)
	if layout == null:
		_motif_label.text = "GENERATION FAILED"
		_metrics_label.text = error
		_use_button.disabled = true
		return
	var metadata: Dictionary = layout.metadata
	var motifs: Array = metadata.get("selected_motifs", [])
	var metrics: Dictionary = metadata.get("mobile_fit", {})
	_motif_label.text = " / ".join(motifs).to_upper()
	_metrics_label.text = "%d TILES  |  %d LAYERS  |  %d OPEN  |  ~%dPX" % [
		layout.slots.size(),
		int(metrics.get("layer_count", 0)),
		int(metrics.get("initial_selectable_tile_count", 0)),
		int(metrics.get("estimated_reference_tile_width_px", 0)),
	]
	_use_button.disabled = false


func request_seed_for_testing(seed: int) -> void:
	_seed_input.text = str(seed)
	_request_current_seed()


func accept_for_testing() -> void:
	if not _use_button.disabled:
		accepted.emit()


func _step_seed(amount: int) -> void:
	_seed_input.text = str(maxi(1, _parsed_seed() + amount))
	_request_current_seed()


func _roll_seed() -> void:
	_seed_input.text = str((int(_parsed_seed()) * 48271) % 2147483647)
	_request_current_seed()


func _request_current_seed() -> void:
	_seed = _parsed_seed()
	_seed_input.text = str(_seed)
	_use_button.disabled = true
	_motif_label.text = "GENERATING..."
	_metrics_label.text = ""
	seed_requested.emit(_seed)


func _parsed_seed() -> int:
	return maxi(1, int(_seed_input.text))


func _layout_overlay_content(scale_factor: float) -> void:
	_apply_title_layout(_title, scale_factor)
	for button in [_previous_button, _next_button, _roll_button, _generate_button, _use_button]:
		_apply_command_button_layout(button, scale_factor, 18.0)
	_previous_button.custom_minimum_size.x = 48.0 * scale_factor
	_next_button.custom_minimum_size.x = 48.0 * scale_factor
	_seed_input.custom_minimum_size = Vector2(170.0, 48.0) * scale_factor
	_seed_input.add_theme_font_size_override("font_size", roundi(20.0 * scale_factor))
	_roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_motif_label.add_theme_font_size_override("font_size", roundi(15.0 * scale_factor))
	_metrics_label.add_theme_font_size_override("font_size", roundi(14.0 * scale_factor))
