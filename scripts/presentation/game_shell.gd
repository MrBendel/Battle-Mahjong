extends Control

const DebugPanelScript := preload("res://scripts/ui/debug_panel.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")
const BoardViewScript := preload("res://scripts/presentation/board_view.gd")
const TrayViewScript := preload("res://scripts/presentation/tray_view.gd")
const MomentumViewScript := preload("res://scripts/presentation/momentum_view.gd")
const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const ReferenceGameFactoryScript := preload("res://scripts/simulation/reference_game_factory.gd")
const BoardLayoutCatalogScript := preload("res://scripts/simulation/board_layout_catalog.gd")
const MomentumTuningScript := preload("res://scripts/configuration/momentum_tuning.gd")
const ModifierTuningScript := preload("res://scripts/configuration/modifier_tuning.gd")
const ConsumablesViewScript := preload("res://scripts/presentation/consumables_view.gd")
const START_SEED := 92817361

@export var momentum_tuning: Resource
@export var modifier_tuning: Resource
@export var layout_id: String = BoardLayoutCatalogScript.DEFAULT_LAYOUT_ID

var _rng: RefCounted = DeterministicRngScript.new(START_SEED)
var _regions: Dictionary = {}
var _debug_panel: PanelContainer
var _game: Variant
var _game_started_at_ms := 0
var _delete_pair_armed := false

func _ready() -> void:
	_build_shell()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


func _build_shell() -> void:
	_game = _create_game()
	_game_started_at_ms = Time.get_ticks_msec()
	_regions.board = BoardViewScript.new(_game)
	_regions.momentum = MomentumViewScript.new(_game)
	_regions.tray = TrayViewScript.new(_game)
	_regions.consumables = ConsumablesViewScript.new(_game)
	_regions.character = _make_region("Character / FX", "decorative reaction space", Color(0.17, 0.11, 0.13, 1.0))

	for region in _regions.values():
		add_child(region)

	_regions.board.tile_selected.connect(_on_tile_selected)
	_regions.tray.undo_requested.connect(_on_undo_requested)
	_regions.tray.restart_requested.connect(_on_restart_requested)
	_regions.consumables.hint_requested.connect(_on_hint_requested)
	_regions.consumables.delete_pair_requested.connect(_on_delete_pair_requested)
	_regions.consumables.shuffle_requested.connect(_on_shuffle_requested)

	_debug_panel = DebugPanelScript.new()
	add_child(_debug_panel)


func _create_game() -> Variant:
	var tuning_overrides := {}
	if momentum_tuning == null:
		push_warning("No MomentumTuning resource assigned; using simulation defaults.")
	elif momentum_tuning.get_script() != MomentumTuningScript:
		push_error("Assigned momentum tuning is not a MomentumTuning resource; using simulation defaults.")
	else:
		var tuning_errors: Array[String] = momentum_tuning.validation_errors()
		if tuning_errors.is_empty():
			tuning_overrides = momentum_tuning.configuration_overrides()
		else:
			push_error("Invalid MomentumTuning; using simulation defaults: %s" % " ".join(tuning_errors))
	if modifier_tuning == null:
		push_warning("No ModifierTuning resource assigned; using simulation defaults.")
	elif modifier_tuning.get_script() != ModifierTuningScript:
		push_error("Assigned modifier tuning is not a ModifierTuning resource; using simulation defaults.")
	else:
		var modifier_errors: Array[String] = modifier_tuning.validation_errors()
		if modifier_errors.is_empty():
			tuning_overrides.merge(modifier_tuning.configuration_overrides(), true)
		else:
			push_error("Invalid ModifierTuning; using simulation defaults: %s" % " ".join(modifier_errors))
	var factory := ReferenceGameFactoryScript.new()
	var definition: Variant = factory.call(
		"create_definition",
		_rng.call("get_seed"),
		GameStateScript.BASE_TRAY_CAPACITY,
		tuning_overrides,
		layout_id
	)
	if definition == null and layout_id != BoardLayoutCatalogScript.DEFAULT_LAYOUT_ID:
		push_error("Unknown or invalid layout '%s'; using default." % layout_id)
		definition = factory.call(
			"create_definition",
			_rng.call("get_seed"),
			GameStateScript.BASE_TRAY_CAPACITY,
			tuning_overrides,
			BoardLayoutCatalogScript.DEFAULT_LAYOUT_ID
		)
	return GameStateScript.new(definition)


func _on_tile_selected(tile_id: String) -> void:
	var result: String
	if _delete_pair_armed:
		_delete_pair_armed = false
		result = _game.call("delete_pair", tile_id, _playback_time_ms())
		if result == GameStateScript.NO_DELETABLE_PAIR:
			_regions.consumables.call("show_notice", "That tile has no available matching pair.")
	else:
		result = _game.call("select_tile", tile_id, _playback_time_ms())
	_refresh_game_views()
	if result == GameStateScript.PAIR_RESOLVED:
		var transaction: Variant = _game.call("last_transaction")
		_regions.momentum.call("play_pair_feedback", int(transaction.telemetry.resulting_multiplier))


func _on_undo_requested() -> void:
	_game.call("undo_last_unmatched", _playback_time_ms())
	_refresh_game_views()


