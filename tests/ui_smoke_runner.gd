extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shell: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(shell)
	await process_frame

	var orientation := "portrait" if root.size.x < root.size.y else "landscape"
	shell.call("_apply_layout")
	await process_frame
	_validate_regions(shell, orientation)
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var output_path := "user://m3_%s.png" % orientation
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


func _check(condition: bool, message: String) -> void:
	if condition:
		printerr("OK: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	printerr("ERR: %s" % message)
