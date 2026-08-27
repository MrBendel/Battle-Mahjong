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
const ArcadeCalloutPolicyScript := preload("res://scripts/presentation/arcade_callout_policy.gd")
const ArcadeCalloutTuningScript := preload("res://scripts/configuration/arcade_callout_tuning.gd")
const PauseMenuScript := preload("res://scripts/presentation/pause_menu.gd")
const EndGameMenuScript := preload("res://scripts/presentation/end_game_menu.gd")
const GameChangeScript := preload("res://scripts/simulation/game_change.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const UpdateBannerViewScript := preload("res://scripts/presentation/update_banner_view.gd")
const UpdateCheckerScript := preload("res://scripts/presentation/update_checker.gd")
const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const PORTRAIT_BACKGROUND := preload("res://game-assets/ui/portrait/background.png")
const BACKGROUND_PATCH_MARGIN := 48
const PORTRAIT_PAUSE_BUTTON := preload("res://game-assets/ui/portrait/pause_button.png")
const PORTRAIT_HUD_TOP_SCRIM := preload("res://game-assets/ui/portrait/hud_top_scrim.svg")
const PORTRAIT_REFERENCE_SIZE := Vector2(390.0, 844.0)
const PORTRAIT_HUD_SCRIM_SIZE := Vector2(390.0, 167.0)
const PORTRAIT_QUEUE_SOURCE_HEIGHT := 115.0
const PORTRAIT_QUEUE_BOTTOM_TRANSPARENT := 15.0
const PORTRAIT_QUEUE_TO_BOARD_GAP := -6.0
const PORTRAIT_BOTTOM_DOCK_OFFSET := 17.0
const PORTRAIT_BOARD_INTO_DOCK_PADDING := 8.0
const START_SEED := 92817361
const PAIR_LANDING_HOLD_SECONDS := 0.12

@export var momentum_tuning: Resource
@export var modifier_tuning: Resource
@export var arcade_callout_tuning: Resource
@export var layout_id: String = BoardLayoutCatalogScript.DEFAULT_LAYOUT_ID
@export_range(0, 48, 1) var flipped_tile_count := 12
## Uniform tray-tile scale relative to the current rendered Board tile footprint.
@export_range(0.60, 1.00, 0.01) var tray_tile_scale := 0.80
## Travel time for Board-to-Tray, flipped staging, and Undo return presentation.
@export_range(0.12, 0.40, 0.01) var tile_transfer_seconds := 0.24
## Full back-to-front or front-to-back Board flip duration.
@export_range(0.20, 0.80, 0.01) var tile_flip_seconds := 0.25
@export var show_debug_panel := false

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
var _flipped_pair_staging_count := 0
var _last_flipped_pair_stage_targets: Array[Rect2] = []
var _undo_motion_count := 0
var _last_undo_motion_target := Rect2()
var _tile_transfer_previews := {}
var _tile_transfer_tweens := {}
var _gameplay_background: NinePatchRect
var _gameplay_background_wash: ColorRect
var _portrait_hud_scrim: TextureRect
var _pause_button: Button
var _pause_menu: Control
var _end_game_menu: Control
var _pause_started_at_ms := -1
var _game_over_time_ms := -1
var _paused_duration_ms := 0
var _performance_callout: Control
var _arcade_callout_policy := ArcadeCalloutPolicyScript.new()
var _update_banner: PanelContainer
var _update_checker: Node
var _safe_area_override := Rect2(-1.0, -1.0, -1.0, -1.0)
var _android_capture_frames_remaining := 0
var _active_screen_touches: Dictionary = {}
var _application_backgrounded := false
var _lifecycle_input_suspended := false
var _input_recovery_count := 0

func _ready() -> void:
	_build_shell()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED \
			or what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_application_backgrounded()
	elif what == MainLoop.NOTIFICATION_APPLICATION_RESUMED \
			or what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_application_foregrounded()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_screen_touches[event.index] = event.position
		else:
			_active_screen_touches.erase(event.index)
	if _lifecycle_input_suspended and (event is InputEventScreenTouch \
			or event is InputEventMouseButton or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


func _build_shell() -> void:
	_build_gameplay_background()
	_game = _create_game()
	_tile_skin = TileSkinScript.new()
	_game_started_at_ms = Time.get_ticks_msec()
	_regions.board = BoardViewScript.new(_game, _tile_skin)
	_regions.board.call("set_flip_duration", tile_flip_seconds)
	_regions.momentum = MomentumViewScript.new(_game)
	_regions.tray = TrayViewScript.new(_game, _tile_skin)
	_regions.consumables = ConsumablesViewScript.new(_game)
	_regions.character = _make_region("Character / FX", "decorative reaction space", Color(0.17, 0.11, 0.13, 1.0))

	for region in _regions.values():
		add_child(region)
	_performance_callout = PerformanceCalloutScript.new()
	add_child(_performance_callout)
	if arcade_callout_tuning == null or arcade_callout_tuning.get_script() != ArcadeCalloutTuningScript:
		push_error("No valid ArcadeCalloutTuning resource assigned.")
	elif not arcade_callout_tuning.call("validation_errors").is_empty():
		push_error("Invalid ArcadeCalloutTuning resource: %s" % " ".join(arcade_callout_tuning.call("validation_errors")))

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

	_debug_panel = DebugPanelScript.new()
	add_child(_debug_panel)
	_build_pause_menu()
	_build_end_game_menu()

	_update_checker = UpdateCheckerScript.new()
	_update_checker.name = "UpdateChecker"
	_update_checker.update_available.connect(_on_update_available)
	add_child(_update_checker)
	_update_checker.call("check_for_updates")


func _on_update_available(version_name: String, store_url: String, mandatory: bool) -> void:
	_update_banner.call("show_update", version_name, store_url, mandatory)
	_apply_layout()


func _on_update_requested() -> void:
	if _update_checker != null and _update_checker.has_method("start_in_app_update"):
		_update_checker.call("start_in_app_update", false)



func _build_pause_menu() -> void:
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = ""
	_pause_button.icon = PORTRAIT_PAUSE_BUTTON
	_pause_button.expand_icon = true
	_pause_button.tooltip_text = "Pause"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.z_index = 1500
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_pause_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
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
	_gameplay_background = NinePatchRect.new()
	_gameplay_background.name = "GameplayBackground"
	_gameplay_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameplay_background.texture = PORTRAIT_BACKGROUND
	_gameplay_background.set_patch_margin(SIDE_LEFT, BACKGROUND_PATCH_MARGIN)
	_gameplay_background.set_patch_margin(SIDE_TOP, BACKGROUND_PATCH_MARGIN)
	_gameplay_background.set_patch_margin(SIDE_RIGHT, BACKGROUND_PATCH_MARGIN)
	_gameplay_background.set_patch_margin(SIDE_BOTTOM, BACKGROUND_PATCH_MARGIN)
	_gameplay_background.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_gameplay_background.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_gameplay_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gameplay_background)

	_gameplay_background_wash = ColorRect.new()
	_gameplay_background_wash.name = "GameplayBackgroundWash"
	_gameplay_background_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameplay_background_wash.color = Color(0.01, 0.025, 0.025, 0.24)
	_gameplay_background_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gameplay_background_wash)

	_portrait_hud_scrim = TextureRect.new()
	_portrait_hud_scrim.name = "PortraitHudScrim"
	_portrait_hud_scrim.texture = PORTRAIT_HUD_TOP_SCRIM
	_portrait_hud_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_hud_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait_hud_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_hud_scrim)


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
	if _gameplay_input_blocked():
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
			_play_transaction_auto_reveals(transaction)
			_play_board_pair_removal(removal_visuals)
			return
	else:
		var face_down: bool = _game.board.call("is_tile_face_down", tile_id)
		var flipped_candidate: Dictionary = _game.call("flipped_match_candidate", tile_id)
		var legacy_direct_flipped_match: bool = _game.definition.rules_version < 12 \
			and not flipped_candidate.is_empty()
		if face_down or legacy_direct_flipped_match:
			var direct_visuals := _capture_board_visuals([tile_id], face_down)
			var direct_matching_zone := ""
			var direct_target_rect := Rect2()
			if legacy_direct_flipped_match:
				var matching_tile_id := str(flipped_candidate.tile_id)
				direct_matching_zone = str(flipped_candidate.zone)
				if direct_matching_zone == GameStateDataScript.ZONE_BOARD:
					direct_visuals.append_array(_capture_board_visuals([matching_tile_id]))
				else:
					direct_target_rect = _regions.tray.call("slot_global_rect", mini(_game.tray.tiles.size(), 3))
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
			var direct_transaction: Variant = _game.call("last_transaction")
			_play_transaction_auto_reveals(direct_transaction)
			if result == GameStateScript.TILE_REVEALED:
				for visual in direct_visuals:
					visual.preview.queue_free()
				_regions.board.call("play_flip", tile_id, true)
			elif result == GameStateScript.FLIPPED_PAIR_RESOLVED:
				if direct_matching_zone == GameStateDataScript.ZONE_TRAY:
					_play_flipped_match_to_tray(direct_visuals, direct_target_rect, face_down)
				else:
					_play_flipped_pair_via_open_slots(direct_visuals, face_down)
				_regions.momentum.call("play_pair_feedback", int(direct_transaction.telemetry.resulting_multiplier))
				_play_transaction_callout(direct_transaction)
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
	var selection_transaction: Variant = _game.call("last_transaction")
	_play_transaction_auto_reveals(selection_transaction)
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
		_play_transaction_callout(transaction)


