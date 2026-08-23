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
const TileSkinScript := preload("res://scripts/presentation/tile_skin.gd")
const PairMatchFxScript := preload("res://scripts/presentation/pair_match_fx.gd")
const PerformanceCalloutScript := preload("res://scripts/presentation/performance_callout_view.gd")
const PauseMenuScript := preload("res://scripts/presentation/pause_menu.gd")
const EndGameMenuScript := preload("res://scripts/presentation/end_game_menu.gd")
const GameChangeScript := preload("res://scripts/simulation/game_change.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const UpdateBannerViewScript := preload("res://scripts/presentation/update_banner_view.gd")
const UpdateCheckerScript := preload("res://scripts/presentation/update_checker.gd")
const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const GAMEPLAY_BACKGROUND := preload("res://game-assets/backgrounds/gameplay_brush_arcade.png")
const START_SEED := 92817361
const PAIR_LANDING_HOLD_SECONDS := 0.12
const FLIPPED_REVEAL_SECONDS := 0.16
const FLIPPED_PAIR_ARC_SECONDS := 0.34

@export var momentum_tuning: Resource
@export var modifier_tuning: Resource
@export var layout_id: String = BoardLayoutCatalogScript.DEFAULT_LAYOUT_ID
@export_range(0, 48, 1) var flipped_tile_count := 12

var _rng: RefCounted = DeterministicRngScript.new(START_SEED)
var _regions: Dictionary = {}
var _debug_panel: PanelContainer
var _game: Variant
var _game_started_at_ms := 0
var _delete_pair_armed := false
var _tile_skin: Variant
var _tile_motion_count := 0
var _last_tile_motion_target := Rect2()
var _pair_feedback_count := 0
var _last_pair_feedback_position := Vector2()
var _pair_collision_count := 0
var _last_pair_collision_position := Vector2()
var _flipped_pair_arc_count := 0
var _flipped_pair_tray_count := 0
var _last_flipped_pair_curves: Array = []
var _undo_motion_count := 0
var _last_undo_motion_target := Rect2()
var _tile_transfer_previews := {}
var _tile_transfer_tweens := {}
var _gameplay_background: TextureRect
var _pause_button: Button
var _pause_menu: Control
var _end_game_menu: Control
var _pause_started_at_ms := -1
var _game_over_time_ms := -1
var _paused_duration_ms := 0
var _performance_callout: Control
var _update_banner: PanelContainer
var _update_checker: Node
var _safe_area_override := Rect2(-1.0, -1.0, -1.0, -1.0)
var _android_capture_frames_remaining := 0

func _ready() -> void:
	_build_shell()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


func _build_shell() -> void:
	_build_gameplay_background()
	_game = _create_game()
	_tile_skin = TileSkinScript.new()
	_game_started_at_ms = Time.get_ticks_msec()
	_regions.board = BoardViewScript.new(_game, _tile_skin)
	_regions.momentum = MomentumViewScript.new(_game)
	_regions.tray = TrayViewScript.new(_game, _tile_skin)
	_regions.consumables = ConsumablesViewScript.new(_game)
	_regions.character = _make_region("Character / FX", "decorative reaction space", Color(0.17, 0.11, 0.13, 1.0))

	for region in _regions.values():
		add_child(region)
	_performance_callout = PerformanceCalloutScript.new()
	add_child(_performance_callout)

	_regions.board.tile_selected.connect(_on_tile_selected)
	_regions.board.locked_tile_tapped.connect(_on_locked_tile_tapped)
	_regions.consumables.hint_requested.connect(_on_hint_requested)
	_regions.consumables.delete_pair_requested.connect(_on_delete_pair_requested)
	_regions.consumables.shuffle_requested.connect(_on_shuffle_requested)
	_regions.consumables.undo_requested.connect(_on_undo_requested)

	_update_banner = UpdateBannerViewScript.new()
	_update_banner.visible = false
	_update_banner.dismissed.connect(_apply_layout)
	_update_banner.update_requested.connect(_on_update_requested)
	add_child(_update_banner)

	_update_checker = UpdateCheckerScript.new()
	_update_checker.name = "UpdateChecker"
	_update_checker.update_available.connect(_on_update_available)
	add_child(_update_checker)
	_update_checker.call("check_for_updates")

	_debug_panel = DebugPanelScript.new()
	add_child(_debug_panel)
	_build_pause_menu()
	_build_end_game_menu()


func _on_update_available(version_name: String, store_url: String, mandatory: bool) -> void:
	_update_banner.call("show_update", version_name, store_url, mandatory)
	_apply_layout()


func _on_update_requested() -> void:
	if _update_checker != null and _update_checker.has_method("start_in_app_update"):
		_update_checker.call("start_in_app_update", false)



func _build_pause_menu() -> void:
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = "Ⅱ"
	_pause_button.tooltip_text = "Pause"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.z_index = 1500
	_pause_button.pressed.connect(_on_pause_requested)
	add_child(_pause_button)

	_pause_menu = PauseMenuScript.new()
	_pause_menu.visible = false
	_pause_menu.resumed.connect(_on_resume_requested)
	_pause_menu.restart_requested.connect(_on_restart_requested)
	add_child(_pause_menu)


func _build_end_game_menu() -> void:
	_end_game_menu = EndGameMenuScript.new()
	_end_game_menu.visible = false
	_end_game_menu.restart_requested.connect(_on_restart_requested)
	_end_game_menu.undo_requested.connect(_on_end_game_undo_requested)
	add_child(_end_game_menu)


func _on_end_game_undo_requested() -> void:
	if _end_game_menu != null:
		_end_game_menu.call("close")
	_game_over_time_ms = -1
	if _pause_button != null:
		_pause_button.visible = true
	_on_undo_requested()


func _build_gameplay_background() -> void:
	_gameplay_background = TextureRect.new()
	_gameplay_background.name = "GameplayBackground"
	_gameplay_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameplay_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gameplay_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_gameplay_background.texture = GAMEPLAY_BACKGROUND
	_gameplay_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gameplay_background)

	var wash := ColorRect.new()
	wash.name = "GameplayBackgroundWash"
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.01, 0.025, 0.025, 0.24)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)


