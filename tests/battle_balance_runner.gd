extends SceneTree
const Probe := preload("res://scripts/tools/battle_balance_probe.gd")
const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Game := preload("res://scripts/simulation/game_definition.gd")
const Tile := preload("res://scripts/simulation/tile_instance.gd")
const Face := preload("res://scripts/simulation/tile_face.gd")
const Position := preload("res://scripts/simulation/board_position.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _init() -> void:
	var base := Definition.defaults()
	check(base == Definition.from_json_file(Definition.DEFAULT_PATH), "selected tuning file uses normalized defaults")
	check(not Definition.validation_errors(Definition.from_json_file("res://configuration/battle/balance_scenarios.json")).is_empty(), "scenario files cannot masquerade as battle definitions")
	var tuning := Probe.tuning_for(base, {"player_starting_pairs": 2, "cpu_starting_pairs": 2,
		"cpu": {"base_interval_ms": 2000, "variance_ms": 0, "streak_chance_bp": 0, "pause_chance_bp": 0}})
	check(base.player_starting_pairs == 48 and base.cpu.base_interval_ms == 2500, "variant overrides never mutate defaults")
	var tiles: Array = []
	for i in 4:
		tiles.append(Tile.new(str(i), Face.new("bamboo", str(i / 2 + 1)), Position.new(i * 4, 0, 0)))
	# Use explicit same-face pairs, independent of integer-division formatting.
	tiles[1] = Tile.new("1", tiles[0].face, Position.new(4, 0, 0))
	tiles[3] = Tile.new("3", tiles[2].face, Position.new(12, 0, 0))
	var generated := {"definition": Game.new(42, tiles, {}), "solution": ["0", "1", "2", "3"]}
	var fast := Probe.run(tuning, generated, 400, 10000)
	check(not fast.has("error") and fast.winner == "player" and fast.duration_ms == 1600, "fixed-cadence ordinary taps finish actual board")
	check(fast == Probe.run(tuning, generated, 400, 10000), "identical seed and cadence give identical metrics")
	var slow := Probe.run(tuning, generated, 2500, 10000)
	check(not slow.has("error") and slow.winner == "cpu", "slow player loses to scheduled CPU")
	var timed := Probe.run(tuning, generated, 400, 500)
	check(timed.winner == "timeout" and timed.duration_ms == 500, "horizon is bounded")
	check(Probe.run(tuning, generated, 0, 10000).has("error"), "invalid cadence rejects instead of looping")
	print("Battle balance failures: %d" % failures)
	quit(failures)