func _play_transaction_callout(transaction: Variant) -> void:
	if arcade_callout_tuning == null:
		return
	var score_after := int(_game.call("current_snapshot").score)
	var alert: Dictionary = _arcade_callout_policy.call(
		"choose_for_pair",
		transaction.telemetry,
		score_after,
		arcade_callout_tuning
	)
	if not alert.is_empty():
		_performance_callout.call("play_alert", alert)


func _active_revealed_flipped_tile_ids() -> Array[String]:
	var ids: Array[String] = []
	for tile_id in _game.call("current_snapshot").revealed_flipped_tile_ids:
		if _game.board.call("is_tile_revealed_flipped", tile_id):
			ids.append(tile_id)
	return ids


func _play_flip_backs(previously_revealed_ids: Array[String]) -> void:
	for tile_id in previously_revealed_ids:
		if _game.board.call("is_tile_face_down", tile_id):
			_regions.board.call("play_flip", tile_id, false)


func _on_locked_tile_tapped(tile_id: String) -> void:
	if _gameplay_input_blocked():
		return
	_game.call("break_combo_for_locked_tile", tile_id, _playback_time_ms())
	_regions.momentum.call("refresh", _playback_time_ms())


func _on_undo_requested() -> void:
	if _lifecycle_input_suspended or _application_backgrounded or _pause_started_at_ms >= 0:
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
	if _gameplay_input_blocked():
		return
	var result: String = _game.call("request_hint", _playback_time_ms())
	if result == GameStateScript.NO_HINT_AVAILABLE:
		_regions.consumables.call("show_notice", "No pair is available. Try another move or Shuffle.")
	else:
		_regions.consumables.call("show_notice", "Suggested pair highlighted.")
	_refresh_game_views()