func _create_game() -> Variant:
	var tuning_overrides := {"flipped_tile_count": flipped_tile_count}
	if momentum_tuning == null:
		push_warning("No MomentumTuning resource assigned; using simulation defaults.")
	elif momentum_tuning.get_script() != MomentumTuningScript:
		push_error("Assigned momentum tuning is not a MomentumTuning resource; using simulation defaults.")
	else:
		var tuning_errors: Array[String] = momentum_tuning.validation_errors()
		if tuning_errors.is_empty():
			tuning_overrides.merge(momentum_tuning.configuration_overrides(), true)
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
	if _pause_started_at_ms >= 0 or _game_over_time_ms >= 0 or _game.status != GameStateScript.PLAYING:
		return
	var revealed_before := _active_revealed_flipped_tile_ids()
	var result: String
	var tile_preview: Control = null
	var matching_preview: Control = null
	var source_rect := Rect2()
	var target_rect := Rect2()
	var matching_source_rect := Rect2()
	if _delete_pair_armed:
		_delete_pair_armed = false
		_regions.board.call("set_delete_pair_armed", false)
		result = _game.call("delete_pair", tile_id, _playback_time_ms())
		if result == GameStateScript.NO_DELETABLE_PAIR:
			_regions.consumables.call("show_notice", "That tile has no available matching pair.")
		elif result == GameStateScript.PAIR_DELETED:
			var transaction: Variant = _game.call("last_transaction")
			var removal_visuals := _capture_board_visuals(_resolved_tile_ids(transaction))
			_refresh_game_views()
			_play_board_pair_removal(removal_visuals)
			return
	else:
		var face_down: bool = _game.board.call("is_tile_face_down", tile_id)
		var flipped_candidate: Dictionary = _game.call("flipped_match_candidate", tile_id)
		if face_down or not flipped_candidate.is_empty():
			var direct_visuals := _capture_board_visuals([tile_id], face_down)
			var direct_matching_zone := ""
			if not flipped_candidate.is_empty():
				var matching_tile_id := str(flipped_candidate.tile_id)
				direct_matching_zone = str(flipped_candidate.zone)
				if direct_matching_zone == GameStateDataScript.ZONE_BOARD:
					direct_visuals.append_array(_capture_board_visuals([matching_tile_id]))
				else:
					var tray_index := _tray_index_for_tile(matching_tile_id)
					if tray_index >= 0:
						var tray_preview: Control = _regions.tray.call("create_tile_preview", tray_index)
						if tray_preview != null:
							direct_visuals.append({
								"preview": tray_preview,
								"rect": _regions.tray.call("slot_global_rect", tray_index),
							})
			result = _game.call("tap_tile", tile_id, _playback_time_ms())
			_refresh_game_views()
			_play_flip_backs(revealed_before)
			if result == GameStateScript.TILE_REVEALED:
				for visual in direct_visuals:
					visual.preview.queue_free()
				_regions.board.call("play_flip", tile_id)
			elif result == GameStateScript.FLIPPED_PAIR_RESOLVED:
				if direct_matching_zone == GameStateDataScript.ZONE_TRAY:
					_play_flipped_pair_to_tray(direct_visuals)
				else:
					_play_flipped_pair_collision(direct_visuals)
				var direct_transaction: Variant = _game.call("last_transaction")
				_regions.momentum.call("play_pair_feedback", int(direct_transaction.telemetry.resulting_multiplier))
			else:
				for visual in direct_visuals:
					visual.preview.queue_free()
			return
		var matching_index := _matching_tray_index(tile_id)
		tile_preview = _regions.board.call("create_tile_preview", tile_id)
		source_rect = _regions.board.call("tile_global_rect", tile_id)
		var target_index: int = mini(_game.tray.tiles.size(), 3)
		target_rect = _regions.tray.call("slot_global_rect", target_index)
		if matching_index >= 0:
			matching_preview = _regions.tray.call("create_tile_preview", matching_index)
			matching_source_rect = _regions.tray.call("slot_global_rect", matching_index)
		result = _game.call("select_tile", tile_id, _playback_time_ms())
		if _tray_contains_tile(tile_id):
			_regions.tray.call("suppress_tile", tile_id)
	_refresh_game_views()
	_play_flip_backs(revealed_before)
	if tile_preview != null and result != GameStateScript.INVALID_SELECTION:
		if result == GameStateScript.PAIR_RESOLVED:
			_play_pair_to_tray(tile_preview, matching_preview, source_rect, target_rect, matching_source_rect)
		else:
			_play_tile_to_tray(tile_preview, source_rect, target_rect, tile_id)
	elif tile_preview != null:
		tile_preview.queue_free()
	if matching_preview != null and result != GameStateScript.PAIR_RESOLVED:
		matching_preview.queue_free()
	if result == GameStateScript.PAIR_RESOLVED:
		var transaction: Variant = _game.call("last_transaction")
		_regions.momentum.call("play_pair_feedback", int(transaction.telemetry.resulting_multiplier))
		if transaction.telemetry.has("difficulty_reward"):
			_performance_callout.call("play_reward", transaction.telemetry.difficulty_reward)


