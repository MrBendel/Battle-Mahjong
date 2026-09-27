extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const State := preload("res://scripts/simulation/battle/battle_state.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
const Driver := preload("res://scripts/simulation/battle/battle_cpu_driver.gd")


func _init() -> void:
	var definition := Definition.defaults()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		definition.seed = int(args[0])
	var store := Store.new(definition)
	var driver := Driver.new(store)
	for second in range(601):
		var result := driver.advance_to(second * 1000)
		if not result.accepted:
			push_error(str(result))
			quit(1)
			return
		if not result.events.is_empty():
			var state := store.snapshot()
			print("%3ds CPU: %2d pairs left | progress %.1f%% | %s | streak %d" % [second,
				state.sides.cpu.remaining_pairs, State.progress(state, "cpu") * 100.0,
				state.cpu_schedule.mode, state.sides.cpu.streak])
		if store.snapshot().status != "playing":
			print("Winner: ", store.snapshot().winner)
			quit()
			return
	push_error("CPU did not finish in the 600-second debug horizon.")
	quit(1)
