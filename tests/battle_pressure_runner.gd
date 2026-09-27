extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
const State := preload("res://scripts/simulation/battle/battle_state.gd")
const Driver := preload("res://scripts/simulation/battle/battle_cpu_driver.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func submit(store: RefCounted, type: String, side: String, fields: Dictionary) -> Dictionary:
	var command := {"id": "test_%d" % store.snapshot().revision, "expected_revision": store.snapshot().revision, "type": type, "side": side}
	command.merge(fields)
	return store.submit(command)

func run() -> void:
	var definition := Definition.defaults()
	definition.attacks.delay_ms = 1000 # Fixed deadline fixture, independent of playtest tuning.
	definition.cpu_starting_pairs = 3
	definition.cpu.base_interval_ms = 1000
	definition.cpu.variance_ms = 0
	definition.cpu.pause_chance_bp = 0
	definition.cpu.streak_chance_bp = 0
	var store := Store.new(definition)
	var driver := Driver.new(store)
	driver.advance_to(1000)
	var before := store.snapshot()
	check(submit(store, "send_attack", "player", {"pair_count": 3, "at_ms": 1000}).accepted, "send player attack")
	check(store.snapshot().sides.cpu.remaining_pairs == 2, "warning does not add work early")
	submit(store, "advance_attacks", "player", {"at_ms": 1999})
	check(store.snapshot().sides.cpu.remaining_pairs == 2, "full warning honored")
	var landing := submit(store, "advance_attacks", "player", {"at_ms": 2000})
	check(landing.accepted, "pressure lands")
	check(store.snapshot().sides.cpu.remaining_pairs == 5, "three pairs add three work units")
	check(State.progress(store.snapshot(), "cpu") < State.progress(before, "cpu"), "CPU progress moves backward")
	check(State.race_position(store.snapshot(), "cpu") > State.race_position(before, "cpu"), "CPU marker retreats from center")
	check(store.snapshot().cpu_schedule == before.cpu_schedule, "pressure preserves schedule and RNG")
	check(store.snapshot().sides.cpu.cleared_pairs == 1, "pressure preserves completed work")
	check(landing.transaction.events[-1].type == "cpu_pressure_applied", "pressure event available to future HUD")
	submit(store, "advance_attacks", "player", {"at_ms": 2000})
	check(store.snapshot().sides.cpu.remaining_pairs == 5, "landing applies once")
	check(driver.advance_to(6000).accepted, "CPU continues solving larger workload")
	check(store.snapshot().winner == "cpu" and store.snapshot().sides.cpu.cleared_pairs == 6, "CPU recovers and wins after all added work")
	var replay := Store.new(definition)
	for transaction in store.transactions():
		check(replay.apply_transaction(transaction).accepted, "pressure history replays")
	check(replay.snapshot() == store.snapshot(), "replay preserves pressure and outcome")
	var victim := Store.new(definition)
	for transaction in store.transactions():
		if transaction.command.id == landing.transaction.command.id:
			var tampered: Dictionary = transaction.duplicate(true)
			tampered.after.sides.cpu.remaining_pairs += 1
			check(not victim.apply_transaction(tampered).accepted, "tampered pressure rejected")
			break
		victim.apply_transaction(transaction)
	# Cancellation removes pressure before it can land.
	var cancelled := Store.new(definition)
	submit(cancelled, "send_attack", "player", {"pair_count": 3, "at_ms": 0})
	submit(cancelled, "send_attack", "cpu", {"pair_count": 2, "at_ms": 100})
	submit(cancelled, "advance_attacks", "player", {"at_ms": 1000})
	check(cancelled.snapshot().sides.cpu.remaining_pairs == 4, "only surviving pair adds work")
	var exact := definition.duplicate(true)
	exact.cpu_starting_pairs = 1
	var finish := Store.new(exact)
	submit(finish, "send_attack", "player", {"pair_count": 1, "at_ms": 0})
	Driver.new(finish).advance_to(1000)
	check(finish.snapshot().status == "playing" and finish.snapshot().sides.cpu.remaining_pairs == 1, "due pressure precedes same-time finishing solve")
	Driver.new(finish).advance_to(2000)
	check(finish.snapshot().winner == "cpu", "CPU wins on subsequent solve")
	var frozen := finish.snapshot()
	check(not submit(finish, "send_attack", "player", {"pair_count": 1, "at_ms": 2000}).accepted and finish.snapshot() == frozen, "terminal battle cannot be revived")
	var legacy := definition.duplicate(true)
	legacy.rules_version = 6
	legacy.erase("cpu_attack_charge_units")
	var old := Store.new(legacy)
	submit(old, "send_attack", "player", {"pair_count": 3, "at_ms": 0})
	submit(old, "advance_attacks", "player", {"at_ms": 1000})
	check(old.snapshot().sides.cpu.remaining_pairs == 3 and not old.snapshot().has("cpu_applied_attacks"), "rules 6 retain handoff-only landing")
	var capped := definition.duplicate(true)
	capped.cpu_starting_pairs = Definition.MAX_COUNTER
	var limit := Store.new(capped)
	submit(limit, "send_attack", "player", {"pair_count": 1, "at_ms": 0})
	before = limit.snapshot()
	check(not submit(limit, "advance_attacks", "player", {"at_ms": 1000}).accepted and limit.snapshot() == before, "work limit rolls back landing atomically")
	var charged := Store.new(definition)
	var event := {"source_hash": "board", "source_revision": 1, "at_ms": 0,
		"pair_count": 1, "natural_pairs": 1, "score": 100, "streak": 1,
		"momentum_units": 0, "momentum_tier": 1, "cleared_layers": [0, 1]}
	check(submit(charged, "player_event", "player", {"event": event}).accepted, "natural match generates attack")
	submit(charged, "advance_attacks", "player", {"at_ms": 1000})
	check(charged.snapshot().sides.cpu.remaining_pairs == 4, "charge-generated attack delivers workload")
	check(charged.snapshot().sides.player.attack_charge_units == 1000, "delivery preserves player overflow charge")
	var fine := Store.new(definition)
	var coarse := Store.new(definition)
	for target in [fine, coarse]:
		submit(target, "send_attack", "player", {"pair_count": 2, "at_ms": 0})
	for time in range(0, 6001, 100):
		Driver.new(fine).advance_to(time)
	Driver.new(coarse).advance_to(6000)
	check(fine.transactions() == coarse.transactions(), "CPU polling granularity preserves pressure timeline")
	print("Battle B7: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