func _on_delete_pair_requested() -> void:
	if _gameplay_input_blocked():
		return
	_delete_pair_armed = true
	_regions.board.call("set_delete_pair_armed", true)
	_regions.consumables.call("show_notice", "Choose any visible tile to delete its visible matching pair.")


func _on_shuffle_requested() -> void:
	if _gameplay_input_blocked():
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


func _on_application_backgrounded() -> void:
	if _application_backgrounded:
		return
	_application_backgrounded = true
	_lifecycle_input_suspended = true
	_cancel_active_pointer_events()
	Input.flush_buffered_events()
	_clear_transient_input_state()
	_rebuild_interactive_controls()
	if _pause_started_at_ms < 0 and _game_over_time_ms < 0 \
			and _game != null and _game.status == GameStateScript.PLAYING:
		_on_pause_requested()


func _on_application_foregrounded() -> void:
	if not _application_backgrounded:
		return
	_application_backgrounded = false
	call_deferred("_recover_input_after_foreground")


func _recover_input_after_foreground() -> void:
	_cancel_active_pointer_events()
	Input.flush_buffered_events()
	_clear_transient_input_state()
	_rebuild_interactive_controls()
	_apply_layout()
	await get_tree().process_frame
	_apply_layout()
	_lifecycle_input_suspended = false
	_input_recovery_count += 1


func _clear_transient_input_state() -> void:
	_delete_pair_armed = false
	if _regions.has("board"):
		_regions.board.call("set_delete_pair_armed", false)


