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

	# Simulate update available signal
	checker.call("mock_trigger_update_available", "0.9.5-test", "https://example.com/store", false)
	await process_frame

	_check(banner.visible, "Update banner becomes visible on update_available signal")
	_check(banner.size.x > 100.0, "Update banner has valid width")
	_check(banner.position.y >= 0.0, "Update banner sits at top safe area")

	# Dismiss banner
	var dismiss_button: Button = banner.get("_dismiss_button") as Button
	if dismiss_button != null:
		dismiss_button.emit_signal("pressed")
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
