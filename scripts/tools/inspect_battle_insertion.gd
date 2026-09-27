extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
const Factory := preload("res://scripts/simulation/reference_game_factory.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var tuning := Definition.defaults()
	if not args.is_empty():
		if not args[0].is_valid_int():
			push_error("Usage: inspect_battle_insertion.gd -- [seed]")
			quit(1)
			return
		tuning.seed = int(args[0])
	var game: Variant = Factory.new().create_definition(tuning.seed)
	var store := Store.new(tuning)
	var commands := [
		{"id": "bind", "expected_revision": 0, "type": "bind_board", "side": "player", "game_definition": game.to_dict()},
		{"id": "send", "expected_revision": 1, "type": "send_attack", "side": "cpu", "pair_count": 1, "at_ms": 0},
		{"id": "land", "expected_revision": 2, "type": "advance_attacks", "side": "player", "at_ms": tuning.attacks.delay_ms},
	]
	for command in commands:
		var result := store.submit(command)
		if not result.accepted:
			push_error(str(result))
			quit(1)
			return
		for event in result.transaction.events:
			if event.type == "attack_inserted":
				print(JSON.stringify({"attack_id": event.attack_id, "placements": event.placements,
					"certified_route_tiles": event.route.size()}, "  "))
	var state := store.snapshot()
	print("Battle: %s; player pairs remaining: %d; board definitions: %d" % [state.status,
		state.sides.player.remaining_pairs, state.player_board.definition.tiles.size()])
	quit(0 if state.player_board.applied_attacks.size() == 1 else 1)
