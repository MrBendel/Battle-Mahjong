extends SceneTree
const Host := preload("res://scripts/simulation/battle/battle_host.gd")
const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const GameDefinition := preload("res://scripts/simulation/game_definition.gd")
const Tile := preload("res://scripts/simulation/tile_instance.gd")
const Face := preload("res://scripts/simulation/tile_face.gd")
const Position := preload("res://scripts/simulation/board_position.gd")
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _init() -> void:
	var game := GameDefinition.new(42, [Tile.new("a", Face.new("bamboo", "1"), Position.new(0, 0, 0)),
		Tile.new("b", Face.new("bamboo", "1"), Position.new(4, 0, 0))], {})
	var tuning := Definition.defaults()
	tuning.player_starting_pairs = 1
	tuning.cpu_starting_pairs = 20
	tuning.cpu.base_interval_ms = 1000
	tuning.cpu.variance_ms = 0
	tuning.cpu.pause_chance_bp = 0
	tuning.cpu.streak_chance_bp = 0
	var fine := Host.new(tuning, game)
	var coarse := Host.new(tuning, game)
	check(fine.store != null, "host binds board")
	for time in range(0, 5100, 100):
		check(fine.advance_to(time).accepted, "small clock advance")
	check(coarse.advance_to(5000).accepted, "coarse advance")
	check(fine.store.transactions() == coarse.store.transactions(), "host clock granularity deterministic")
	var state: Dictionary = fine.store.snapshot()
	check(state.player_board.applied_attacks.size() == 1, "automatic CPU attack lands and inserts")
	check(state.player_board.definition.tiles.size() == 4, "CPU pressure creates real pair")
	check(state.sides.cpu.attack_charge_units == 1000, "CPU charge remainder")
	var rejected := Host.new(tuning, game)
	var rejected_result: Dictionary = rejected.tap("missing", 5000)
	check(not rejected_result.accepted, "missing tile rejected")
	check(rejected_result.events.any(func(event: Dictionary) -> bool: return event.type == "attack_inserted"), "rejected tap preserves committed deadline presentation")
	check(rejected.advance_to(5000).events.is_empty(), "deadline presentation delivered only once")
	var count: int = fine.store.transactions().size()
	fine.advance_to(5000)
	check(fine.store.transactions().size() == count, "same clock cannot double count")
	check(not fine.advance_to(4999).accepted, "backdated host time rejected")
	var timed := Host.new(tuning, game)
	check(timed.tap("a", 1000).accepted, "tap coordinated with due CPU step")
	check(timed.store.transactions()[1].command.type == "cpu_step", "CPU input wins exact tie")
	check(timed.tap("b", 1001).accepted, "normal matching input")
	check(timed.store.snapshot().winner == "player", "player can win through host")
	var invalid := Host.new(tuning, game, ["a", "missing"])
	check(invalid.store == null, "supplied route must verify")
	var pause_tuning := tuning.duplicate(true)
	pause_tuning.cpu.pause_chance_bp = 10000
	var resting := Host.new(pause_tuning, game)
	resting.advance_to(1000)
	check(resting.store.snapshot().sides.cpu.attack_charge_units == 0, "CPU mistakes generate no attack charge")
	var tiles: Array = game.tiles.duplicate()
	for z in 2:
		for x in [8, 12]:
			tiles.append(Tile.new("stack_%d_%d" % [x, z], Face.new("bamboo", str(z + 2)), Position.new(x, 0, z)))
	var stacked := GameDefinition.new(42, tiles, {})
	var stack_tuning := tuning.duplicate(true)
	stack_tuning.player_starting_pairs = 3
	var locked := Host.new(stack_tuning, stacked)
	locked.tap("a", 0)
	locked.tap("b", 1)
	check(locked.store.snapshot().sides.player.streak == 1, "natural pair starts Combo")
	check(locked.tap("stack_8_0", 2).accepted and locked.store.snapshot().sides.player.streak == 0, "locked tile breaks Combo through ordinary rules")
	print("Battle host failures: %d" % failures)
	quit(failures)
