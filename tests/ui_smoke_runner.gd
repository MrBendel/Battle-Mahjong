extends SceneTree

const PairDifficultyRewardsScript := preload("res://scripts/simulation/pair_difficulty_rewards.gd")
const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_size := Vector2i(720, 1280)
	if OS.get_cmdline_user_args().has("--small-phone"):
		requested_size = Vector2i(375, 667)
	elif OS.get_cmdline_user_args().has("--landscape"):
		requested_size = Vector2i(1280, 720)
	elif OS.get_cmdline_user_args().has("--portrait"):
		requested_size = Vector2i(430, 932)
	root.size = requested_size
	var shell: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(shell)
	await process_frame
	var banner_view: Control = shell.get("_update_banner")
	if banner_view != null:
		banner_view.visible = false
		await process_frame

	_check_equal(
		DisplayServer.SCREEN_SENSOR,
		ProjectSettings.get_setting("display/window/handheld/orientation"),
		"Android export declares sensor orientation"
	)
	var projected_insets := SafeAreaScript.insets(
		Vector2(1200.0, 600.0),
		Rect2i(100, 40, 960, 520),
		Vector2i(1200, 600)
	)
	_check_equal(Rect2(100.0, 40.0, 140.0, 40.0), projected_insets, "safe-area projection preserves asymmetric edge insets")
	if OS.get_cmdline_user_args().has("--safe-area"):
		var test_insets := Rect2(72.0, 24.0, 44.0, 28.0) if requested_size.x > requested_size.y \
			else Rect2(28.0, 54.0, 46.0, 30.0)
		shell.call("set_safe_area_override_for_testing", test_insets)
		await process_frame
	var gameplay_background: TextureRect = shell.get("_gameplay_background")
	_check(gameplay_background != null and gameplay_background.texture != null, "gameplay shell renders the M7 background asset")
	_check_equal(
		TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		gameplay_background.stretch_mode,
		"gameplay background covers responsive viewports without distortion"
	)
	var tuning: Resource = shell.get("momentum_tuning")
	var modifier_tuning: Resource = shell.get("modifier_tuning")
	_check(tuning != null, "main scene exposes a MomentumTuning resource")
	_check(tuning.call("validation_errors").is_empty(), "main scene MomentumTuning resource validates")
	_check(modifier_tuning != null, "main scene exposes a ModifierTuning resource")
	_check(modifier_tuning.call("validation_errors").is_empty(), "main scene ModifierTuning resource validates")
	var live_game: Variant = shell.get("_game")
	_check_equal(shell.get("layout_id"), live_game.definition.configuration.layout_id, "main scene selects its exported layout id")
	_check_equal(
		int(shell.get("flipped_tile_count")),
		live_game.definition.flipped_tile_ids.size(),
		"main scene copies Inspector flipped-tile count into game definition"
	)
	_check_equal(
		int(tuning.get("pair_gain")),
		int(live_game.definition.configuration.momentum_pair_gain),
		"main scene copies Inspector tuning into game definition"
	)
	_check_equal(
		int(tuning.get("selection_gain")),
		int(live_game.definition.configuration.momentum_selection_gain),
		"main scene copies selection gain into game definition"
	)
	_check_equal(
		int(modifier_tuning.get("loadout_capacity")),
		int(live_game.definition.configuration.modifier_loadout_capacity),
		"main scene copies modifier tuning into game definition"
	)
	var attached_tile_id: String = str(live_game.definition.modifier_attachments.keys()[0])
	var attached_button: Button = shell.get("_regions").board.get("_tile_buttons")[attached_tile_id]
	var modifier_label: Label = attached_button.get_node("Modifier")
	_check("×" in modifier_label.text and modifier_label.visible, "starter modifier remains a separate visible tile overlay")
	var revealable_tile_id := ""
	for tile in live_game.board.call("revealable_tiles"):
		revealable_tile_id = tile.id
		break
	_check(not revealable_tile_id.is_empty(), "reference game starts with an accessible face-down tile")
	if not revealable_tile_id.is_empty():
		var reveal_button: Button = shell.get("_regions").board.get("_tile_buttons")[revealable_tile_id]
		var reveal_art: TextureRect = reveal_button.get_node("FaceArt")
		_check(bool(reveal_button.get_meta("face_down")), "face-down presentation records hidden state")
		_check(not reveal_art.visible and reveal_button.text == "?", "face-down presentation hides tile identity")
		var tray_before_reveal: int = live_game.tray.tiles.size()
		var motion_before_reveal: int = shell.get("_tile_motion_count")
		shell.call("_on_tile_selected", revealable_tile_id)
		_check(live_game.board.call("is_tile_revealed_flipped", revealable_tile_id), "shell commits face-down reveal transaction")
		_check_equal(tray_before_reveal, live_game.tray.tiles.size(), "shell reveal leaves tray occupancy unchanged")
		_check_equal(motion_before_reveal, shell.get("_tile_motion_count"), "shell reveal does not start tray transfer")
		_check(reveal_art.visible and reveal_button.text.is_empty(), "revealed tile displays its face in place")
		_check_equal(Color.WHITE, reveal_button.modulate, "revealed flipped tile remains bright and readable")
		_check(not bool(reveal_button.get_meta("targetable")), "revealed flipped tile remains pinned to the board")
		var nonmatching_tile_id := ""
		var revealed_face: Variant = live_game.definition.get_tile(revealable_tile_id).face
		for candidate in live_game.board.call("selectable_tiles"):
			if not candidate.face.equals(revealed_face):
				nonmatching_tile_id = candidate.id
				break
		_check(not nonmatching_tile_id.is_empty(), "reference game exposes an ordinary non-match for flip-back validation")
		if not nonmatching_tile_id.is_empty():
			shell.call("_on_tile_selected", nonmatching_tile_id)
			_check(live_game.board.call("is_tile_face_down", revealable_tile_id), "ordinary non-match re-hides the revealed tile")
			_check(not reveal_art.visible and reveal_button.text == "?", "flip-back presentation restores the tile back")
			shell.call("_on_restart_requested")
			live_game = shell.get("_game")
	var arc_visuals := []
	for rect in [Rect2(Vector2(32.0, 120.0), Vector2(42.0, 54.0)), Rect2(Vector2(root.size.x - 74.0, root.size.y - 180.0), Vector2(42.0, 54.0))]:
		var preview := Panel.new()
		arc_visuals.append({"preview": preview, "rect": rect})
	var arc_count_before: int = shell.get("_flipped_pair_arc_count")
	var arc_collision_before: int = shell.get("_pair_collision_count")
	var arc_feedback_before: int = shell.get("_pair_feedback_count")
	shell.call("_play_flipped_pair_collision", arc_visuals)
	_check_equal(arc_count_before + 1, shell.get("_flipped_pair_arc_count"), "flipped pair starts one center-arc presentation")
	var curves: Array = shell.get("_last_flipped_pair_curves")
	_check_equal(2, curves.size(), "flipped pair records one curve per tile")
	for curve in curves:
		var straight_midpoint: Vector2 = (curve.start + curve.finish) * 0.5
		_check(curve.control.distance_to(straight_midpoint) > 1.0, "flipped tile path bends away from a straight center line")
	await create_timer(0.18).timeout
	_check_equal(arc_collision_before, shell.get("_pair_collision_count"), "flipped pair remains in flight before center collision")
	await create_timer(0.24).timeout
	_check_equal(arc_collision_before + 1, shell.get("_pair_collision_count"), "flipped pair collides after curved travel")
	_check_equal(shell.get("_regions").board.get_global_rect().get_center(), shell.get("_last_pair_collision_position"), "flipped pair collision targets board center")
	_check_equal(arc_feedback_before + 1, shell.get("_pair_feedback_count"), "flipped center collision triggers the shared removal burst")
	await create_timer(0.24).timeout
	var tray_match_rect: Rect2 = shell.get("_regions").tray.call("slot_global_rect", 0)
	var tray_visuals := [
		{"preview": Panel.new(), "rect": Rect2(Vector2(root.size.x * 0.5, root.size.y * 0.7), Vector2(42.0, 54.0))},
		{"preview": Panel.new(), "rect": tray_match_rect},
	]
	var tray_arc_before: int = shell.get("_flipped_pair_tray_count")
	var tray_collision_before: int = shell.get("_pair_collision_count")
	shell.call("_play_flipped_pair_to_tray", tray_visuals)
	_check_equal(tray_arc_before + 1, shell.get("_flipped_pair_tray_count"), "flipped-to-tray match starts its dedicated upward arc")
	_check_equal(tray_match_rect, shell.get("_last_tile_motion_target"), "flipped-to-tray arc targets the held tile rather than an open slot")
	var tray_incoming: Control = tray_visuals[0].preview
	var tray_start: Vector2 = tray_incoming.position
	_check(tray_incoming.scale.x < 0.1, "matching flipped tile begins its face reveal edge-on")
	await create_timer(0.10).timeout
	_check_equal(tray_start, tray_incoming.position, "matching flipped tile reveals in place before tray motion")
	_check(tray_incoming.scale.x > 0.1, "matching flipped tile face becomes visible during the reveal beat")
	await create_timer(0.10).timeout
	_check_equal(tray_collision_before, shell.get("_pair_collision_count"), "flipped tile begins tray travel only after revealing")
	await create_timer(0.34).timeout
	_check_equal(tray_collision_before + 1, shell.get("_pair_collision_count"), "flipped tile collides with its held tray mate")
	_check_equal(tray_match_rect.get_center(), shell.get("_last_pair_collision_position"), "flipped-to-tray collision uses the held tile position")
	await create_timer(0.24).timeout
	var representative_button: Button = null
	for tile in live_game.board.tiles:
		if tile.face.logical_id() == "reference_01":
			representative_button = shell.get("_regions").board.get("_tile_buttons")[tile.id]
			break
	_check(representative_button != null, "reference game contains the representative Bamboo face")
	if representative_button != null:
		var face_art: TextureRect = representative_button.get_node("FaceArt")
		_check(face_art.texture != null and face_art.visible, "representative Default face renders as a layered runtime asset")
	var selectable_tile_id := ""
	for tile in live_game.board.call("selectable_tiles"):
		selectable_tile_id = tile.id
		break
	_check(not selectable_tile_id.is_empty(), "reference game starts with an animatable selectable tile")
	if not selectable_tile_id.is_empty():
		var original_board_rect: Rect2 = shell.get("_regions").board.call("tile_global_rect", selectable_tile_id)
		var expected_target: Rect2 = shell.get("_regions").tray.call("slot_global_rect", 0)
		shell.call("_on_tile_selected", selectable_tile_id)
		_check_equal(1, shell.get("_tile_motion_count"), "ordinary selection starts one board-to-tray animation")
		_check_equal(
			int(tuning.get("selection_gain")),
			live_game.call("current_snapshot").momentum_units,
			"ordinary selection immediately bumps live Momentum"
		)
		_check_equal(expected_target, shell.get("_last_tile_motion_target"), "selection animation targets the next tray slot")
		_check_equal(1, live_game.tray.tiles.size(), "ordinary transfer commits tray occupancy immediately")
		var first_slot_art: TextureRect = shell.get("_regions").tray.get("_slot_art")[0]
		_check(not first_slot_art.visible, "destination tile stays visually suppressed during transfer")
		await create_timer(0.32).timeout
		_check(first_slot_art.visible and first_slot_art.texture != null, "arrival reveals the selected face artwork")
		var landed_undo_before: int = shell.get("_undo_motion_count")
		shell.call("_on_undo_requested")
		_check_equal(landed_undo_before + 1, shell.get("_undo_motion_count"), "landed tray tile animates back on Undo")
		_check_equal(0, live_game.call("current_snapshot").momentum_units, "Undo removes the returned tile's Momentum bump")
		_check_equal(original_board_rect, shell.get("_last_undo_motion_target"), "landed Undo returns to the original board position")
		await create_timer(0.32).timeout
		_check(shell.get("_regions").board.get("_tile_buttons")[selectable_tile_id].visible, "landed Undo reveals the restored board tile on arrival")
		var paused_time: int = shell.call("_playback_time_ms")
		shell.call("_on_pause_requested")
		_check(shell.get("_pause_menu").visible, "pause button opens the first modal menu")
		_check(not shell.get("_pause_button").visible, "pause button yields focus to the open menu")
		await create_timer(0.05).timeout
		_check_equal(paused_time, shell.call("_playback_time_ms"), "pause menu freezes active gameplay time")
		shell.get("_pause_menu").emit_signal("resumed")
		_check(not shell.get("_pause_menu").visible, "Resume closes the pause menu")
		_check(shell.get("_pause_button").visible, "Resume restores the pause button")
		await create_timer(0.02).timeout
		_check(shell.call("_playback_time_ms") > paused_time, "Resume restarts active gameplay time")
		shell.call("_on_pause_requested")
		shell.get("_pause_menu").emit_signal("restart_requested")
		await process_frame
		live_game = shell.get("_game")
		_check_equal(0, live_game.revision, "pause-menu Restart creates a fresh game")
		_check(not shell.get("_pause_menu").visible, "Restart closes the pause menu")
		_check(shell.get("_pause_button").visible, "Restart restores the pause button")
		var undo_tile_id := ""
		for tile in live_game.board.call("selectable_tiles"):
			undo_tile_id = tile.id
			break
		var undo_target: Rect2 = shell.get("_regions").board.call("tile_global_rect", undo_tile_id)
		shell.call("_on_tile_selected", undo_tile_id)
		var undo_motion_before: int = shell.get("_undo_motion_count")
		shell.call("_on_undo_requested")
		_check_equal(0, live_game.tray.tiles.size(), "rapid Undo restores authoritative tray immediately")
		_check(live_game.board.call("is_tile_active", undo_tile_id), "rapid Undo restores authoritative board state immediately")
		_check_equal(undo_motion_before + 1, shell.get("_undo_motion_count"), "Undo reverses the in-flight tile visual")
		_check_equal(undo_target, shell.get("_last_undo_motion_target"), "Undo animation targets the restored board position")
		_check(not shell.get("_regions").board.get("_tile_buttons")[undo_tile_id].visible, "restored board tile stays hidden during return motion")
		await create_timer(0.32).timeout
		_check(shell.get("_regions").board.get("_tile_buttons")[undo_tile_id].visible, "restored board tile appears when Undo animation lands")
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
	var selectable_pair := _find_rewardable_pair(live_game)
	_check_equal(2, selectable_pair.size(), "reference game exposes a rewardable pair for feedback validation")
	if selectable_pair.size() == 2:
		shell.call("_on_tile_selected", selectable_pair[0])
		await create_timer(0.25).timeout
		var pair_feedback_before: int = shell.get("_pair_feedback_count")
		var pair_collision_before: int = shell.get("_pair_collision_count")
		var callout_before: int = shell.get("_performance_callout").get("play_count")
		var open_visual_slot: Rect2 = shell.get("_regions").tray.call("slot_global_rect", 1)
		shell.call("_on_tile_selected", selectable_pair[1])
		_check_equal(0, live_game.tray.tiles.size(), "resolved pair leaves no temporary animation occupancy in tray data")
		_check_equal(open_visual_slot, shell.get("_last_tile_motion_target"), "matching tile first targets the next open visual slot")
		await create_timer(0.20).timeout
		_check_equal(pair_collision_before, shell.get("_pair_collision_count"), "pair pauses briefly after landing before collision")
		await create_timer(0.30).timeout
		_check_equal(pair_collision_before + 1, shell.get("_pair_collision_count"), "pair performs one collision before removal pop")
		_check_equal(pair_feedback_before + 1, shell.get("_pair_feedback_count"), "resolved pair emits one reusable match burst")
		_check_equal(1, live_game.tray.resolved_pair_count, "match feedback follows a committed pair transaction")
		_check_equal(1, live_game.call("combo_at", shell.call("_playback_time_ms")), "natural pair starts the live Combo readout")
		var reward: Dictionary = live_game.call("last_transaction").telemetry.get("difficulty_reward", {})
		_check(not reward.is_empty(), "qualified pair records its difficulty reward")
		_check_equal(callout_before + 1, shell.get("_performance_callout").get("play_count"), "difficulty reward starts one live-text callout")
		_check_equal(str(reward.callout_key), shell.get("_performance_callout").get("last_callout_key"), "callout consumes the transaction event key")
	var visible_blocked_tile_id := ""
	for tile in live_game.board.tiles:
		if live_game.board.call("is_tile_visible", tile.id) \
				and not live_game.board.call("is_tile_selectable", tile.id) \
				and not live_game.board.call("is_tile_revealable", tile.id):
			visible_blocked_tile_id = tile.id
			break
	_check(not visible_blocked_tile_id.is_empty(), "reference layout contains a visible tile blocked from normal movement")
	if not visible_blocked_tile_id.is_empty():
		var board: Control = shell.get("_regions").board
		var negative_count: int = board.call("negative_feedback_count")
		var revision_before: int = live_game.revision
		var target_button: Button = board.get("_tile_buttons")[visible_blocked_tile_id]
		_check(target_button.modulate != Color.WHITE, "normally unselectable tile is visibly darkened")
		board.call("_on_tile_pressed", visible_blocked_tile_id)
		_check_equal(revision_before + 1, live_game.revision, "blocked-tile feedback records a live Combo break")
		_check_equal(0, live_game.call("combo_at", shell.call("_playback_time_ms")), "blocked tile tap kills Combo")
		_check_equal("locked_tile_tap", live_game.call("last_transaction").telemetry.combo_break_reason, "blocked tile break is replay telemetry")
		_check_equal(negative_count + 1, board.call("negative_feedback_count"), "blocked tile tap starts negative feedback")
		await create_timer(0.25).timeout
		shell.call("_on_delete_pair_requested")
		_check(not target_button.disabled, "Delete Pair mode enables visible tiles blocked from normal movement")
		_check_equal(Color.WHITE, target_button.modulate, "Delete Pair target returns to full color")

	shell.call("_on_restart_requested")
	live_game = shell.get("_game")
	var deletable_pair := _find_visible_pair(live_game)
	_check_equal(2, deletable_pair.size(), "reference game exposes a visible pair for Delete Pair feedback")
	if deletable_pair.size() == 2:
		var delete_feedback_before: int = shell.get("_pair_feedback_count")
		shell.call("_on_delete_pair_requested")
		shell.call("_on_tile_selected", deletable_pair[0])
		await create_timer(0.25).timeout
		_check_equal(delete_feedback_before + 1, shell.get("_pair_feedback_count"), "Delete Pair composes the shared removal burst")
		_check_equal(1, live_game.tray.resolved_pair_count, "Delete Pair feedback follows a committed transaction")

	var orientation := "portrait" if root.size.x < root.size.y else "landscape"
	shell.call("_apply_layout")
	await process_frame
	_validate_regions(shell, orientation)
	_validate_board_tiles(shell, orientation)
	_validate_consumables(shell, orientation)

	shell.call("_on_update_available", "0.2.0-smoke.1", "https://play.google.com/apps/internaltest/4701554282456194202", false)
	await process_frame
	var banner: Control = shell.get("_update_banner")
	_check(banner != null and banner.visible, "%s update banner displays on available update" % orientation)
	if banner != null and banner.visible:
		var banner_rect := Rect2(banner.position, banner.size)
		var safe_viewport := SafeAreaScript.content_rect(shell.get_viewport_rect().size, shell.call("_get_safe_area_insets"))
		_check(shell.get_viewport_rect().encloses(banner_rect), "%s update banner stays inside viewport (%s)" % [orientation, banner_rect])
		_check(safe_viewport.encloses(banner_rect), "%s update banner stays inside safe area (%s in %s)" % [orientation, banner_rect, safe_viewport])
		_check(
			not Rect2(banner.position, banner.size).intersects(Rect2(shell.get("_pause_button").position, shell.get("_pause_button").size)),
			"%s update banner does not cover pause button" % orientation
		)
		banner.call("_on_dismiss_pressed")
		_check(not banner.visible, "%s update banner hides on dismiss" % orientation)
		await process_frame

	shell.set("_delete_pair_armed", false)
	shell.get("_regions").board.call("set_delete_pair_armed", false)
	if OS.get_cmdline_user_args().has("--callout-capture"):
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
		shell.call("_apply_layout")
		var capture_pair := _find_rewardable_pair(live_game)
		if capture_pair.size() == 2:
			shell.call("_on_tile_selected", capture_pair[0])
			await create_timer(0.2).timeout
			shell.call("_on_tile_selected", capture_pair[1])
			await create_timer(0.18).timeout
	else:
		var capture_tile_id := ""
		for tile in live_game.board.call("selectable_tiles"):
			capture_tile_id = tile.id
			break
		if not capture_tile_id.is_empty():
			shell.call("_on_tile_selected", capture_tile_id)
			await create_timer(0.25).timeout
	if OS.get_cmdline_user_args().has("--pause-menu"):
		shell.call("_on_pause_requested")
		await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		printerr("capture skipped: active renderer does not expose a framebuffer")
	else:
		RenderingServer.force_draw()
		var image := root.get_texture().get_image()
		var capture_name := "difficulty-callout" if OS.get_cmdline_user_args().has("--callout-capture") \
			else "pause-menu" if OS.get_cmdline_user_args().has("--pause-menu") \
			else "small-phone" if OS.get_cmdline_user_args().has("--small-phone") \
			else "safe-%s" % orientation if OS.get_cmdline_user_args().has("--safe-area") else orientation
		var output_path := "user://m7_%s.png" % capture_name
		if image == null:
			printerr("capture skipped: active renderer does not expose a framebuffer")
		elif image.save_png(output_path) != OK:
			_fail("could not save %s capture" % orientation)
		else:
			printerr("capture: %s" % ProjectSettings.globalize_path(output_path))

	printerr("PASS: responsive UI smoke" if _failures == 0 else "FAIL: %d responsive UI check(s)" % _failures)
	shell.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if _failures > 0 else 0)