func _rebuild_interactive_controls() -> void:
	if _regions.has("board"):
		_regions.board.call("reset_input_state")
	if _regions.has("consumables"):
		_regions.consumables.call("reset_input_state")


func _gameplay_input_blocked() -> bool:
	return _lifecycle_input_suspended or _application_backgrounded \
		or _pause_started_at_ms >= 0 or _game_over_time_ms >= 0 \
		or _game == null or _game.status != GameStateScript.PLAYING


func _cancel_active_pointer_events() -> void:
	var touches := _active_screen_touches.duplicate()
	_active_screen_touches.clear()
	for index in touches:
		var cancellation := InputEventScreenTouch.new()
		cancellation.index = int(index)
		cancellation.position = touches[index]
		cancellation.pressed = false
		cancellation.canceled = true
		Input.parse_input_event(cancellation)

	# Android can emulate a mouse press from a touch whose release was lost while
	# suspending. Release it outside the viewport so no control treats it as a tap.
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.position = Vector2(-10000.0, -10000.0)
	mouse_release.global_position = mouse_release.position
	mouse_release.pressed = false
	Input.parse_input_event(mouse_release)


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
	tween.tween_property(preview, "position", target_position, tile_transfer_seconds)
	tween.tween_property(preview, "scale", _preview_scale_for_rect(preview, target_rect), tile_transfer_seconds)
	tween.finished.connect(_finish_tile_to_tray.bind(preview, tile_id))


func _finish_tile_to_tray(preview: Control, tile_id: String) -> void:
	_tile_transfer_previews.erase(tile_id)
	_tile_transfer_tweens.erase(tile_id)
	_regions.tray.call("reveal_tile", tile_id)
	if is_instance_valid(preview):
		preview.queue_free()


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
	tween.tween_property(preview, "position", target_position, tile_transfer_seconds)
	tween.tween_property(preview, "scale", _preview_scale_for_rect(preview, target_rect), tile_transfer_seconds)
	var rotation_half := tile_transfer_seconds * 0.5
	var rotation_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	rotation_tween.tween_property(preview, "rotation", deg_to_rad(3.0), rotation_half)
	rotation_tween.tween_property(preview, "rotation", 0.0, rotation_half)
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
	_prepare_pair_to_tray(incoming, held, source_rect, held_source_rect)
	_start_pair_to_tray_motion(incoming, held, target_rect, held_source_rect)


func _prepare_pair_to_tray(incoming: Control, held: Control, source_rect: Rect2, held_source_rect: Rect2) -> void:
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


func _start_pair_to_tray_motion(incoming: Control, held: Control, target_rect: Rect2, held_source_rect: Rect2) -> void:
	if not is_instance_valid(incoming):
		return
	_tile_motion_count += 1
	_last_tile_motion_target = target_rect
	var target_position := _global_to_local(target_rect.get_center()) - incoming.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(incoming, "position", target_position, tile_transfer_seconds)
	tween.tween_property(incoming, "scale", _preview_scale_for_rect(incoming, target_rect), tile_transfer_seconds)
	tween.tween_property(incoming, "rotation", deg_to_rad(4.0), tile_transfer_seconds)
	tween.chain().tween_interval(PAIR_LANDING_HOLD_SECONDS)
	tween.finished.connect(_play_pair_collision.bind(incoming, held, target_rect, held_source_rect))


func _play_flipped_match_to_tray(visuals: Array, target_rect: Rect2, reveal_incoming: bool) -> void:
	if visuals.size() != 2:
		_play_board_pair_removal(visuals)
		return
	var incoming: Control = visuals[0].preview
	var held: Control = visuals[1].preview
	var source_rect: Rect2 = visuals[0].rect
	var held_source_rect: Rect2 = visuals[1].rect
	_prepare_pair_to_tray(incoming, held, source_rect, held_source_rect)
	if not reveal_incoming:
		_start_pair_to_tray_motion(incoming, held, target_rect, held_source_rect)
		return
	incoming.scale = Vector2(0.08, 1.0)
	var reveal_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(incoming, "scale", Vector2.ONE, tile_flip_seconds * 0.5)
	reveal_tween.finished.connect(
		_start_pair_to_tray_motion.bind(incoming, held, target_rect, held_source_rect)
	)


