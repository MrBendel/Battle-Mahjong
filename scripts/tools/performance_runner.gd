extends SceneTree

const DEFAULT_OUTPUT := "res://build/performance-baseline-desktop.json"
const DEFAULT_VIEWPORT := Vector2i(430, 932)

var _shell: Control
var _board: Control
var _results: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = DEFAULT_VIEWPORT
	_shell = load("res://scenes/main.tscn").instantiate()
	_shell.set("haptics_enabled_on_start", false)
	root.add_child(_shell)
	await process_frame
	await process_frame
	_board = _shell.get("_regions").board
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	await _wait_frames(30)

	_results.append(await _capture_scenario("idle_fresh_board", 120, Callable()))

	await _restart_and_settle()
	var selection_id := _first_selectable_tile_id()
	_results.append(await _capture_scenario(
		"ordinary_selection",
		75,
		_shell.call.bind("_on_tile_selected", selection_id)
	))

	await _restart_and_settle()
	var pair_ids := _first_selectable_pair()
	if pair_ids.size() == 2:
		_shell.call("_on_tile_selected", pair_ids[0])
		await _wait_frames(24)
		_results.append(await _capture_scenario(
			"natural_pair",
			75,
			_shell.call.bind("_on_tile_selected", pair_ids[1])
		))

	await _restart_and_settle()
	_results.append(await _capture_scenario(
		"hint_glow",
		120,
		_shell.call.bind("_on_hint_requested")
	))

	await _restart_and_settle()
	_results.append(await _capture_scenario(
		"shuffle",
		75,
		_shell.call.bind("_on_shuffle_requested")
	))

	var report := {
		"schema_version": 1,
		"captured_at_utc": Time.get_datetime_string_from_system(true),
		"environment": _environment(),
		"scenarios": _results,
	}
	var output_path := _output_path()
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("ERROR: could not write performance report to %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PERFORMANCE_REPORT=%s" % ProjectSettings.globalize_path(output_path))
	for scenario in _results:
		print(
			"%s: frame p50=%.2fms p95=%.2fms worst=%.2fms action=%.2fms draws=%.1f nodes=%.1f" % [
				scenario.name,
				scenario.frame_ms.p50,
				scenario.frame_ms.p95,
				scenario.frame_ms.max,
				scenario.action_cpu_ms,
				scenario.draw_calls.mean,
				scenario.node_count.mean,
			]
		)
	quit(0)


func _capture_scenario(name: String, frame_count: int, action: Callable) -> Dictionary:
	var counters_before: Dictionary = _board.call("performance_counters")
	var action_cpu_ms := 0.0
	if action.is_valid():
		var action_started := Time.get_ticks_usec()
		action.call()
		action_cpu_ms = float(Time.get_ticks_usec() - action_started) / 1000.0

	var wall_frame_ms: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var render_cpu_ms: Array[float] = []
	var render_gpu_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var rendered_objects: Array[float] = []
	var node_counts: Array[float] = []
	var object_counts: Array[float] = []
	var orphan_counts: Array[float] = []
	var static_memory_bytes: Array[float] = []
	var previous_ticks := Time.get_ticks_usec()
	for _frame in frame_count:
		await process_frame
		var current_ticks := Time.get_ticks_usec()
		wall_frame_ms.append(float(current_ticks - previous_ticks) / 1000.0)
		previous_ticks = current_ticks
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		physics_ms.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		rendered_objects.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		node_counts.append(float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		object_counts.append(float(Performance.get_monitor(Performance.OBJECT_COUNT)))
		orphan_counts.append(float(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
		static_memory_bytes.append(float(Performance.get_monitor(Performance.MEMORY_STATIC)))

	var counters_after: Dictionary = _board.call("performance_counters")
	return {
		"name": name,
		"frames": frame_count,
		"action_cpu_ms": action_cpu_ms,
		"frame_ms": _summarize(wall_frame_ms),
		"process_ms": _summarize(process_ms),
		"physics_ms": _summarize(physics_ms),
		"render_cpu_ms": _summarize(render_cpu_ms),
		"render_gpu_ms": _summarize(render_gpu_ms),
		"draw_calls": _summarize(draw_calls),
		"rendered_objects": _summarize(rendered_objects),
		"node_count": _summarize(node_counts),
		"object_count": _summarize(object_counts),
		"orphan_count": _summarize(orphan_counts),
		"static_memory_bytes": _summarize(static_memory_bytes),
		"frames_over_16_7_ms": _count_over(wall_frame_ms, 16.7),
		"frames_over_33_3_ms": _count_over(wall_frame_ms, 33.3),
		"board_counter_delta": _counter_delta(counters_before, counters_after),
	}


func _summarize(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"min": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0, "mean": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values:
		total += value
	return {
		"min": sorted[0],
		"p50": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"max": sorted[-1],
		"mean": total / float(values.size()),
	}


func _percentile(sorted: Array[float], percentile: float) -> float:
	var index := clampi(ceili(percentile * float(sorted.size())) - 1, 0, sorted.size() - 1)
	return sorted[index]


func _count_over(values: Array[float], threshold: float) -> int:
	var count := 0
	for value in values:
		if value > threshold:
			count += 1
	return count


func _counter_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var delta := {}
	for key in after:
		delta[key] = int(after[key]) - int(before.get(key, 0))
	return delta


func _environment() -> Dictionary:
	return {
		"platform": OS.get_name(),
		"model": OS.get_model_name(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"godot_version": Engine.get_version_info().string,
		"renderer_method": RenderingServer.get_current_rendering_method(),
		"renderer_driver": RenderingServer.get_current_rendering_driver_name(),
		"display_server": DisplayServer.get_name(),
		"viewport": [root.size.x, root.size.y],
		"screen_refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"debug_build": OS.is_debug_build(),
	}


func _first_selectable_tile_id() -> String:
	for tile in _shell.get("_game").board.call("selectable_tiles"):
		return tile.id
	return ""


func _first_selectable_pair() -> Array[String]:
	var selectable: Array = _shell.get("_game").board.call("selectable_tiles")
	for first_index in selectable.size():
		for second_index in range(first_index + 1, selectable.size()):
			var first: Variant = selectable[first_index]
			var second: Variant = selectable[second_index]
			if first.face.logical_id() == second.face.logical_id():
				return [first.id, second.id]
	return []


func _restart_and_settle() -> void:
	_shell.call("_on_restart_requested")
	await _wait_frames(12)
	_board = _shell.get("_regions").board


func _wait_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			return argument.trim_prefix("--output=")
	return DEFAULT_OUTPUT