func _validate_regions(shell: Control, orientation: String) -> void:
	var regions: Dictionary = shell.get("_regions")
	var viewport_rect := shell.get_viewport_rect()
	var safe_viewport: Rect2 = SafeAreaScript.content_rect(viewport_rect.size, shell.call("_get_safe_area_insets"))
	var debug_panel: Control = shell.get("_debug_panel")
	var pause_button: Button = shell.get("_pause_button")
	var momentum: Control = regions.momentum
	var combo_label: Label = momentum.get("_combo")
	var momentum_meter: ProgressBar = momentum.get("_meter")
	_check(not Rect2(combo_label.position, combo_label.size).intersects(Rect2(momentum_meter.position, momentum_meter.size)), "%s Combo readout does not cover Momentum meter" % orientation)
	_check(viewport_rect.encloses(Rect2(pause_button.position, pause_button.size)), "%s pause button stays inside viewport" % orientation)
	_check(safe_viewport.encloses(Rect2(pause_button.position, pause_button.size)), "%s pause button stays inside safe area" % orientation)
	if debug_panel.visible:
		_check(viewport_rect.encloses(Rect2(debug_panel.position, debug_panel.size)), "%s debug panel stays inside viewport" % orientation)
		_check(safe_viewport.encloses(Rect2(debug_panel.position, debug_panel.size)), "%s debug panel stays inside safe area" % orientation)
	var names: Array = []
	for name in regions:
		if regions[name].visible:
			names.append(name)
	for name in names:
		var region: Control = regions[name]
		var region_rect := Rect2(region.position, region.size)
		_check(
			viewport_rect.encloses(region_rect),
			"%s %s stays inside viewport (%s in %s)" % [orientation, name, region_rect, viewport_rect]
		)
		_check(
			safe_viewport.encloses(region_rect),
			"%s %s stays inside safe area (%s in %s)" % [orientation, name, region_rect, safe_viewport]
		)

	var tray: Control = regions.tray
	var board: Control = regions.board
	var board_tile_size: Vector2 = board.call("tile_visual_size")
	for slot in tray.get("_slots"):
		_check(slot.size.is_equal_approx(board_tile_size), "%s tray slot preserves board tile size" % orientation)
	var callout: Control = shell.get("_performance_callout")
	var callout_label: Label = callout.get("_label")
	_check_equal(Rect2(board.position, board.size), Rect2(callout.position, callout.size), "%s callout tracks the board region" % orientation)
	_check(Rect2(Vector2.ZERO, callout.size).encloses(Rect2(callout_label.position, callout_label.size)), "%s callout text stays inside the board overlay" % orientation)
	_check(
		tray.position.y + tray.size.y <= board.position.y,
		"%s tray stays above the game board" % orientation
	)
	_check(
		not Rect2(pause_button.position, pause_button.size).intersects(Rect2(regions.momentum.position, regions.momentum.size)),
		"%s pause button does not cover Momentum" % orientation
	)

	for first_index in range(names.size()):
		for second_index in range(first_index + 1, names.size()):
			var first: Control = regions[names[first_index]]
			var second: Control = regions[names[second_index]]
			_check(
				not Rect2(first.position, first.size).intersects(Rect2(second.position, second.size)),
				"%s %s and %s do not overlap" % [orientation, names[first_index], names[second_index]]
			)

	if orientation == "portrait" and debug_panel.visible:
		for name in names:
			var region: Control = regions[name]
			_check(
				not Rect2(debug_panel.position, debug_panel.size).intersects(Rect2(region.position, region.size)),
				"portrait debug panel and %s do not overlap" % name
			)


