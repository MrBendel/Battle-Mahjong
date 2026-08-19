extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_size := Vector2i(1280, 720)
	if OS.get_cmdline_user_args().has("--portrait"):
		requested_size = Vector2i(430, 932)
	root.size = requested_size
	var shell: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(shell)
	await process_frame
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
	var visible_blocked_tile_id := ""
	for tile in live_game.board.tiles:
		if live_game.board.call("is_tile_visible", tile.id) and not live_game.board.call("is_tile_selectable", tile.id):
			visible_blocked_tile_id = tile.id
			break
	_check(not visible_blocked_tile_id.is_empty(), "reference layout contains a visible tile blocked from normal movement")
	if not visible_blocked_tile_id.is_empty():
		shell.call("_on_delete_pair_requested")
		var target_button: Button = shell.get("_regions").board.get("_tile_buttons")[visible_blocked_tile_id]
		_check(not target_button.disabled, "Delete Pair mode enables visible tiles blocked from normal movement")

	var orientation := "portrait" if root.size.x < root.size.y else "landscape"
	shell.call("_apply_layout")
	await process_frame
	_validate_regions(shell, orientation)
	_validate_board_tiles(shell, orientation)
	_validate_consumables(shell, orientation)
	if DisplayServer.get_name() == "headless":
		printerr("capture skipped: active renderer does not expose a framebuffer")
	else:
		RenderingServer.force_draw()
		var image := root.get_texture().get_image()
		var output_path := "user://m4_%s.png" % orientation
		if image == null:
			printerr("capture skipped: active renderer does not expose a framebuffer")
		elif image.save_png(output_path) != OK:
			_fail("could not save %s capture" % orientation)
		else:
			printerr("capture: %s" % ProjectSettings.globalize_path(output_path))

	printerr("PASS: responsive UI smoke" if _failures == 0 else "FAIL: %d responsive UI check(s)" % _failures)
	shell.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _validate_regions(shell: Control, orientation: String) -> void:
	var regions: Dictionary = shell.get("_regions")
	var viewport_rect := shell.get_viewport_rect()
	var debug_panel: Control = shell.get("_debug_panel")
	_check(viewport_rect.encloses(Rect2(debug_panel.position, debug_panel.size)), "%s debug panel stays inside viewport" % orientation)
	var names: Array = regions.keys()
	for name in names:
		var region: Control = regions[name]
		var region_rect := Rect2(region.position, region.size)
		_check(
			viewport_rect.encloses(region_rect),
			"%s %s stays inside viewport (%s in %s)" % [orientation, name, region_rect, viewport_rect]
		)

	for first_index in range(names.size()):
		for second_index in range(first_index + 1, names.size()):
			var first: Control = regions[names[first_index]]
			var second: Control = regions[names[second_index]]
			_check(
				not Rect2(first.position, first.size).intersects(Rect2(second.position, second.size)),
				"%s %s and %s do not overlap" % [orientation, names[first_index], names[second_index]]
			)

	if orientation == "portrait":
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
	var panel_rect := Rect2(Vector2.ZERO, consumables.size)
	var controls: Array[Control] = []
	for button in consumables.get("_buttons").values():
		controls.append(button)
	var notice: Label = consumables.get("_notice")
	if notice.visible:
		controls.append(notice)
	for control in controls:
		_check(panel_rect.encloses(Rect2(control.position, control.size)), "%s consumable control stays inside its panel" % orientation)
	for first_index in range(controls.size()):
		for second_index in range(first_index + 1, controls.size()):
			_check(
				not Rect2(controls[first_index].position, controls[first_index].size).intersects(
					Rect2(controls[second_index].position, controls[second_index].size)
				),
				"%s consumable controls do not overlap" % orientation
			)

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