func _active_revealed_flipped_tile_ids() -> Array[String]:
	var ids: Array[String] = []
	for tile_id in _game.call("current_snapshot").revealed_flipped_tile_ids:
		if _game.board.call("is_tile_revealed_flipped", tile_id):
			ids.append(tile_id)
	return ids


func _play_flip_backs(previously_revealed_ids: Array[String]) -> void:
	for tile_id in previously_revealed_ids:
		if _game.board.call("is_tile_face_down", tile_id):
			_regions.board.call("play_flip", tile_id)


func _on_locked_tile_tapped(tile_id: String) -> void:
	if _pause_started_at_ms >= 0 or _game_over_time_ms >= 0 or _game.status != GameStateScript.PLAYING:
		return
	_game.call("break_combo_for_locked_tile", tile_id, _playback_time_ms())
	_regions.momentum.call("refresh", _playback_time_ms())


func _on_undo_requested() -> void:
	if _pause_started_at_ms >= 0:
		return
	var tray_index: int = _game.tray.tiles.size() - 1
	var tile_id := ""
	var preview: Control = null
	var source_rect := Rect2()
	if tray_index >= 0:
		tile_id = _game.tray.tiles[tray_index].id
		preview = _take_active_tile_transfer(tile_id)
		if preview != null:
			source_rect = preview.get_global_rect()
		else:
			preview = _regions.tray.call("create_tile_preview", tray_index)
			source_rect = _regions.tray.call("slot_global_rect", tray_index)
	var result: String = _game.call("undo_last_unmatched", _playback_time_ms())
	_refresh_game_views()
	if result == GameStateScript.UNDONE and preview != null:
		var target_rect: Rect2 = _regions.board.call("tile_global_rect", tile_id)
		_regions.board.call("suppress_tile", tile_id)
		_play_undo_to_board(preview, source_rect, target_rect, tile_id)
	elif preview != null:
		preview.queue_free()


func _on_hint_requested() -> void:
	if _pause_started_at_ms >= 0 or _game_over_time_ms >= 0 or _game.status != GameStateScript.PLAYING:
		return
	var result: String = _game.call("request_hint", _playback_time_ms())
	if result == GameStateScript.NO_HINT_AVAILABLE:
		_regions.consumables.call("show_notice", "No pair is available. Try another move or Shuffle.")
	else:
		_regions.consumables.call("show_notice", "Suggested pair highlighted.")
	_refresh_game_views()


func _on_delete_pair_requested() -> void:
	if _pause_started_at_ms >= 0 or _game_over_time_ms >= 0 or _game.status != GameStateScript.PLAYING:
		return
	_delete_pair_armed = true
	_regions.board.call("set_delete_pair_armed", true)
	_regions.consumables.call("show_notice", "Choose any visible tile to delete its visible matching pair.")


func _on_shuffle_requested() -> void:
	if _pause_started_at_ms >= 0 or _game_over_time_ms >= 0 or _game.status != GameStateScript.PLAYING:
		return
	_delete_pair_armed = false
	_regions.board.call("set_delete_pair_armed", false)
	var result: String = _game.call("shuffle", _playback_time_ms())
	if result == GameStateScript.SHUFFLED:
		_regions.consumables.call("show_notice", "Board shuffled; tray tiles were preserved.")
	else:
		_regions.consumables.call("show_notice", "Shuffle is unavailable for this position.")
	_refresh_game_views()


