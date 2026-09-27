extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
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


func fixed_definition() -> Dictionary:
	var definition := Definition.defaults()
	definition.cpu_starting_pairs = 600
	definition.cpu.variance_ms = 0
	definition.cpu.streak_chance_bp = 0
	definition.cpu.pause_chance_bp = 0
	definition.cpu.base_interval_ms = 1000
	return definition


func run() -> void:
	var definition := Definition.defaults()
	var store := Store.new(definition)
	var driver := Driver.new(store)
	var first: int = store.snapshot().cpu_schedule.next_event_ms
	check(driver.advance_to(first - 1).events.is_empty(), "no event before deadline")
	check(driver.advance_to(first).events.size() == 1, "one event at exact deadline")
	var snapshot := store.snapshot()
	check(driver.advance_to(first).events.is_empty() and store.snapshot() == snapshot, "same horizon cannot double count")
	check(not driver.advance_to(-1).accepted, "negative time rejected")
	check(not driver.advance_to(first - 1).accepted, "time before committed CPU event rejected")
	var invalid := {"id": "early", "expected_revision": snapshot.revision, "type": "cpu_step", "side": "cpu", "at_ms": first}
	check(not store.submit(invalid).accepted and store.snapshot() == snapshot, "early CPU command rejected atomically")
	# Neither frame rate nor catch-up chunk size changes the event timeline.
	var small := Store.new(definition)
	var small_driver := Driver.new(small)
	for time in range(0, 180001, 17):
		small_driver.advance_to(time)
	small_driver.advance_to(180000)
	var large := Store.new(definition)
	var large_driver := Driver.new(large)
	while large_driver.advance_to(180000).get("pending", false):
		pass
	check(small.snapshot() == large.snapshot(), "small and large clock steps produce identical state")
	check(small.transactions() == large.transactions(), "small and large clock steps produce identical transactions")
	check(large.snapshot().winner == "cpu", "default CPU completes its workload")
	var finished := large.snapshot()
	check(large_driver.advance_to(200000).events.is_empty() and large.snapshot() == finished, "CPU stops at victory")
	var replay := Store.new(definition)
	for transaction in large.transactions():
		check(replay.apply_transaction(transaction).accepted, "seeded CPU transaction replays")
	check(replay.snapshot() == finished, "replay reproduces RNG, scheduler, and outcome")
	var tampered: Dictionary = large.transactions()[0].duplicate(true)
	tampered.after.cpu_schedule.rng_state += 1
	check(not Store.new(definition).apply_transaction(tampered).accepted, "tampered RNG rejected")
	var changed := definition.duplicate(true)
	changed.seed += 31
	check(Store.new(changed).snapshot().cpu_schedule != Store.new(definition).snapshot().cpu_schedule, "different seed changes schedule")
	var intervals := {}
	var previous := 0
	for transaction in large.transactions():
		var time: int = transaction.command.at_ms
		intervals[time - previous] = true
		previous = time
	check(intervals.size() > 3, "CPU intervals vary")
	# Difficulty modifies actual solve cadence, not progress arithmetic.
	var easy_definition := fixed_definition()
	var hard_definition := easy_definition.duplicate(true)
	hard_definition.cpu.difficulty_bp = 20000
	var easy := Store.new(easy_definition)
	var hard := Store.new(hard_definition)
	Driver.new(easy).advance_to(10000)
	Driver.new(hard).advance_to(10000)
	check(easy.snapshot().sides.cpu.cleared_pairs == 10 and hard.snapshot().sides.cpu.cleared_pairs == 20, "difficulty controls solve speed")
	# Forced pauses exercise recovery and guarantee eventual forward progress.
	var pauses := fixed_definition()
	pauses.cpu.pause_chance_bp = 10000
	pauses.cpu.pause_ms = 2000
	pauses.cpu.recovery_rate_bp = 20000
	var recovering := Store.new(pauses)
	var recovery_driver := Driver.new(recovering)
	recovery_driver.advance_to(1000)
	check(recovering.snapshot().sides.cpu.cleared_pairs == 0 and recovering.snapshot().cpu_schedule.mode == "recovering", "mistake pauses instead of clearing")
	check(recovering.snapshot().sides.cpu.streak == 0, "mistake resets streak")
	recovery_driver.advance_to(2000)
	check(recovering.snapshot().sides.cpu.cleared_pairs == 1, "recovery rate controls delayed solve")
	var bursts := fixed_definition()
	bursts.cpu.streak_chance_bp = 10000
	bursts.cpu.streak_speed_bp = 20000
	var streak := Store.new(bursts)
	Driver.new(streak).advance_to(1500)
	check(streak.snapshot().sides.cpu.cleared_pairs == 3 and streak.snapshot().sides.cpu.streak == 3, "streak bursts accelerate solves")
	check(streak.snapshot().sides.cpu.momentum_units == 10000, "CPU burst momentum is exposed")
	var capped := Store.new(fixed_definition())
	var cap_driver := Driver.new(capped)
	var batch := cap_driver.advance_to(300000)
	check(batch.events.size() == 128 and batch.pending, "large catch-up work is bounded")
	while batch.pending:
		batch = cap_driver.advance_to(300000)
	check(capped.snapshot().sides.cpu.cleared_pairs == 300, "catch-up never discards CPU events")
	var interrupted := Store.new(definition)
	interrupted.submit({"id": "player-finishes", "expected_revision": 0, "type": "clear_pairs", "side": "player", "pair_count": 48})
	check(Driver.new(interrupted).advance_to(180000).events.is_empty() and interrupted.snapshot().winner == "player", "player victory stops CPU")
	var legacy := {"rules_version": 1, "seed": 1, "player_starting_pairs": 4, "cpu_starting_pairs": 4}
	check(not Driver.new(Store.new(legacy)).advance_to(1000).accepted, "B1 definitions have no implicit CPU")
	for override in [{"variance_ms": 2500}, {"streak_chance_bp": 10001}, {"difficulty_bp": 0}, {"pause_ms": -1}, {"base_interval_ms": 1.5}]:
		var invalid_definition := definition.duplicate(true)
		invalid_definition.cpu.merge(override, true)
		check(not Definition.validation_errors(invalid_definition).is_empty(), "invalid CPU tuning rejected")
	definition.cpu.difficulty_bp = 40000
	check(store.definition_snapshot().cpu.difficulty_bp == 10000, "CPU tuning snapshot cannot change mid-battle")
	print("%s: Battle B2 (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
