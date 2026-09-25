extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(430, 932)
	var shell = load("res://scenes/game_shell.tscn").instantiate()
	shell.show_layout_generator_on_start = false
	shell.show_modifier_picker_on_start = false
	shell.flipped_tile_count = 0
	root.add_child(shell)
	await process_frame
	var game = shell.get("_game")
	var pair: Array = []
	var by_face := {}
	for tile in game.board.call("selectable_tiles"):
		var face: String = tile.face.logical_id()
		if by_face.has(face):
			pair = [by_face[face], tile]
			break
		by_face[face] = tile
	check(pair.size() == 2, "fixture requires a selectable pair")
	if pair.size() != 2:
		quit(1)
		return
	# Author one visible flipped tile before play. Holding its mate triggers
	# the rules-20 last-face-down cleanup reveal through a real transaction.
	game.definition.flipped_tile_ids.append(pair[0].id)
	shell.call("_refresh_game_views")
	shell.call("_on_tile_selected", pair[1].id)
	await create_timer(0.35).timeout
	check(game.board.call("is_tile_revealed_flipped", pair[0].id), "cleanup reveals the held tile's mate")
	var motions: int = shell.get("_tile_motion_count")
	var impacts: int = shell.get("_pair_feedback_count")
	shell.call("_on_tile_selected", pair[0].id)
	check(game.call("last_transaction").result == "pair_resolved", "already revealed tile resolves as an ordinary pair")
	check(shell.get("_tile_motion_count") == motions + 1, "already revealed mate must animate into the tray")
	check(shell.get("_pair_feedback_count") == impacts, "impact waits for the arrival animation")
	await create_timer(0.65).timeout
	check(shell.get("_pair_feedback_count") == impacts + 1, "pair reaches the shared impact and sound path exactly once")
	shell.queue_free()
	await process_frame
	print("PASS: revealed tray pair presentation" if failures == 0 else "FAIL: revealed tray pair presentation")
	quit(0 if failures == 0 else 1)