func _on_restart_requested() -> void:
	_pause_started_at_ms = -1
	_game_over_time_ms = -1
	_paused_duration_ms = 0
	if _pause_menu != null:
		_pause_menu.call("close")
	if _end_game_menu != null:
		_end_game_menu.call("close")
	if _pause_button != null:
		_pause_button.visible = true
	_game = _create_game()
	_game_started_at_ms = Time.get_ticks_msec()
	_regions.board.call("set_game_state", _game)
	_regions.tray.call("set_game_state", _game)
	_regions.momentum.call("set_game_state", _game)
	_regions.consumables.call("set_game_state", _game)
	_performance_callout.call("reset")
	_delete_pair_armed = false
	_regions.board.call("set_delete_pair_armed", false)


func _on_pause_requested() -> void:
	if _pause_started_at_ms >= 0 or _game_over_time_ms >= 0 or _game.status != GameStateScript.PLAYING:
		return
	_pause_started_at_ms = Time.get_ticks_msec()
	_pause_button.visible = false
	_pause_menu.call("open")


func _on_resume_requested() -> void:
	if _pause_started_at_ms < 0:
		return
	_paused_duration_ms += Time.get_ticks_msec() - _pause_started_at_ms
	_pause_started_at_ms = -1
	_pause_menu.call("close")
	_pause_button.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _pause_started_at_ms >= 0:
			_on_resume_requested()
		else:
			_on_pause_requested()
		get_viewport().set_input_as_handled()


func _refresh_game_views() -> void:
	_regions.board.call("refresh")
	_regions.tray.call("refresh")
	_regions.momentum.call("refresh", _playback_time_ms())
	_regions.consumables.call("refresh")
	_check_game_over()


func _check_game_over() -> void:
	if _game == null or _game.status == GameStateScript.PLAYING:
		return
	if _game_over_time_ms < 0:
		_game_over_time_ms = _playback_time_ms()
		if _pause_button != null:
			_pause_button.visible = false
		if _end_game_menu != null:
			_end_game_menu.call("show_result", _game, _game_over_time_ms)


func _play_tile_to_tray(preview: Control, source_rect: Rect2, target_rect: Rect2, tile_id: String) -> void:
	add_child(preview)
	preview.position = _global_to_local(source_rect.position)
	preview.size = source_rect.size
	preview.pivot_offset = preview.size * 0.5
	preview.z_index = 1000
	var target_position: Vector2 = _global_to_local(target_rect.get_center()) - preview.size * 0.5
	_tile_motion_count += 1
	_last_tile_motion_target = target_rect
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tile_transfer_previews[tile_id] = preview
	_tile_transfer_tweens[tile_id] = tween
	tween.set_parallel(true)
	tween.tween_property(preview, "position", target_position, 0.18)
	tween.tween_property(preview, "rotation", deg_to_rad(-3.0), 0.09)
	tween.chain().tween_property(preview, "modulate:a", 0.0, 0.06)
	tween.finished.connect(_finish_tile_to_tray.bind(preview, tile_id))


func _finish_tile_to_tray(preview: Control, tile_id: String) -> void:
	_tile_transfer_previews.erase(tile_id)
	_tile_transfer_tweens.erase(tile_id)
	if is_instance_valid(preview):
		preview.queue_free()
	_regions.tray.call("reveal_tile", tile_id)


func _take_active_tile_transfer(tile_id: String) -> Control:
	var preview: Control = _tile_transfer_previews.get(tile_id)
	if preview == null:
		return null
	var tween: Tween = _tile_transfer_tweens.get(tile_id)
	if tween != null and tween.is_valid():
		tween.kill()
	_tile_transfer_previews.erase(tile_id)
	_tile_transfer_tweens.erase(tile_id)
	_regions.tray.call("reveal_tile", tile_id)
	return preview


func _play_undo_to_board(preview: Control, source_rect: Rect2, target_rect: Rect2, tile_id: String) -> void:
	if preview.get_parent() == null:
		add_child(preview)
	preview.position = _global_to_local(source_rect.position)
	preview.size = source_rect.size
	preview.pivot_offset = preview.size * 0.5
	preview.modulate = Color.WHITE
	preview.z_index = 1000
	var target_position := _global_to_local(target_rect.get_center()) - preview.size * 0.5
	_undo_motion_count += 1
	_last_undo_motion_target = target_rect
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(preview, "position", target_position, 0.18)
	tween.tween_property(preview, "rotation", deg_to_rad(3.0), 0.09)
	tween.chain().tween_property(preview, "rotation", 0.0, 0.09)
	tween.finished.connect(_finish_undo_to_board.bind(preview, tile_id))


func _finish_undo_to_board(preview: Control, tile_id: String) -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	_regions.board.call("reveal_tile", tile_id)


