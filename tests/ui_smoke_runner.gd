extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_size := Vector2i(1280, 720)
	if OS.get_cmdline_user_args().has("--small-phone"):
		requested_size = Vector2i(375, 667)
	elif OS.get_cmdline_user_args().has("--portrait"):
		requested_size = Vector2i(430, 932)
	root.size = requested_size
	var shell: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(shell)
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
		int(tuning.get("pair_gain")),
		int(live_game.definition.configuration.momentum_pair_gain),
		"main scene copies Inspector tuning into game definition"
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
		var expected_target: Rect2 = shell.get("_regions").tray.call("slot_global_rect", 0)
		shell.call("_on_tile_selected", selectable_tile_id)
		_check_equal(1, shell.get("_tile_motion_count"), "ordinary selection starts one board-to-tray animation")
		_check_equal(expected_target, shell.get("_last_tile_motion_target"), "selection animation targets the next tray slot")
		var first_slot_art: TextureRect = shell.get("_regions").tray.get("_slot_art")[0]
		_check(first_slot_art.visible and first_slot_art.texture != null, "tray uses the selected face artwork")
		await create_timer(0.25).timeout
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
	var selectable_pair := _find_selectable_pair(live_game)
	_check_equal(2, selectable_pair.size(), "reference game exposes a legal pair for match-feedback validation")
	if selectable_pair.size() == 2:
		shell.call("_on_tile_selected", selectable_pair[0])
		await create_timer(0.25).timeout
		var pair_feedback_before: int = shell.get("_pair_feedback_count")
		shell.call("_on_tile_selected", selectable_pair[1])
		await create_timer(0.35).timeout
		_check_equal(pair_feedback_before + 1, shell.get("_pair_feedback_count"), "resolved pair emits one reusable match burst")
		_check_equal(1, live_game.tray.resolved_pair_count, "match feedback follows a committed pair transaction")
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
	var visible_blocked_tile_id := ""
	for tile in live_game.board.tiles:
		if live_game.board.call("is_tile_visible", tile.id) and not live_game.board.call("is_tile_selectable", tile.id):
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
		_check_equal(revision_before, live_game.revision, "blocked-tile feedback does not submit a gameplay command")
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
	shell.set("_delete_pair_armed", false)
	shell.get("_regions").board.call("set_delete_pair_armed", false)
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
		var capture_name := "pause-menu" if OS.get_cmdline_user_args().has("--pause-menu") \
			else "small-phone" if OS.get_cmdline_user_args().has("--small-phone") else orientation
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
	var debug_panel: Control = shell.get("_debug_panel")
	var pause_button: Button = shell.get("_pause_button")
	_check(viewport_rect.encloses(Rect2(pause_button.position, pause_button.size)), "%s pause button stays inside viewport" % orientation)
	if debug_panel.visible:
		_check(viewport_rect.encloses(Rect2(debug_panel.position, debug_panel.size)), "%s debug panel stays inside viewport" % orientation)
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

	var tray: Control = regions.tray
	var board: Control = regions.board
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


func _find_selectable_pair(game: Variant) -> Array[String]:
	for first in game.board.call("selectable_tiles"):
		for second in game.board.call("selectable_tiles_without", first.id):
			if first.face.family == second.face.family and first.face.value == second.face.value:
				return [first.id, second.id]
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
