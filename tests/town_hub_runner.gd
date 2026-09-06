extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_orientation(Vector2i(430, 932), "portrait")
	await _verify_orientation(Vector2i(1280, 720), "landscape")
	if _failures == 0:
		print("Town hub tests passed.")
		quit(0)
	else:
		push_error("Town hub tests failed: %d" % _failures)
		quit(1)


func _verify_orientation(viewport_size: Vector2i, label: String) -> void:
	root.size = viewport_size
	var app: Control = MAIN_SCENE.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame

	var theme: Resource = app.get("town_theme")
	_check(theme != null and theme.call("validation_errors").is_empty(), "%s theme validates" % label)
	var hub: Control = app.get("_hub")
	_check(hub != null and hub.visible, "%s starts on the town hub" % label)
	var map_rect: Rect2 = hub.get("_map_rect")
	_check(map_rect.size.x > 0.0 and map_rect.size.y > 0.0, "%s lays out the map" % label)
	_check(map_rect.position.x >= -0.01 and map_rect.position.y >= -0.01, "%s map stays inside the viewport" % label)
	_check(map_rect.end.x <= viewport_size.x + 0.01 and map_rect.end.y <= viewport_size.y + 0.01, "%s map fits the viewport" % label)
	var tower: TextureButton = hub.call("destination_button", "tower")
	var home: TextureButton = hub.call("destination_button", "home")
	_check(tower != null and not tower.disabled, "%s Tower destination is interactive" % label)
	_check(home != null and home.disabled, "%s unfinished destinations are disabled" % label)
	_check(tower.texture_click_mask != null, "%s Tower uses its sprite alpha as the hit target" % label)
	_check(tower.has_node("BuildingVisual") and tower.has_node("DestinationSign"), "%s destination separates smooth visual art and sign presentation" % label)
	var tower_hit_position := tower.position
	var tower_visual: Sprite2D = tower.get_node("BuildingVisual")
	var tower_visual_base: Vector2 = tower_visual.get_meta("base_position")
	hub.set("_animation_time", 0.37)
	hub.call("_process", 0.016)
	_check(tower.position.is_equal_approx(tower_hit_position), "%s Tower animation keeps its alpha hit target stationary" % label)
	_check(not tower_visual.position.is_equal_approx(tower_visual_base), "%s Tower animation moves only the rendered sprite" % label)
	_check(not is_equal_approx(tower_visual.position.y, roundf(tower_visual.position.y)), "%s Tower sprite keeps subpixel animation precision" % label)
	var tower_sign: Control = tower.get_node("DestinationSign")
	_check(tower_sign.call("fitted_font_size") > 0, "%s destination sign chooses a font size" % label)
	_check(tower_sign.call("text_fits"), "%s destination sign text fits its board" % label)
	for destination_id in ["tower", "home", "game_hall", "daily_shrine", "dojo", "downtown"]:
		var destination_button: TextureButton = hub.call("destination_button", destination_id)
		var destination_sign: Control = destination_button.get_node("DestinationSign")
		_check(destination_sign.call("text_fits"), "%s %s sign auto-fits its label" % [label, destination_id])
	var click_mask: BitMap = tower.texture_click_mask
	var mask_size := click_mask.get_size()
	_check(not click_mask.get_bit(0, 0), "%s transparent building corners reject input" % label)
	_check(click_mask.get_bit(mask_size.x / 2, mask_size.y / 2), "%s visible building center accepts input" % label)
	var test_insets := Rect2(18.0, 24.0, 30.0, 20.0)
	hub.call("set_safe_area_insets", test_insets)
	await process_frame
	map_rect = hub.get("_map_rect")
	_check(map_rect.position.x >= test_insets.position.x - 0.01, "%s map respects the left safe area" % label)
	_check(map_rect.position.y >= test_insets.position.y - 0.01, "%s map respects the top safe area" % label)
	_check(map_rect.end.x <= viewport_size.x - test_insets.size.x + 0.01, "%s map respects the right safe area" % label)
	_check(map_rect.end.y <= viewport_size.y - test_insets.size.y + 0.01, "%s map respects the bottom safe area" % label)
	hub.call("set_safe_area_insets", Rect2())
	await process_frame

	if OS.get_cmdline_user_args().has("--capture"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/screenshots"))
		var image := root.get_texture().get_image()
		if image != null:
			image.save_png("res://build/screenshots/town-hub-%s.png" % label)

	app.call("open_destination_for_testing", "tower")
	await process_frame
	_check(app.get("_game_shell") != null, "%s Tower opens the existing gameplay setup" % label)
	app.call("_show_hub")
	await process_frame
	_check(app.get("_hub") != null, "%s gameplay can return to town" % label)

	root.remove_child(app)
	app.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
