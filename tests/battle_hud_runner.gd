extends SceneTree
const Hud := preload("res://scripts/presentation/battle_hud.gd")
const State := preload("res://scripts/simulation/battle/battle_state.gd")
const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var hud := Hud.new()
	hud.gameplay_theme = preload("res://configuration/default_gameplay_theme.tres")
	root.add_child(hud)
	for dimensions in [Vector2(330, 88), Vector2(760, 88)]:
		hud.size = dimensions
		var state := State.initial(Definition.defaults())
		for progress in [0, 24, 48]:
			for side in ["player", "cpu"]:
				state.sides[side].cleared_pairs = progress
				state.sides[side].remaining_pairs = 48 - progress
			hud.refresh(state, 4000)
			var player := hud.race_anchor("player")
			var cpu := hud.race_anchor("cpu")
			check(is_equal_approx(player.x + cpu.x, dimensions.x), "race progress markers are symmetric")
			check(player.x < dimensions.x / 2 and cpu.x > dimensions.x / 2, "markers converge on finish without crossing")
			state.sides.player.attack_charge_units = 3000
			hud.refresh(state, 4000)
			check(player == hud.race_anchor("player") and cpu == hud.race_anchor("cpu"), "charge cannot move race markers")
	check(hud._number(12450) == "12,450", "score grouping")
	hud.queue_free()
	await process_frame
	print("Battle HUD failures: %d" % failures)
	quit(failures)
