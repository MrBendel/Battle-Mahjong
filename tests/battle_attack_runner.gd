extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
const Attacks := preload("res://scripts/simulation/battle/battle_attacks.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func command(store: RefCounted, side: String, count: int, time: int) -> Dictionary:
	var value := {"id": "event_%d" % store.snapshot().revision, "expected_revision": store.snapshot().revision,
		"type": "send_attack" if count != 0 else "advance_attacks", "side": side, "at_ms": time}
	if count != 0:
		value.pair_count = count
	return store.submit(value)

func run() -> void:
	var definition := Definition.defaults()
	definition.rules_version = 6
	definition.erase("cpu_attack_charge_units")
	for source in ["player", "cpu"]:
		var other := "cpu" if source == "player" else "player"
		var store := Store.new(definition)
		check(command(store, other, 3, 0).accepted, "send accepted")
		check(Attacks.pending_pairs(store.snapshot(), source) == 3, "incoming count")
		command(store, source, 2, 100)
		check(Attacks.pending_pairs(store.snapshot(), source) == 1, "partial cancellation")
		check(Attacks.pending_pairs(store.snapshot(), other) == 0, "no outgoing pressure while cancelling")
		command(store, source, 4, 200)
		check(Attacks.pending_pairs(store.snapshot(), source) == 0, "incoming fully cancelled")
		check(Attacks.pending_pairs(store.snapshot(), other) == 3, "excess sent")
		check(store.transactions()[-1].events.size() == 2, "cancel and send recorded together")
		command(store, source, 0, 1199)
		check(store.snapshot().landed_attacks.is_empty(), "warning lasts full delay")
		command(store, source, 0, 1200)
		check(store.snapshot().landed_attacks.size() == 1, "lands exactly at deadline")
		check(store.snapshot().landed_attacks[0].pair_count == 3, "only uncancelled pairs land")
		check(store.snapshot().sides[other].remaining_pairs == 48, "landing awaits later workload milestone")
		command(store, source, 0, 2000)
		check(store.snapshot().landed_attacks.size() == 1, "landing cannot repeat")
		var replay := Store.new(definition)
		for transaction in store.transactions():
			check(replay.apply_transaction(transaction).accepted, "queue transaction replays")
		check(replay.snapshot() == store.snapshot(), "replay state identical")
		var tampered: Dictionary = store.transactions()[1].duplicate(true)
		tampered.events[0].pair_count += 1
		var victim := Store.new(definition)
		victim.apply_transaction(store.transactions()[0])
		check(not victim.apply_transaction(tampered).accepted, "tampered cancellation rejected")
	var fifo := Store.new(definition)
	command(fifo, "cpu", 2, 0)
	command(fifo, "cpu", 3, 100)
	command(fifo, "player", 3, 200)
	check(fifo.snapshot().sides.player.pending_attacks.size() == 1, "oldest attack removed first")
	check(fifo.snapshot().sides.player.pending_attacks[0].created_at_ms == 100, "partial later attack preserves timestamp")
	check(fifo.snapshot().sides.player.pending_attacks[0].pair_count == 2, "cancellation spans queue entries")
	command(fifo, "player", 2, 1100)
	check(fifo.snapshot().landed_attacks[0].pair_count == 2, "exact-deadline attack already landed")
	check(Attacks.pending_pairs(fifo.snapshot(), "cpu") == 2, "deadline outgoing cannot cancel landed attack")
	var before := fifo.snapshot()
	check(not command(fifo, "cpu", 1, 1099).accepted and fifo.snapshot() == before, "stale clock rejected atomically")
	check(not command(fifo, "cpu", -1, 5000).accepted and fifo.snapshot() == before, "invalid send cannot commit due landings")
	# Charge crossings use precisely the same cancellation reducer.
	var charged := Store.new(definition)
	command(charged, "cpu", 2, 0)
	var event := {"source_hash": "board", "source_revision": 1, "at_ms": 100, "pair_count": 1,
		"natural_pairs": 1, "score": 100, "streak": 1, "momentum_units": 0, "momentum_tier": 1, "cleared_layers": [0, 1]}
	check(charged.submit({"id": "match", "expected_revision": 1, "type": "player_event", "side": "player", "event": event}).accepted, "charge event accepted")
	check(Attacks.pending_pairs(charged.snapshot(), "player") == 1, "charge cancels incoming")
	check(charged.snapshot().sides.player.attack_charge_units == 1000, "charge overflow survives cancellation")
	var coarse := Store.new(definition)
	var fine := Store.new(definition)
	for store in [coarse, fine]:
		command(store, "player", 1, 0)
		command(store, "player", 2, 10)
	command(coarse, "cpu", 0, 2000)
	for time in [500, 1000, 1009, 1010, 2000]:
		command(fine, "cpu", 0, time)
	check(coarse.snapshot().landed_attacks == fine.snapshot().landed_attacks, "clock granularity preserves landing order and deadlines")
	var custom := definition.duplicate(true)
	custom.attacks.delay_ms = 2500
	var tuned := Store.new(custom)
	custom.attacks.delay_ms = 1
	command(tuned, "player", 1, 10)
	check(tuned.snapshot().sides.cpu.pending_attacks[0].lands_at_ms == 2510, "custom delay is snapshotted")
	var duplicate: Dictionary = tuned.transactions()[0].command
	before = tuned.snapshot()
	check(not tuned.submit(duplicate).accepted and tuned.snapshot() == before, "duplicate send cannot generate pressure")
	var near_limit := Store.new(definition)
	before = near_limit.snapshot()
	check(not command(near_limit, "cpu", 1, Attacks.MAX_TIME_MS).accepted and near_limit.snapshot() == before, "deadline overflow rejected atomically")
	var bad := definition.duplicate(true)
	bad.attacks.delay_ms = 0
	check(not Definition.validation_errors(bad).is_empty(), "instant attack rejected")
	bad.attacks.delay_ms = 60001
	check(not Definition.validation_errors(bad).is_empty(), "unbounded delay rejected")
	var legacy := definition.duplicate(true)
	legacy.rules_version = 3
	legacy.erase("cpu_attack_charge_units")
	legacy.erase("attacks")
	legacy.erase("payload")
	legacy.erase("insertion")
	check(not command(Store.new(legacy), "cpu", 1, 0).accepted, "legacy replay cannot send new attack commands")
	var terminal := Store.new(definition)
	command(terminal, "cpu", 1, 0)
	terminal.submit({"id": "win", "expected_revision": 1, "type": "clear_pairs", "side": "player", "pair_count": 48})
	before = terminal.snapshot()
	check(not command(terminal, "cpu", 0, 1000).accepted and terminal.snapshot() == before, "victory freezes in-flight attacks")
	print("Battle B4: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