func _validate_board_tiles(shell: Control, orientation: String) -> void:
	var board: Control = shell.get("_regions").board
	var tile_layer: Control = board.get("_tile_layer")
	var tile_layer_rect := Rect2(Vector2.ZERO, tile_layer.size)
	var minimum_tile_size := Vector2(INF, INF)
	var board_footprint := Rect2()
	var has_visible_tile := false
	for button in board.get("_tile_buttons").values():
		var tile_rect := Rect2(button.position, button.size)
		_check(tile_layer_rect.encloses(tile_rect), "%s %s stays inside board bounds" % [orientation, button.name])
		minimum_tile_size.x = minf(minimum_tile_size.x, button.size.x)
		minimum_tile_size.y = minf(minimum_tile_size.y, button.size.y)
		if button.visible:
			board_footprint = tile_rect if not has_visible_tile else board_footprint.merge(tile_rect)
			has_visible_tile = true
	if not OS.get_cmdline_user_args().has("--safe-area"):
		_check(
			minimum_tile_size.x >= 32.0 and minimum_tile_size.y >= 40.0,
			"%s tiles preserve the M7 minimum footprint (%s)" % [orientation, minimum_tile_size]
		)
	_check(has_visible_tile, "%s board renders visible tiles" % orientation)
	_check(
		board_footprint.size.y > board_footprint.size.x,
		"%s preserves the portrait-authored board footprint (%s)" % [orientation, board_footprint.size]
	)


