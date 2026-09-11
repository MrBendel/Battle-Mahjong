class_name ConsumableButton
extends Button

## A Button specialized for bottom-bar consumable power-ups with edge-swipe
## and upward-drag protection.
##
## Prevents accidental activations when a player swipes up from the bottom edge
## of the device to access the Android/iOS home screen or app switcher.

signal activated

const TAP_MAX_TRAVEL_PX := 14.0
const SWIPE_UP_CANCEL_PX := -6.0
const BOTTOM_EDGE_GESTURE_MARGIN := 28.0
const BUTTON_BOTTOM_EDGE_MARGIN := 10.0

var _touch_active := false
var _touch_index := -1
var _touch_start_global := Vector2.ZERO
var _disarmed := false
var _scale_factor := 1.0


func set_scale_factor(scale_value: float) -> void:
	_scale_factor = maxf(0.5, scale_value)


func disarm() -> void:
	_touch_active = false
	_touch_index = -1
	_disarmed = true
	set_pressed_no_signal(false)


func is_disarmed() -> bool:
	return _disarmed


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_PAUSED:
		disarm()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		disarm()
		return

	if event is InputEventScreenTouch:
		var coords := _get_event_coords(event)
		if event.pressed:
			_handle_pointer_down(coords.global, event.index, coords.local)
		else:
			_handle_pointer_up(coords.global, event.index, event.canceled)
	elif event is InputEventScreenDrag:
		var coords := _get_event_coords(event)
		_handle_pointer_drag(coords.global, event.index)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Ignore emulated mouse events if a real screen touch is active
			if _touch_active and _touch_index >= 0:
				accept_event()
				return
			var coords := _get_event_coords(event)
			if event.pressed:
				_handle_pointer_down(coords.global, -1, coords.local)
			else:
				var is_canceled: bool = event.canceled if "canceled" in event else false
				_handle_pointer_up(coords.global, -1, is_canceled)
	elif event is InputEventMouseMotion:
		if _touch_active and _touch_index == -1 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var coords := _get_event_coords(event)
			_handle_pointer_drag(coords.global, -1)


func _get_event_coords(event: InputEvent) -> Dictionary:
	var global_pos := Vector2.ZERO
	var local_pos := Vector2.ZERO
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		# Control._gui_input() receives touch positions in this control's local
		# coordinate space, just like mouse events without global_position.
		local_pos = event.position
		global_pos = get_global_transform() * local_pos
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if "global_position" in event and event.global_position != Vector2.ZERO:
			global_pos = event.global_position
			local_pos = get_global_transform().affine_inverse() * event.global_position
		else:
			local_pos = event.position
			global_pos = get_global_transform() * event.position
	return {"global": global_pos, "local": local_pos}


func _handle_pointer_down(global_pos: Vector2, index: int, local_pos: Vector2) -> void:
	if _touch_active and index != _touch_index:
		disarm()
		accept_event()
		return

	var vp_height := get_viewport_rect().size.y
	var edge_margin := BOTTOM_EDGE_GESTURE_MARGIN * _scale_factor
	var btn_edge_margin := BUTTON_BOTTOM_EDGE_MARGIN * _scale_factor

	# 1. Reject if touch originates in the bottom edge gesture zone of the viewport
	# (system navigation bar / home swipe bar area).
	if global_pos.y >= vp_height - edge_margin:
		disarm()
		accept_event()
		return

	# 2. Reject if touch originates at the bottom margin of the button itself.
	if local_pos.y >= size.y - btn_edge_margin:
		disarm()
		accept_event()
		return

	_touch_active = true
	_touch_index = index
	_touch_start_global = global_pos
	_disarmed = false
	set_pressed_no_signal(true)
	accept_event()


func _handle_pointer_drag(global_pos: Vector2, index: int) -> void:
	if not _touch_active or _disarmed:
		return
	if _touch_index != -1 and index != _touch_index:
		disarm()
		accept_event()
		return

	var delta := global_pos - _touch_start_global
	var max_travel := TAP_MAX_TRAVEL_PX * _scale_factor
	var cancel_y := SWIPE_UP_CANCEL_PX * _scale_factor

	# Disarm immediately if finger swipes upward toward the top of the screen
	# or drags further than the allowable tap slop.
	if delta.y < cancel_y or delta.length() > max_travel:
		disarm()
		accept_event()


func _handle_pointer_up(global_pos: Vector2, index: int, is_canceled: bool) -> void:
	if is_canceled or not _touch_active or _disarmed:
		disarm()
		accept_event()
		return

	if _touch_index != -1 and index != _touch_index:
		disarm()
		accept_event()
		return

	var delta := global_pos - _touch_start_global
	var max_travel := TAP_MAX_TRAVEL_PX * _scale_factor
	var cancel_y := SWIPE_UP_CANCEL_PX * _scale_factor

	if delta.y < cancel_y or delta.length() > max_travel:
		disarm()
		accept_event()
		return

	# Ensure the release point is still within the button boundary
	var local_release := get_global_transform().affine_inverse() * global_pos
	if not Rect2(Vector2.ZERO, size).has_point(local_release):
		disarm()
		accept_event()
		return

	_touch_active = false
	_touch_index = -1
	set_pressed_no_signal(false)
	_trigger_action()
	accept_event()


func _trigger_action() -> void:
	pressed.emit()
	activated.emit()
