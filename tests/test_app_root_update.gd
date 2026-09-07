extends SceneTree

const AppRootScript := preload("res://scripts/presentation/app_root.gd")

var _failures := 0
var _assertions := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("Running AppRoot update banner tests...")
	await _test_app_root_update_flow()

	if _failures == 0:
		print("AppRoot update banner tests passed! (%d assertions)" % _assertions)
		quit(0)
	else:
		push_error("AppRoot update banner tests failed with %d errors" % _failures)
		quit(1)


func _test_app_root_update_flow() -> void:
	root.size = Vector2i(720, 1280)
	var app: Control = AppRootScript.new()
	root.add_child(app)
	await process_frame

	var checker: Node = app.get("_update_checker")
	_check(checker != null, "AppRoot creates UpdateChecker on startup")

	var banner: Control = app.get("_update_banner")
	_check(banner != null, "AppRoot creates GlobalUpdateBanner on startup")
	_check(not banner.visible, "Update banner is initially hidden")

	# Simulate up to date check: banner remains hidden (quick top message removed)
	checker.call("mock_trigger_check_status", checker.call("get_current_version_code"), "0.1.27", false)
	await process_frame
	_check(not banner.visible, "Update banner stays hidden when app is up to date")

	# Simulate update available via check_status_reported
	checker.call("mock_trigger_check_status", checker.call("get_current_version_code") + 100, "0.9.5-test", true)
	await process_frame

	_check(banner.visible, "Update banner becomes visible on update_available signal")
	var update_btn: Button = banner.get("_update_button") as Button
	_check(update_btn != null and update_btn.visible, "Update button is visible for update available banner")
	_check(banner.size.x > 100.0, "Update banner has valid width")
	_check(banner.size.x <= 640.0, "Update banner width is constrained to max width")
	_check(banner.position.y >= 0.0, "Update banner sits at top safe area")
	_check(banner.position.x >= 0.0, "Update banner has valid horizontal position")

	# Test responsive layout on screen resize (e.g. Landscape)
	root.size = Vector2i(1920, 1080)
	app.size = Vector2(1920, 1080)
	app.call("_layout_update_banner")
	await process_frame

	_check(banner.size.x <= 640.0, "Update banner remains constrained in wide/landscape view")
	_check(banner.position.x > 400.0, "Update banner is horizontally centered in landscape view")

	# Dismiss banner
	var dismiss_btn: Button = banner.get("_dismiss_button") as Button
	if dismiss_btn != null:
		dismiss_btn.emit_signal("pressed")
		await process_frame
		_check(not banner.visible, "Dismiss button hides update banner")

	app.queue_free()




func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % message)
	else:
		print("  OK: %s" % message)


func _check_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assertions += 1
	if expected != actual:
		_failures += 1
		push_error("FAIL: %s | expected=%s actual=%s" % [message, expected, actual])
	else:
		print("  OK: %s | expected=%s actual=%s" % [message, expected, actual])