func _play_pair_to_tray(
		incoming: Control,
		held: Control,
		source_rect: Rect2,
		target_rect: Rect2,
		held_source_rect: Rect2
) -> void:
	add_child(incoming)
	incoming.position = _global_to_local(source_rect.position)
	incoming.size = source_rect.size
	incoming.pivot_offset = incoming.size * 0.5
	incoming.z_index = 1000
	if held != null:
		add_child(held)
		held.position = _global_to_local(held_source_rect.position)
		held.size = held_source_rect.size
		held.pivot_offset = held.size * 0.5
		held.z_index = 999
	_tile_motion_count += 1
	_last_tile_motion_target = target_rect
	var target_position := _global_to_local(target_rect.get_center()) - incoming.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(incoming, "position", target_position, 0.15)
	tween.tween_property(incoming, "rotation", deg_to_rad(4.0), 0.15)
	tween.chain().tween_interval(PAIR_LANDING_HOLD_SECONDS)
	tween.finished.connect(_play_pair_collision.bind(incoming, held, target_rect, held_source_rect))


func _play_pair_collision(incoming: Control, held: Control, incoming_rect: Rect2, held_rect: Rect2) -> void:
	if held == null or not is_instance_valid(held):
		_play_pair_pop([incoming], incoming_rect.get_center())
		return
	var collision_center := (incoming_rect.get_center() + held_rect.get_center()) * 0.5
	_pair_collision_count += 1
	_last_pair_collision_position = collision_center
	var incoming_target := _global_to_local(collision_center) - incoming.size * 0.5
	var held_target := _global_to_local(collision_center) - held.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(incoming, "position", incoming_target, 0.10)
	tween.tween_property(held, "position", held_target, 0.10)
	tween.tween_property(incoming, "rotation", deg_to_rad(-5.0), 0.10)
	tween.tween_property(held, "rotation", deg_to_rad(5.0), 0.10)
	tween.tween_property(incoming, "scale", Vector2(1.08, 1.08), 0.10)
	tween.tween_property(held, "scale", Vector2(1.08, 1.08), 0.10)
	tween.finished.connect(_play_pair_pop.bind([incoming, held], collision_center))


func _play_board_pair_removal(visuals: Array) -> void:
	if visuals.is_empty():
		return
	var center := Vector2()
	for visual in visuals:
		var preview: Control = visual.preview
		var rect: Rect2 = visual.rect
		add_child(preview)
		preview.position = _global_to_local(rect.position)
		preview.size = rect.size
		preview.pivot_offset = preview.size * 0.5
		preview.z_index = 1000
		center += rect.get_center()
	center /= float(visuals.size())
	_play_pair_pop(visuals.map(func(visual: Dictionary) -> Variant: return visual.preview), center)


func _play_flipped_pair_collision(visuals: Array) -> void:
	if visuals.size() != 2:
		_play_board_pair_removal(visuals)
		return
	var collision_center: Vector2 = _regions.board.get_global_rect().get_center()
	var previews: Array = []
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_last_flipped_pair_curves.clear()
	for index in range(visuals.size()):
		var visual: Dictionary = visuals[index]
		var preview: Control = visual.preview
		var rect: Rect2 = visual.rect
		add_child(preview)
		preview.position = _global_to_local(rect.position)
		preview.size = rect.size
		preview.pivot_offset = preview.size * 0.5
		preview.z_index = 1000 + index
		previews.append(preview)
		var start := preview.position
		var finish := _global_to_local(collision_center) - preview.size * 0.5
		var path := finish - start
		var perpendicular := Vector2(-path.y, path.x).normalized()
		var bend := minf(path.length() * 0.18, 90.0)
		var bend_sign := -1.0 if index == 0 else 1.0
		var control := (start + finish) * 0.5 + perpendicular * bend * bend_sign
		_last_flipped_pair_curves.append({"start": start, "control": control, "finish": finish})
		tween.tween_method(
			_set_curve_position.bind(preview, start, control, finish),
			0.0,
			1.0,
			FLIPPED_PAIR_ARC_SECONDS
		)
		tween.tween_property(preview, "rotation", deg_to_rad(-7.0 if index == 0 else 7.0), FLIPPED_PAIR_ARC_SECONDS)
		tween.tween_property(preview, "scale", Vector2(1.08, 1.08), FLIPPED_PAIR_ARC_SECONDS)
	_flipped_pair_arc_count += 1
	tween.finished.connect(_finish_flipped_pair_collision.bind(previews, collision_center))