func _validate_consumables(shell: Control, orientation: String) -> void:
	var consumables: Control = shell.get("_regions").consumables
	var buttons: Dictionary = consumables.get("_buttons")
	var panel_rect := Rect2(Vector2.ZERO, consumables.size)
	var controls: Array[Control] = []
	for button in buttons.values():
		controls.append(button)
	var notice: Label = consumables.get("_notice")
	if notice.visible:
		controls.append(notice)
	for control in controls:
		_check(panel_rect.encloses(Rect2(control.position, control.size)), "%s consumable control stays inside its panel" % orientation)
	for first_index in range(controls.size()):
		for second_index in range(first_index + 1, controls.size()):
			var first_rect := Rect2(controls[first_index].position, controls[first_index].size)
			var second_rect := Rect2(controls[second_index].position, controls[second_index].size)
			_check(
				not first_rect.intersects(second_rect),
				"%s consumable controls do not overlap (%s %s, %s %s)" % [
					orientation,
					controls[first_index].name,
					first_rect,
					controls[second_index].name,
					second_rect,
				]
			)
	_check(buttons.has("undo"), "%s consumables own Undo" % orientation)
	for consumable_type in buttons:
		if consumable_type != "undo":
			if consumables.size.y <= 180.0:
				_check(buttons.undo.position.x > buttons[consumable_type].position.x, "%s Undo stays rightmost" % orientation)
			else:
				_check(buttons.undo.position.y > buttons[consumable_type].position.y, "%s Undo stays last in the tool stack" % orientation)
	var tray_has_command_button := false
	for child in shell.get("_regions").tray.get_children():
		tray_has_command_button = tray_has_command_button or child is Button
	_check(not tray_has_command_button, "%s tray contains no command buttons" % orientation)


func _find_rewardable_pair(game: Variant) -> Array[String]:
	var analysis: Dictionary = game.call("opportunity_analysis")
	for pair in analysis.pair_scores:
		var observed: Dictionary = pair.duplicate(true)
		observed["source"] = "board_pair"
		if not PairDifficultyRewardsScript.evaluate(observed, game.definition.configuration).is_empty():
			var ids: Array[String] = []
			ids.assign(pair.tile_ids)
			return ids
	return []


func _find_visible_pair(game: Variant) -> Array[String]:
	var visible: Array = game.board.call("visible_tiles")
	for first_index in range(visible.size()):
		for second_index in range(first_index + 1, visible.size()):
			var first: Variant = visible[first_index]
			var second: Variant = visible[second_index]
			if first.face.family == second.face.family and first.face.value == second.face.value:
				return [first.id, second.id]
	return []

func _check(condition: bool, message: String) -> void:
	if condition:
		printerr("OK: %s" % message)
	else:
		_fail(message)


func _check_equal(expected: Variant, actual: Variant, message: String) -> void:
	_check(expected == actual, "%s (expected=%s actual=%s)" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures += 1
	printerr("ERR: %s" % message)
