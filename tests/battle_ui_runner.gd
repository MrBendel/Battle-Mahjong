extends SceneTree
const Shell := preload("res://scripts/presentation/battle_shell.gd")
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	root.size = Vector2i(390, 844)
	var shell := Shell.new()
	shell.seed = 42
	root.add_child(shell)
	var deadline := Time.get_ticks_msec() + 60000
	while shell.snapshot.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not shell.snapshot.is_empty(), "Battle prepares")
	if shell.snapshot.is_empty():
		quit(1)
		return
	shell.pause_battle()
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568)]:
		root.size = dimensions
		shell.safe_area_override = Rect2(8, 24, 8, 16)
		await process_frame
		shell._layout()
		for control in [shell._hud, shell._board, shell._tray, shell._pause, shell._character]:
			check(control.position.x >= 8 and control.position.y >= 24, "safe top/left")
			check(control.get_rect().end.x <= dimensions.x - 8 + 1 and control.get_rect().end.y <= dimensions.y - 16 + 1, "safe bottom/right")
		check(not shell._board.get_rect().intersects(shell._tray.get_rect()), "tray and board do not overlap")
		check(not shell._hud.get_rect().intersects(shell._board.get_rect()), "HUD and board do not overlap")
		shell._overlay.show_message("YOU WIN!", false)
		shell._overlay.show_reaction(shell._character._frustrated, "Not bad... for now.")
		await process_frame
		await process_frame
		var panel: Rect2 = shell._overlay._panel.get_rect()
		check(panel.position.y >= 24 and panel.end.y <= dimensions.y - 16 + 1, "result character fits safe display %s %s" % [dimensions, panel])
		shell._overlay.clear_reaction()
		shell._overlay.show_message("BATTLE PAUSED", true)
		for control in [shell._board, shell._tray, shell._pause]:
			check(not shell._character.get_rect().intersects(control.get_rect()), "character leaves important regions clear")
		var stable_rects := [shell._hud.get_rect(), shell._board.get_rect(), shell._tray.get_rect()]
		shell._character.reset()
		shell._character.consume([{"type": "character_reaction", "cue": "cpu_big_attack", "revision": 1}])
		shell._character._process(0.3)
		shell._layout()
		check(stable_rects == [shell._hud.get_rect(), shell._board.get_rect(), shell._tray.get_rect()], "cut-in never shifts HUD, Board, or tray")
	var before: Dictionary = shell.snapshot.duplicate(true)
	await create_timer(0.1).timeout
	check(shell.snapshot == before, "paused battle remains unchanged")
	shell._overlay.resumed.emit()
	var tile_id: String = shell.snapshot.player_board.route[0]
	var revision: int = shell.snapshot.player_board.state.revision
	shell._dispatch(tile_id)
	deadline = Time.get_ticks_msec() + 60000
	while shell._thread != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(shell.snapshot.player_board.state.revision > revision, "visible tile input commits through host")
	shell._active_ms = 20000
	shell._dispatch("")
	deadline = Time.get_ticks_msec() + 60000
	while shell._thread != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not shell.snapshot.player_board.applied_attacks.is_empty(), "live CPU attack reaches presentation")
	check(shell._board.get("_tile_buttons").size() == shell.snapshot.player_board.definition.tiles.size(), "new attack tiles receive board controls")
	shell.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(shell._paused and shell._overlay.visible, "focus loss requires resume")
	if DisplayServer.get_name() != "headless":
		for dimensions in [Vector2i(390, 844), Vector2i(844, 390)]:
			root.size = dimensions
			shell._overlay.hide()
			shell._fx.clear()
			shell._character.reset()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/battle-idle-%dx%d.png" % [dimensions.x, dimensions.y])
			shell._character.reset()
			shell._character.consume([{"type": "character_reaction", "cue": "cpu_big_attack", "revision": 1}])
			shell._character.age = 0.3
			shell._character.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/battle-%dx%d.png" % [dimensions.x, dimensions.y])
	var old_seed := shell.seed
	shell._overlay.restarted.emit()
	await process_frame
	deadline = Time.get_ticks_msec() + 60000
	while (shell.seed == old_seed or shell._thread != null or shell.snapshot.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(shell.seed == old_seed + 1 and not shell.snapshot.is_empty(), "New Battle binds fresh seed")
	shell.queue_free()
	await process_frame
	print("Battle UI failures: %d" % failures)
	quit(failures)