func _play_flipped_pair_to_tray(visuals: Array) -> void:
	if visuals.size() != 2:
		_play_board_pair_removal(visuals)
		return
	var incoming: Control = visuals[0].preview
	var held: Control = visuals[1].preview
	var incoming_rect: Rect2 = visuals[0].rect
	var held_rect: Rect2 = visuals[1].rect
	add_child(incoming)
	add_child(held)
	incoming.position = _global_to_local(incoming_rect.position)
	incoming.size = incoming_rect.size
	incoming.pivot_offset = incoming.size * 0.5
	incoming.z_index = 1001
	held.position = _global_to_local(held_rect.position)
	held.size = held_rect.size
	held.pivot_offset = held.size * 0.5
	held.z_index = 1000
	incoming.scale = Vector2(0.08, 1.0)
	_flipped_pair_tray_count += 1
	_tile_motion_count += 1
	_last_tile_motion_target = held_rect
	var reveal_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(incoming, "scale", Vector2.ONE, FLIPPED_REVEAL_SECONDS)
	reveal_tween.finished.connect(_start_flipped_pair_tray_arc.bind(incoming, held, held_rect))


func _start_flipped_pair_tray_arc(incoming: Control, held: Control, held_rect: Rect2) -> void:
	if not is_instance_valid(incoming) or not is_instance_valid(held):
		return
	var start := incoming.position
	var finish := _global_to_local(held_rect.get_center()) - incoming.size * 0.5
	var path := finish - start
	var perpendicular := Vector2(-path.y, path.x).normalized()
	var control := (start + finish) * 0.5 + perpendicular * minf(path.length() * 0.14, 72.0)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		_set_curve_position.bind(incoming, start, control, finish),
		0.0,
		1.0,
		FLIPPED_PAIR_ARC_SECONDS
	)
	tween.tween_property(incoming, "rotation", deg_to_rad(6.0), FLIPPED_PAIR_ARC_SECONDS)
	tween.tween_property(incoming, "scale", Vector2(1.08, 1.08), FLIPPED_PAIR_ARC_SECONDS)
	tween.tween_property(held, "scale", Vector2(1.06, 1.06), FLIPPED_PAIR_ARC_SECONDS)
	tween.finished.connect(_finish_flipped_pair_collision.bind([incoming, held], held_rect.get_center()))


func _set_curve_position(progress: float, preview: Control, start: Vector2, control: Vector2, finish: Vector2) -> void:
	if not is_instance_valid(preview):
		return
	var inverse := 1.0 - progress
	preview.position = inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * finish


func _finish_flipped_pair_collision(previews: Array, collision_center: Vector2) -> void:
	_pair_collision_count += 1
	_last_pair_collision_position = collision_center
	_play_pair_pop(previews, collision_center)


func _play_pair_pop(previews: Array, global_center: Vector2) -> void:
	_pair_feedback_count += 1
	_last_pair_feedback_position = global_center
	_spawn_match_burst(global_center)
	for preview in previews:
		if preview == null or not is_instance_valid(preview):
			continue
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.set_parallel(true)
		tween.tween_property(preview, "scale", Vector2(1.18, 1.18), 0.08)
		tween.tween_property(preview, "rotation", 0.0, 0.08)
		tween.chain().set_parallel(true)
		tween.tween_property(preview, "scale", Vector2(0.72, 0.72), 0.13)
		tween.tween_property(preview, "modulate:a", 0.0, 0.13)
		tween.finished.connect(preview.queue_free)


func _spawn_match_burst(global_center: Vector2) -> void:
	var burst: Control = PairMatchFxScript.new()
	add_child(burst)
	burst.position = _global_to_local(global_center) - burst.size * 0.5
	burst.z_index = 1001


func _matching_tray_index(tile_id: String) -> int:
	var tile: Variant = _game.definition.get_tile(tile_id)
	if tile == null:
		return -1
	for index in range(_game.tray.tiles.size()):
		var held: Variant = _game.tray.tiles[index]
		if held.face.family == tile.face.family and held.face.value == tile.face.value:
			return index
	return -1


func _tray_index_for_tile(tile_id: String) -> int:
	for index in range(_game.tray.tiles.size()):
		if _game.tray.tiles[index].id == tile_id:
			return index
	return -1


func _tray_contains_tile(tile_id: String) -> bool:
	for tile in _game.tray.tiles:
		if tile.id == tile_id:
			return true
	return false


func _resolved_tile_ids(transaction: Variant) -> Array[String]:
	var resolved: Array[String] = []
	for change in transaction.changes:
		if change.type == GameChangeScript.TILE_ZONE and change.after == GameStateDataScript.ZONE_RESOLVED:
			resolved.append(change.target)
	return resolved


func _capture_board_visuals(tile_ids: Array[String], force_face_up: bool = false) -> Array:
	var visuals: Array = []
	for tile_id in tile_ids:
		var preview: Control = _regions.board.call("create_tile_preview", tile_id, force_face_up)
		if preview != null:
			visuals.append({
				"preview": preview,
				"rect": _regions.board.call("tile_global_rect", tile_id),
			})
	return visuals


func _global_to_local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func _process(_delta: float) -> void:
	if _pause_started_at_ms < 0 and _game != null and _regions.has("momentum"):
		_regions.momentum.call("refresh", _playback_time_ms())
	if _android_capture_frames_remaining > 0:
		_android_capture_frames_remaining -= 1
		if _android_capture_frames_remaining == 0:
			var image := get_viewport().get_texture().get_image()
			if image != null:
				image.save_png("user://android_viewport_capture.png")