func _play_pair_collision(incoming: Control, held: Control, incoming_rect: Rect2, held_rect: Rect2) -> void:
	if held == null or not is_instance_valid(held):
		_play_pair_pop([incoming], incoming_rect.get_center())
		return
	var collision_center := (incoming_rect.get_center() + held_rect.get_center()) * 0.5
	_pair_collision_count += 1
	_last_pair_collision_position = collision_center
	var incoming_target := _global_to_local(collision_center) - incoming.size * 0.5
	var held_target := _global_to_local(collision_center) - held.size * 0.5
	var incoming_collision_scale := incoming.scale * 1.08
	var held_collision_scale := held.scale * 1.08
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(incoming, "position", incoming_target, 0.10)
	tween.tween_property(held, "position", held_target, 0.10)
	tween.tween_property(incoming, "rotation", deg_to_rad(-5.0), 0.10)
	tween.tween_property(held, "rotation", deg_to_rad(5.0), 0.10)
	tween.tween_property(incoming, "scale", incoming_collision_scale, 0.10)
	tween.tween_property(held, "scale", held_collision_scale, 0.10)
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


func _play_flipped_pair_via_open_slots(visuals: Array, reveal_incoming: bool = false) -> void:
	if visuals.size() != 2:
		_play_board_pair_removal(visuals)
		return
	var previews: Array = []
	var targets := _flipped_pair_staging_rects()
	_last_flipped_pair_stage_targets.assign(targets)
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
	_flipped_pair_staging_count += 1
	_tile_motion_count += 2
	_last_tile_motion_target = targets[1]
	if reveal_incoming:
		previews[0].scale = Vector2(0.08, 1.0)
		var reveal_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(previews[0], "scale", Vector2.ONE, tile_flip_seconds * 0.5)
		reveal_tween.finished.connect(_stage_flipped_pair_in_tray.bind(previews, targets))
	else:
		_stage_flipped_pair_in_tray(previews, targets)


func _flipped_pair_staging_rects() -> Array[Rect2]:
	var first_slot := mini(_game.tray.tiles.size(), 2)
	return [
		_regions.tray.call("slot_global_rect", first_slot),
		_regions.tray.call("slot_global_rect", first_slot + 1),
	]


func _stage_flipped_pair_in_tray(previews: Array, targets: Array[Rect2]) -> void:
	if previews.size() != 2 or not is_instance_valid(previews[0]) or not is_instance_valid(previews[1]):
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	for index in previews.size():
		var preview: Control = previews[index]
		var target_position := _global_to_local(targets[index].get_center()) - preview.size * 0.5
		tween.tween_property(preview, "position", target_position, tile_transfer_seconds)
		tween.tween_property(preview, "scale", _preview_scale_for_rect(preview, targets[index]), tile_transfer_seconds)
		tween.tween_property(preview, "rotation", deg_to_rad(-3.0 if index == 0 else 3.0), tile_transfer_seconds)
	tween.chain().tween_interval(PAIR_LANDING_HOLD_SECONDS)
	tween.finished.connect(_play_pair_collision.bind(previews[0], previews[1], targets[0], targets[1]))


func _play_transaction_auto_reveals(transaction: Variant) -> void:
	if transaction == null:
		return
	for tile_id in transaction.telemetry.get("auto_revealed_tile_ids", []):
		_regions.board.call("play_flip", str(tile_id))


func _play_pair_pop(previews: Array, global_center: Vector2) -> void:
	_pair_feedback_count += 1
	_last_pair_feedback_position = global_center
	_spawn_match_burst(global_center)
	for preview in previews:
		if preview == null or not is_instance_valid(preview):
			continue
		var landed_scale: Vector2 = preview.scale
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.set_parallel(true)
		tween.tween_property(preview, "scale", landed_scale * 1.09, 0.08)
		tween.tween_property(preview, "rotation", 0.0, 0.08)
		tween.chain().set_parallel(true)
		tween.tween_property(preview, "scale", landed_scale * 0.67, 0.13)
		tween.tween_property(preview, "modulate:a", 0.0, 0.13)
		tween.finished.connect(preview.queue_free)


