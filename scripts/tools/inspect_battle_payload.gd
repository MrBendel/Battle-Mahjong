extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")

func _init() -> void:
	var definition := Definition.defaults()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if not args[0].is_valid_int():
			push_error("Usage: inspect_battle_payload.gd -- [seed]")
			quit(1)
			return
		definition.seed = int(args[0])
	var store := Store.new(definition)
	var result := store.submit({"id": "preview", "expected_revision": 0,
		"type": "send_attack", "side": "player", "pair_count": 6, "at_ms": 0})
	if not result.accepted:
		push_error(str(result))
		quit(1)
		return
	print(JSON.stringify(store.snapshot().sides.cpu.pending_attacks[0], "  "))
	quit(0)