func _playback_time_ms() -> int:
	if _game_over_time_ms >= 0:
		return _game_over_time_ms
	var now: int = _pause_started_at_ms if _pause_started_at_ms >= 0 else Time.get_ticks_msec()
	return now - _game_started_at_ms - _paused_duration_ms


func _make_region(title: String, subtitle: String, color: Color) -> Panel:
	var panel := Panel.new()
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
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 12.0
	label.offset_top = 12.0
	label.offset_right = -12.0
	label.offset_bottom = -12.0

	return panel


func _apply_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var viewport_i := Vector2i(int(viewport_size.x), int(viewport_size.y))
	var orientation := "Landscape" if viewport_size.x >= viewport_size.y else "Portrait"

	for region in _regions.values():
		region.visible = true
	_debug_panel.visible = true
	if orientation == "Landscape":
		_apply_landscape_layout(viewport_size)
	elif viewport_size.y < 800.0:
		_apply_compact_portrait_layout(viewport_size)
	else:
		_apply_portrait_layout(viewport_size)

	_place_debug_panel(viewport_size, orientation)
	_place_pause_button(viewport_size)
	_regions.tray.call("set_tile_visual_size", _regions.board.call("tile_visual_size"))
	_performance_callout.call("place_over", Rect2(_regions.board.position, _regions.board.size))
	_debug_panel.call(
		"set_info",
		_rng.call("get_seed"),
		viewport_i,
		orientation,
		str(_game.definition.configuration.get("layout_id", "unknown"))
	)
	_write_android_layout_probe(orientation, viewport_size)


func _get_safe_area_insets() -> Rect2:
	if _safe_area_override.position.x >= 0.0:
		return _safe_area_override
	var safe_rect := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.screen_get_size()
	return SafeAreaScript.insets(get_viewport_rect().size, safe_rect, screen_size)


func set_safe_area_override_for_testing(edge_insets: Rect2) -> void:
	_safe_area_override = edge_insets
	_apply_layout()


func _write_android_layout_probe(orientation: String, viewport_size: Vector2) -> void:
	if OS.get_name() != "Android" or not OS.is_debug_build():
		return
	var insets := _get_safe_area_insets()
	var regions := {}
	for region_name in _regions:
		var region: Control = _regions[region_name]
		if region.visible:
			regions[region_name] = _rect_to_dict(Rect2(region.position, region.size))
	var controls := {
		"pause_button": _rect_to_dict(Rect2(_pause_button.position, _pause_button.size)),
	}
	if _debug_panel.visible:
		controls["debug_panel"] = _rect_to_dict(Rect2(_debug_panel.position, _debug_panel.size))
	var probe := {
		"orientation": orientation.to_lower(),
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"display_safe_area": _rect_to_dict(DisplayServer.get_display_safe_area()),
		"screen": {
			"width": DisplayServer.screen_get_size().x,
			"height": DisplayServer.screen_get_size().y,
		},
		"insets": {
			"left": insets.position.x,
			"top": insets.position.y,
			"right": insets.size.x,
			"bottom": insets.size.y,
		},
		"regions": regions,
		"controls": controls,
	}
	var file := FileAccess.open("user://android_layout_probe.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(probe))
	_android_capture_frames_remaining = 3


func _rect_to_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}


func _apply_landscape_layout(size: Vector2) -> void:
	var insets := _get_safe_area_insets()
	var margin := 16.0
	var gap := 12.0
	var left_margin := margin + insets.position.x
	var right_margin := margin + insets.size.x
	var usable_width := size.x - left_margin - right_margin
	var banner_offset := 0.0
	if _update_banner != null and _update_banner.visible:
		var banner_height := 44.0
		_place(_update_banner, Rect2(left_margin, margin + insets.position.y, usable_width, banner_height))
		banner_offset = banner_height + gap
	var top_start := margin + insets.position.y + banner_offset
	var bottom_limit := size.y - margin - insets.size.y
	var usable_height := bottom_limit - top_start

	var left_width: float = clampf(usable_width * 0.20, 220.0, 320.0)
	var right_width: float = clampf(usable_width * 0.22, 240.0, 360.0)
	var tray_height: float = clampf(usable_height * 0.16, 88.0, 128.0)
	var board_left: float = left_margin + left_width + gap
	var board_width: float = size.x - board_left - right_width - gap - right_margin
	var board_height: float = usable_height - tray_height - gap

	_place(_regions.momentum, Rect2(left_margin, top_start, left_width, 96.0))
	_place(_regions.consumables, Rect2(left_margin, top_start + 96.0 + gap, left_width, usable_height - 96.0 - gap))
	_place(_regions.tray, Rect2(board_left, top_start, board_width, tray_height))
	_place(_regions.board, Rect2(board_left, top_start + tray_height + gap, board_width, board_height))
	_place(_regions.character, Rect2(board_left + board_width + gap, top_start, right_width, usable_height))