func _preview_scale_for_rect(preview: Control, target_rect: Rect2) -> Vector2:
	if preview.size.x <= 0.0 or preview.size.y <= 0.0:
		return Vector2.ONE
	return target_rect.size / preview.size


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
	_tile_skin.call("set_orientation", orientation.to_lower())
	var portrait := orientation == "Portrait"
	_gameplay_background_wash.visible = false
	_portrait_hud_scrim.visible = portrait
	_regions.momentum.call("set_portrait_style", portrait)
	_regions.tray.call("set_portrait_style", portrait)
	_regions.consumables.call("set_horizontal_dock", portrait)
	_regions.board.call("set_compact_mode", portrait)

	for region in _regions.values():
		region.visible = true
	if _debug_panel != null:
		_debug_panel.visible = show_debug_panel
	if orientation == "Landscape":
		_apply_landscape_layout(viewport_size)
	elif viewport_size.y < 800.0:
		_apply_compact_portrait_layout(viewport_size)
	else:
		_apply_portrait_layout(viewport_size)
	_regions.board.call("refresh")
	var tile_visual_size: Vector2 = _regions.board.call("tile_visual_size")
	var tray_visual_size := tile_visual_size * tray_tile_scale
	var required_tray_height := float(_regions.tray.call("minimum_height_for_tile", tray_visual_size))
	var required_tray_width := float(_regions.tray.call("minimum_width_for_tile", tray_visual_size))
	_reflow_for_tray_clearance(orientation, required_tray_height, required_tray_width)

	if _debug_panel.visible:
		_place_debug_panel(viewport_size, orientation)
	_place_pause_button(viewport_size)
	_regions.board.call("refresh")
	_regions.tray.call("set_tile_visual_size", _regions.board.call("tile_visual_size") * tray_tile_scale)
	_regions.tray.call("refresh")
	_performance_callout.call("place_over", Rect2(_regions.board.position, _regions.board.size))
	_debug_panel.call(
		"set_info",
		_rng.call("get_seed"),
		viewport_i,
		orientation,
		str(_game.definition.configuration.get("layout_id", "unknown"))
	)
	_write_android_layout_probe(orientation, viewport_size)


func _reflow_for_tray_clearance(
	orientation: String,
	required_height: float,
	required_width: float
) -> void:
	var tray: Control = _regions.tray
	var board: Control = _regions.board
	if required_width > tray.size.x:
		var expanded_width := minf(required_width, board.size.x)
		tray.position.x = board.position.x + (board.size.x - expanded_width) * 0.5
		tray.size.x = expanded_width
	var board_bottom := board.position.y + board.size.y
	if orientation == "Portrait":
		var queue_scale := required_height / PORTRAIT_QUEUE_SOURCE_HEIGHT
		tray.size.y = required_height
		var board_top := tray.position.y + required_height \
			- PORTRAIT_QUEUE_BOTTOM_TRANSPARENT * queue_scale \
			+ PORTRAIT_QUEUE_TO_BOARD_GAP * queue_scale
		board.position.y = board_top
		board.size.y = maxf(1.0, board_bottom - board_top)
		return
	if required_height <= tray.size.y:
		return
	var gap := 10.0 if orientation == "Landscape" or get_viewport_rect().size.y >= 800.0 else 7.0
	tray.size.y = required_height
	if orientation == "Landscape":
		_regions.momentum.size.y = required_height
	var board_top := tray.position.y + tray.size.y + gap
	board.position.y = board_top
	board.size.y = maxf(1.0, board_bottom - board_top)


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
	var content := SafeAreaScript.content_rect(size, insets)
	var margin := 12.0
	var gap := 10.0
	var safe_rect := Rect2(content.position + Vector2(margin, margin), content.size - Vector2(margin * 2.0, margin * 2.0))
	var banner_offset := 0.0
	if _update_banner != null and _update_banner.visible:
		var banner_height := 44.0
		_place(_update_banner, Rect2(safe_rect.position, Vector2(safe_rect.size.x, banner_height)))
		banner_offset = banner_height + gap
	var top_start := safe_rect.position.y + banner_offset
	var bottom_limit := safe_rect.end.y
	var usable_height := bottom_limit - top_start
	var rail_width := clampf(safe_rect.size.x * 0.18, 120.0, 240.0)
	var top_height := clampf(usable_height * 0.15, 76.0, 104.0)
	var board_left := safe_rect.position.x + rail_width + gap
	var board_width := safe_rect.size.x - (rail_width + gap) * 2.0
	var board_top := top_start + top_height + gap
	var tray_width := minf(board_width, 430.0)

	_place(_regions.momentum, Rect2(safe_rect.position.x, top_start, rail_width, top_height))
	_place(_regions.tray, Rect2(board_left + (board_width - tray_width) * 0.5, top_start, tray_width, top_height))
	_place(_regions.board, Rect2(board_left, board_top, board_width, bottom_limit - board_top))
	_place(_regions.consumables, safe_rect)
	var action_gap := 8.0
	var action_height := clampf((usable_height - top_height - gap - action_gap) * 0.18, 54.0, 72.0)
	var action_bottom := safe_rect.size.y
	_regions.consumables.call("set_action_rects", {
		"hint": Rect2(0.0, action_bottom - action_height * 2.0 - action_gap, rail_width, action_height),
		"delete_pair": Rect2(0.0, action_bottom - action_height, rail_width, action_height),
		"shuffle": Rect2(safe_rect.size.x - rail_width, action_bottom - action_height * 2.0 - action_gap, rail_width, action_height),
		"undo": Rect2(safe_rect.size.x - rail_width, action_bottom - action_height, rail_width, action_height),
	})
	_regions.character.visible = false