func _on_hint_requested() -> void:
	var result: String = _game.call("request_hint", _playback_time_ms())
	if result == GameStateScript.NO_HINT_AVAILABLE:
		_regions.consumables.call("show_notice", "No pair is available. Try another move or Shuffle.")
	else:
		_regions.consumables.call("show_notice", "Suggested pair highlighted.")
	_refresh_game_views()


func _on_delete_pair_requested() -> void:
	_delete_pair_armed = true
	_regions.consumables.call("show_notice", "Choose an available tile to delete its matching pair.")


func _on_shuffle_requested() -> void:
	_delete_pair_armed = false
	var result: String = _game.call("shuffle", _playback_time_ms())
	if result == GameStateScript.SHUFFLED:
		_regions.consumables.call("show_notice", "Board shuffled; tray tiles were preserved.")
	else:
		_regions.consumables.call("show_notice", "Shuffle is unavailable for this position.")
	_refresh_game_views()


func _on_restart_requested() -> void:
	_game = _create_game()
	_game_started_at_ms = Time.get_ticks_msec()
	_regions.board.call("set_game_state", _game)
	_regions.tray.call("set_game_state", _game)
	_regions.momentum.call("set_game_state", _game)
	_regions.consumables.call("set_game_state", _game)
	_delete_pair_armed = false


func _refresh_game_views() -> void:
	_regions.board.call("refresh")
	_regions.tray.call("refresh")
	_regions.momentum.call("refresh", _playback_time_ms())
	_regions.consumables.call("refresh")


func _process(_delta: float) -> void:
	if _game != null and _regions.has("momentum"):
		_regions.momentum.call("refresh", _playback_time_ms())


func _playback_time_ms() -> int:
	return Time.get_ticks_msec() - _game_started_at_ms


func _make_region(title: String, subtitle: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = title.replace(" / ", "_").replace(" ", "_")

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "%s\n%s" % [title, subtitle]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	panel.add_child(label)

	return panel


func _apply_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var viewport_i := Vector2i(int(viewport_size.x), int(viewport_size.y))
	var orientation := "Landscape" if viewport_size.x >= viewport_size.y else "Portrait"

	if orientation == "Landscape":
		_apply_landscape_layout(viewport_size)
	else:
		_apply_portrait_layout(viewport_size)

	_place_debug_panel(viewport_size, orientation)
	_debug_panel.call(
		"set_info",
		_rng.call("get_seed"),
		viewport_i,
		orientation,
		str(_game.definition.configuration.get("layout_id", "unknown"))
	)


func _apply_landscape_layout(size: Vector2) -> void:
	var margin := 16.0
	var gap := 12.0
	var left_width: float = clampf(size.x * 0.20, 220.0, 320.0)
	var right_width: float = clampf(size.x * 0.22, 240.0, 360.0)
	var tray_height: float = clampf(size.y * 0.16, 88.0, 128.0)
	var board_left: float = margin + left_width + gap
	var board_width: float = size.x - board_left - right_width - gap - margin
	var board_height: float = size.y - tray_height - gap - margin * 2.0

	_place(_regions.momentum, Rect2(margin, margin, left_width, 96.0))
	_place(_regions.consumables, Rect2(margin, margin + 96.0 + gap, left_width, size.y - margin * 2.0 - 96.0 - gap))
	_place(_regions.board, Rect2(board_left, margin, board_width, board_height))
	_place(_regions.tray, Rect2(board_left, margin + board_height + gap, board_width, tray_height))
	_place(_regions.character, Rect2(board_left + board_width + gap, margin, right_width, size.y - margin * 2.0))


func _apply_portrait_layout(size: Vector2) -> void:
	var margin := 14.0
	var gap := 10.0
	var usable_width := size.x - margin * 2.0
	var momentum_height := 64.0
	var debug_height := 120.0
	var board_height: float = clampf(size.y * 0.39, 260.0, size.y * 0.46)
	var tray_height := 86.0
	var consumables_height := 90.0
	var board_top: float = margin + momentum_height + gap + debug_height + gap
	var character_top: float = board_top + board_height + gap + tray_height + gap + consumables_height + gap
	var character_height: float = maxf(72.0, size.y - character_top - margin)

	_place(_regions.momentum, Rect2(margin, margin, usable_width, momentum_height))
	_place(_regions.board, Rect2(margin, board_top, usable_width, board_height))
	_place(_regions.tray, Rect2(margin, board_top + board_height + gap, usable_width, tray_height))
	_place(_regions.consumables, Rect2(margin, board_top + board_height + gap + tray_height + gap, usable_width, consumables_height))
	_place(_regions.character, Rect2(margin, character_top, usable_width, character_height))


func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size


func _place_debug_panel(size: Vector2, orientation: String) -> void:
	var panel_size := Vector2(220.0, 104.0)
	var panel_position := Vector2(max(12.0, size.x - panel_size.x - 18.0), 18.0)
	if orientation == "Portrait":
		panel_size.x = size.x - 28.0
		panel_size.y = 120.0
		panel_position = Vector2(14.0, 88.0)
	_debug_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_panel.position = panel_position
	_debug_panel.size = panel_size