func _apply_portrait_layout(size: Vector2) -> void:
	var insets := _get_safe_area_insets()
	var margin := 14.0
	var gap := 10.0
	var left_margin := margin + insets.position.x
	var right_margin := margin + insets.size.x
	var usable_width := size.x - left_margin - right_margin
	var banner_offset := 0.0
	if _update_banner != null and _update_banner.visible:
		var banner_height := 44.0
		_place(_update_banner, Rect2(left_margin, margin + insets.position.y, usable_width, banner_height))
		banner_offset = banner_height + gap
	var top_start := margin + insets.position.y + banner_offset
	var bottom_limit := size.y - margin - insets.size.y
	var usable_height := bottom_limit - top_start

	var momentum_height := 64.0
	var debug_height := 120.0
	var tray_height := 86.0
	var consumables_height := 90.0
	var tray_top: float = top_start + momentum_height + gap + debug_height + gap
	var board_top: float = tray_top + tray_height + gap
	var minimum_character_height := maxf(72.0, _regions.character.get_combined_minimum_size().y)
	var reserved_after_board := gap + consumables_height + gap + minimum_character_height
	var board_height: float = minf(
		clampf(usable_height * 0.43, 260.0, usable_height * 0.46),
		maxf(260.0, bottom_limit - board_top - reserved_after_board)
	)
	var character_top: float = board_top + board_height + gap + consumables_height + gap
	var character_height: float = bottom_limit - character_top

	_place(_regions.momentum, Rect2(left_margin, top_start, usable_width - 52.0, momentum_height))
	_place(_regions.tray, Rect2(left_margin, tray_top, usable_width, tray_height))
	_place(_regions.board, Rect2(left_margin, board_top, usable_width, board_height))
	_place(_regions.consumables, Rect2(left_margin, board_top + board_height + gap, usable_width, consumables_height))
	if character_height >= minimum_character_height:
		_place(_regions.character, Rect2(left_margin, character_top, usable_width, character_height))
	else:
		_regions.character.visible = false


func _apply_compact_portrait_layout(size: Vector2) -> void:
	var insets := _get_safe_area_insets()
	var margin := 10.0
	var gap := 8.0
	var left_margin := margin + insets.position.x
	var right_margin := margin + insets.size.x
	var usable_width := size.x - left_margin - right_margin
	var banner_offset := 0.0
	if _update_banner != null and _update_banner.visible:
		var banner_height := 40.0
		_place(_update_banner, Rect2(left_margin, margin + insets.position.y, usable_width, banner_height))
		banner_offset = banner_height + gap
	var top_start := margin + insets.position.y + banner_offset
	var bottom_limit := size.y - margin - insets.size.y
	var momentum_height := 58.0
	var tray_height := 76.0
	var consumables_height := 82.0
	var tray_top := top_start + momentum_height + gap
	var board_top := tray_top + tray_height + gap
	var board_height := bottom_limit - board_top - gap - consumables_height
	_place(_regions.momentum, Rect2(left_margin, top_start, usable_width - 50.0, momentum_height))
	_place(_regions.tray, Rect2(left_margin, tray_top, usable_width, tray_height))
	_place(_regions.board, Rect2(left_margin, board_top, usable_width, board_height))
	_place(_regions.consumables, Rect2(left_margin, board_top + board_height + gap, usable_width, consumables_height))
	_regions.character.visible = false
	_debug_panel.visible = false


func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size


func _place_debug_panel(size: Vector2, orientation: String) -> void:
	var insets := _get_safe_area_insets()
	var panel_size := Vector2(220.0, 104.0)
	var banner_y_offset := 0.0
	if _update_banner != null and _update_banner.visible:
		banner_y_offset = 54.0
	var panel_position := Vector2(
		max(12.0 + insets.position.x, size.x - insets.size.x - panel_size.x - 18.0),
		70.0 + insets.position.y + banner_y_offset
	)
	if orientation == "Portrait":
		panel_size.x = size.x - (14.0 + insets.position.x) - (14.0 + insets.size.x)
		panel_size.y = 120.0
		panel_position = Vector2(14.0 + insets.position.x, 88.0 + insets.position.y + banner_y_offset)
	_debug_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_panel.position = panel_position
	_debug_panel.size = panel_size


func _place_pause_button(size: Vector2) -> void:
	var insets := _get_safe_area_insets()
	var banner_y_offset := 0.0
	if _update_banner != null and _update_banner.visible:
		banner_y_offset = 54.0
	_pause_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pause_button.position = Vector2(size.x - 54.0 - insets.size.x, 14.0 + insets.position.y + banner_y_offset)
	_pause_button.size = Vector2(40.0, 40.0)