func _apply_portrait_layout(size: Vector2) -> void:
	_apply_figma_portrait_layout(size, false)


func _apply_compact_portrait_layout(size: Vector2) -> void:
	_apply_figma_portrait_layout(size, true)
	_debug_panel.visible = false


func _apply_figma_portrait_layout(size: Vector2, compact: bool) -> void:
	var insets := _get_safe_area_insets()
	var content := SafeAreaScript.content_rect(size, insets)
	var scale := _portrait_reference_scale(content)
	var margin := (8.0 if compact else 12.0) * scale
	var usable_width := maxf(1.0, content.size.x - margin * 2.0)
	var banner_offset := 0.0
	if _update_banner != null and _update_banner.visible:
		var banner_height := 40.0 * scale
		_place(_update_banner, Rect2(content.position.x + margin, content.position.y, usable_width, banner_height))
		banner_offset = banner_height + 6.0 * scale
	var top_start := content.position.y + banner_offset
	var momentum_height := 81.0 * scale
	var tray_height := 118.564 * scale
	var consumables_height := 149.2696 * scale
	var tray_top := top_start + momentum_height
	var board_top := tray_top + tray_height
	var consumables_top := content.end.y - consumables_height
	var board_bottom := consumables_top + (PORTRAIT_BOTTOM_DOCK_OFFSET + PORTRAIT_BOARD_INTO_DOCK_PADDING) * scale
	var board_height := maxf(1.0, board_bottom - board_top)
	_place(_regions.momentum, Rect2(content.position.x, top_start, content.size.x, momentum_height))
	_place(_regions.tray, Rect2(content.position.x + margin, tray_top, usable_width, tray_height))
	_place(_regions.board, Rect2(content.position.x + margin, board_top, usable_width, board_height))
	_place(_regions.consumables, Rect2(content.position.x + margin, consumables_top, usable_width, consumables_height))
	var scrim_height := size.x * PORTRAIT_HUD_SCRIM_SIZE.y / PORTRAIT_HUD_SCRIM_SIZE.x
	_place(_portrait_hud_scrim, Rect2(0.0, 0.0, size.x, scrim_height))
	_regions.consumables.call("clear_action_rects")
	_regions.character.visible = false


func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size


func _portrait_reference_scale(content: Rect2) -> float:
	return maxf(0.01, minf(
		content.size.x / PORTRAIT_REFERENCE_SIZE.x,
		content.size.y / PORTRAIT_REFERENCE_SIZE.y
	))


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
	if size.x < size.y:
		var content := SafeAreaScript.content_rect(size, insets)
		var scale := _portrait_reference_scale(content)
		var button_size := 48.0 * scale
		_pause_button.position = Vector2(content.end.x - button_size - 6.0 * scale, content.position.y + 12.0 * scale + banner_y_offset)
		_pause_button.size = Vector2(button_size, button_size)
	else:
		_pause_button.position = Vector2(size.x - 54.0 - insets.size.x, 14.0 + insets.position.y + banner_y_offset)
		_pause_button.size = Vector2(40.0, 40.0)
