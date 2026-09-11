extends SceneTree

const ConsumableButtonScript := preload("res://scripts/presentation/consumable_button.gd")

var _failures := 0
var _assertions := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("Running ConsumableButton tests...")
	_test_clean_tap()
	_test_swipe_up_cancelled()
	_test_bottom_viewport_edge_rejected()
	_test_bottom_button_edge_rejected()
	_test_drag_slop_exceeded_cancelled()
	_test_touch_canceled_event()
	_test_off_screen_drag_entry_ignored()
	_test_disarm_resets_state()
	_test_mouse_click()
	_test_mouse_swipe_up_cancelled()

	if _failures == 0:
		print("ConsumableButton tests passed! (%d assertions)" % _assertions)
		quit(0)
	else:
		push_error("ConsumableButton tests failed with %d errors" % _failures)
		quit(1)


func _create_button(pos := Vector2(100, 700), btn_size := Vector2(80, 110)) -> Button:
	var btn: Button = ConsumableButtonScript.new()
	btn.position = pos
	btn.size = btn_size
	root.add_child(btn)
	return btn


func _test_clean_tap() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 1000), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	var touch_pos := Vector2(40, 40)

	# Touch down
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = touch_pos
	down.pressed = true
	btn._gui_input(down)

	_check(not btn.is_disarmed(), "Tap down is armed")

	# Touch up at same position
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = touch_pos
	up.pressed = false
	btn._gui_input(up)

	_check_equal(1, pressed_count[0], "Clean tap emits pressed once")
	btn.queue_free()


func _test_swipe_up_cancelled() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 1000), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	var start_pos := Vector2(40, 50)

	# Touch down
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = start_pos
	down.pressed = true
	btn._gui_input(down)

	# Drag up by 25px
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = start_pos + Vector2(0, -25)
	btn._gui_input(drag)

	_check(btn.is_disarmed(), "Swipe up disarms button")

	# Touch up
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = start_pos + Vector2(0, -25)
	up.pressed = false
	btn._gui_input(up)

	_check_equal(0, pressed_count[0], "Swipe up never emits pressed")
	btn.queue_free()


func _test_bottom_viewport_edge_rejected() -> void:
	root.size = Vector2i(720, 1280)
	# Button placed right at the bottom of the viewport
	var btn := _create_button(Vector2(100, 1200), Vector2(80, 80))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	# Touch down in bottom margin zone (within 28px of 1280, e.g. 1265)
	var edge_pos := Vector2(40, 68)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = edge_pos
	down.pressed = true
	btn._gui_input(down)

	_check(btn.is_disarmed(), "Touch in bottom viewport margin disarms immediately")

	# Touch up
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = edge_pos
	up.pressed = false
	btn._gui_input(up)

	_check_equal(0, pressed_count[0], "Bottom viewport margin touch never emits pressed")
	btn.queue_free()


func _test_bottom_button_edge_rejected() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 800), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	# Touch down at local y = 106 (within 10px of button bottom 110)
	var edge_pos := Vector2(40, 106)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = edge_pos
	down.pressed = true
	btn._gui_input(down)

	_check(btn.is_disarmed(), "Touch in bottom button margin disarms immediately")

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = edge_pos
	up.pressed = false
	btn._gui_input(up)

	_check_equal(0, pressed_count[0], "Bottom button margin touch never emits pressed")
	btn.queue_free()


func _test_drag_slop_exceeded_cancelled() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 800), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	var start_pos := Vector2(40, 40)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = start_pos
	down.pressed = true
	btn._gui_input(down)

	# Drag sideways by 30px (exceeds TAP_MAX_TRAVEL_PX = 14)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = start_pos + Vector2(30, 0)
	btn._gui_input(drag)

	_check(btn.is_disarmed(), "Exceeding drag slop disarms button")

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = start_pos + Vector2(30, 0)
	up.pressed = false
	btn._gui_input(up)

	_check_equal(0, pressed_count[0], "Excessive drag never emits pressed")
	btn.queue_free()


func _test_touch_canceled_event() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 800), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	var start_pos := Vector2(40, 40)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = start_pos
	down.pressed = true
	btn._gui_input(down)

	# OS gesture cancellation (e.g. system gesture intercepts)
	var cancel_touch := InputEventScreenTouch.new()
	cancel_touch.index = 0
	cancel_touch.position = start_pos
	cancel_touch.pressed = false
	cancel_touch.canceled = true
	btn._gui_input(cancel_touch)

	_check(btn.is_disarmed(), "Canceled touch disarms button")
	_check_equal(0, pressed_count[0], "Canceled touch never emits pressed")
	btn.queue_free()


func _test_off_screen_drag_entry_ignored() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 1000), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	# A drag event arrives without a down event on this button (off-screen swipe entered)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(40, 40)
	btn._gui_input(drag)

	# Followed by a release
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = Vector2(40, 40)
	up.pressed = false
	btn._gui_input(up)

	_check_equal(0, pressed_count[0], "Off-screen drag entry never emits pressed")
	btn.queue_free()


func _test_disarm_resets_state() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 800), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	var start_pos := Vector2(40, 40)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = start_pos
	down.pressed = true
	btn._gui_input(down)

	# Explicit disarm (e.g. app backgrounded or view reset)
	btn.disarm()
	_check(btn.is_disarmed(), "Explicit disarm marks button disarmed")

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = start_pos
	up.pressed = false
	btn._gui_input(up)

	_check_equal(0, pressed_count[0], "Disarmed button does not emit pressed on release")
	btn.queue_free()


func _test_mouse_click() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 800), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	var click_global := btn.global_position + Vector2(40, 40)
	var click_local := Vector2(40, 40)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = click_local
	down.global_position = click_global
	down.pressed = true
	btn._gui_input(down)

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = click_local
	up.global_position = click_global
	up.pressed = false
	btn._gui_input(up)

	_check_equal(1, pressed_count[0], "Mouse click emits pressed once")
	btn.queue_free()


func _test_mouse_swipe_up_cancelled() -> void:
	root.size = Vector2i(720, 1280)
	var btn := _create_button(Vector2(100, 800), Vector2(80, 110))
	var pressed_count := [0]
	btn.pressed.connect(func() -> void: pressed_count[0] += 1)

	var start_global := btn.global_position + Vector2(40, 40)
	var start_local := Vector2(40, 40)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = start_local
	down.global_position = start_global
	down.pressed = true
	btn._gui_input(down)

	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = start_local + Vector2(0, -20)
	motion.global_position = start_global + Vector2(0, -20)
	btn._gui_input(motion)

	_check(btn.is_disarmed(), "Mouse upward drag disarms button")

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = start_local + Vector2(0, -20)
	up.global_position = start_global + Vector2(0, -20)
	up.pressed = false
	btn._gui_input(up)

	_check_equal(0, pressed_count[0], "Mouse upward drag never emits pressed")
	btn.queue_free()


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
