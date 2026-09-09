extends SceneTree

const VIEWPORT_SIZE := Vector2i(430, 932)
const CAPACITIES := [3, 5]
const CAPTURE_MARGIN := 8


func _init() -> void:
	call_deferred("_capture_variants")


func _capture_variants() -> void:
	root.size = VIEWPORT_SIZE
	for capacity in CAPACITIES:
		var shell: Control = load("res://scenes/game_shell.tscn").instantiate()
		shell.set("show_layout_generator_on_start", false)
		shell.set("show_modifier_picker_on_start", false)
		root.add_child(shell)
		await process_frame
		await process_frame

		var banner: Control = shell.get("_update_banner")
		if banner != null:
			banner.visible = false
		var game: Variant = shell.get("_game")
		game.definition.configuration["tray_capacity"] = capacity
		var tray: Control = shell.get("_regions").tray
		tray.call("refresh")
		shell.call("_apply_layout")
		await process_frame
		await process_frame

		RenderingServer.force_draw()
		var viewport_image := root.get_texture().get_image()
		var tray_rect := tray.get_global_rect().grow(CAPTURE_MARGIN)
		var capture_rect := Rect2i(tray_rect).intersection(Rect2i(Vector2i.ZERO, VIEWPORT_SIZE))
		var tray_image := viewport_image.get_region(capture_rect)
		var output_path := "user://m7_tray-%d-slots.png" % capacity
		if tray_image.save_png(output_path) != OK:
			push_error("Unable to save tray capture: %s" % output_path)
		else:
			print(ProjectSettings.globalize_path(output_path))

		shell.queue_free()
		await process_frame

	quit()
