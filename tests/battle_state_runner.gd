extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const State := preload("res://scripts/simulation/battle/battle_state.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func command(store: RefCounted, id: String, type: String, side: String, count: int) -> Dictionary:
	return {"id": id, "type": type, "side": side, "pair_count": count, "expected_revision": store.snapshot().revision}


func reject_unchanged(store: RefCounted, input: Dictionary, label: String) -> void:
	var before: Dictionary = store.snapshot()
	var history: Array = store.transactions()
	check(not store.submit(input).accepted, label)
	check(store.snapshot() == before and store.transactions() == history, label + " is atomic")


func run() -> void:
	var definition := Definition.defaults()
	check(Definition.validation_errors(definition).is_empty(), "default configuration validates")
	definition.player_starting_pairs = 4
	definition.cpu_starting_pairs = 6
	var store := Store.new(definition)
	definition.player_starting_pairs = 99
	check(store.snapshot().sides.player.remaining_pairs == 4, "definition is snapshotted")
	check(State.race_position(store.snapshot(), State.PLAYER) == 0.0, "player starts on left")
	check(State.race_position(store.snapshot(), State.CPU) == 1.0, "CPU starts on right")
	for side in [State.PLAYER, State.CPU]:
		check(store.snapshot().sides[side].attack_charge_units == 0, "empty charge: " + side)
		check(store.snapshot().sides[side].pending_attacks.is_empty(), "empty attacks: " + side)
	var first := command(store, "player-1", Store.CLEAR_PAIRS, State.PLAYER, 2)
	var result: Dictionary = store.submit(first)
	check(result.accepted, "player pair clear accepted")
	check(State.progress(store.snapshot(), State.PLAYER) == 0.5, "player progress follows work")
	check(State.race_position(store.snapshot(), State.PLAYER) == 0.25, "player moves toward center")
	check(store.submit(command(store, "cpu-1", Store.CLEAR_PAIRS, State.CPU, 3)).accepted, "independent CPU clear")
	check(State.race_position(store.snapshot(), State.CPU) == 0.75, "CPU moves toward center")
	check(store.submit(command(store, "work-1", Store.ADD_WORK, State.PLAYER, 4)).accepted, "extra workload accepted")
	check(State.progress(store.snapshot(), State.PLAYER) == 0.25, "incoming work moves progress backwards")
	check(store.snapshot().sides.player.remaining_pairs == 6, "incoming work preserves cleared pairs")
	check(store.submit({"id": "stats", "type": Store.SET_STATS, "side": State.PLAYER,
		"expected_revision": 3, "stats": {"score": 1250, "streak": 7, "momentum_units": 25000}}).accepted, "player stats recorded")
	check(store.submit({"id": "cpu-stats", "type": Store.SET_STATS, "side": State.CPU,
		"expected_revision": 4, "stats": {"streak": 2, "momentum_units": 12000}}).accepted, "CPU stats recorded")
	check(store.snapshot().sides.player.score == 1250 and store.snapshot().sides.cpu.streak == 2, "stats remain independent")
	reject_unchanged(store, first, "duplicate event rejected")
	var stale := command(store, "stale", Store.CLEAR_PAIRS, State.PLAYER, 1)
	stale.expected_revision = 0
	reject_unchanged(store, stale, "stale event rejected")
	for amount in [0, -1, 1000000001, 1.5, "1"]:
		var invalid := command(store, "invalid", Store.CLEAR_PAIRS, State.PLAYER, 1)
		invalid.pair_count = amount
		reject_unchanged(store, invalid, "invalid pair count: " + str(amount))
	reject_unchanged(store, command(store, "excess", Store.CLEAR_PAIRS, State.CPU, 4), "cannot over-clear")
	reject_unchanged(store, command(store, "side", Store.CLEAR_PAIRS, "other", 1), "unknown side rejected")
	reject_unchanged(store, command(store, "overflow", Store.ADD_WORK, State.CPU, Definition.MAX_COUNTER), "work arithmetic bounded")
	reject_unchanged(store, {"id": "bad-stats", "type": Store.SET_STATS, "side": State.PLAYER,
		"expected_revision": 5, "stats": {"score": 3, "streak": -1}}, "invalid stats cannot partially apply")
	# Returned records are owned copies, including nested state and commands.
	result.transaction.after.sides.player.remaining_pairs = 0
	var copy: Dictionary = store.snapshot()
	copy.sides.player.pending_attacks.append({"pair_count": 99})
	check(store.snapshot().sides.player.remaining_pairs == 6 and store.snapshot().sides.player.pending_attacks.is_empty(), "returned state cannot mutate the store")
	check(store.submit(command(store, "cpu-win", Store.CLEAR_PAIRS, State.CPU, 3)).accepted, "CPU finish accepted")
	check(store.snapshot().status == State.CPU_WON and store.snapshot().winner == State.CPU, "CPU wins first")
	check(State.race_position(store.snapshot(), State.CPU) == 0.5, "winner reaches center")
	reject_unchanged(store, command(store, "late-player", Store.CLEAR_PAIRS, State.PLAYER, 6), "late finish cannot replace winner")
	reject_unchanged(store, command(store, "late-work", Store.ADD_WORK, State.CPU, 2), "attacks cannot reopen a terminal battle")
	var replay := Store.new(store.definition_snapshot())
	var timeline: Array = store.transactions()
	var tampered: Dictionary = timeline[0].duplicate(true)
	tampered.after.sides.player.score = 999
	check(not replay.apply_transaction(tampered).accepted and replay.snapshot().revision == 0, "tampered replay rejected atomically")
	check(not replay.apply_transaction(timeline[1]).accepted, "out of order replay rejected")
	for transaction in timeline:
		check(replay.apply_transaction(transaction).accepted, "replay accepts valid transaction")
	check(replay.snapshot() == store.snapshot() and replay.transactions() == timeline, "replay reproduces all state and history")
	check(not replay.apply_transaction(timeline[-1]).accepted, "duplicate replay rejected")
	var different := store.definition_snapshot()
	different.seed += 1
	check(not Store.new(different).apply_transaction(timeline[0]).accepted, "definition mismatch rejected")
	var player_wins := Store.new(store.definition_snapshot())
	player_wins.submit(command(player_wins, "finish", Store.CLEAR_PAIRS, State.PLAYER, 4))
	check(player_wins.snapshot().status == State.PLAYER_WON and player_wins.snapshot().winner == State.PLAYER, "player can win independently")
	var cpu_pressure := Store.new(store.definition_snapshot())
	cpu_pressure.submit(command(cpu_pressure, "clear", Store.CLEAR_PAIRS, State.CPU, 3))
	cpu_pressure.submit(command(cpu_pressure, "land", Store.ADD_WORK, State.CPU, 6))
	check(State.progress(cpu_pressure.snapshot(), State.CPU) == 0.25, "CPU attacks use the same workload setback formula")
	check(State.race_position(cpu_pressure.snapshot(), State.CPU) == 0.875, "CPU moves back toward its own endpoint")
	cpu_pressure.submit(command(cpu_pressure, "recover", Store.CLEAR_PAIRS, State.CPU, 9))
	check(cpu_pressure.snapshot().winner == State.CPU, "CPU can finish its increased workload")
	var external_history: Array = store.transactions()
	external_history[0].command.pair_count = 999
	var external_definition: Dictionary = store.definition_snapshot()
	external_definition.seed = 999
	check(store.transactions()[0].command.pair_count == 2 and store.definition_snapshot().seed == 1, "returned timeline and definition are isolated")
	for invalid_definition in [{}, {"rules_version": 9, "seed": 1, "player_starting_pairs": 4, "cpu_starting_pairs": 4},
		{"rules_version": 1, "seed": 1, "player_starting_pairs": 0, "cpu_starting_pairs": 4}]:
		var invalid_store := Store.new(invalid_definition)
		check(not invalid_store.validation_errors().is_empty() and not invalid_store.submit(first).accepted, "invalid definition fails closed")
	print("%s: Battle B1 (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
