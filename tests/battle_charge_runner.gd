extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
const Charge := preload("res://scripts/simulation/battle/battle_charge.gd")
const Adapter := preload("res://scripts/simulation/battle/battle_player_adapter.gd")
const Factory := preload("res://scripts/simulation/reference_game_factory.gd")
const Game := preload("res://scripts/simulation/game_state.gd")
const Solver := preload("res://scripts/simulation/game_solver.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func event(store: RefCounted, overrides: Dictionary = {}) -> Dictionary:
	var revision: int = store.snapshot().player_charge.source_revision + 1
	var value := {"source_hash": "test", "source_revision": revision, "at_ms": revision * 2000,
		"pair_count": 1, "natural_pairs": 1, "score": 100, "streak": revision,
		"momentum_units": 0, "momentum_tier": 1, "cleared_layers": []}
	value.merge(overrides, true)
	return value

func submit(store: RefCounted, value: Dictionary) -> Dictionary:
	return store.submit({"id": "event_%d" % value.source_revision,
		"expected_revision": store.snapshot().revision, "type": "player_event", "side": "player", "event": value})

func run() -> void:
	var definition := Definition.defaults()
	definition.rules_version = 3
	definition.erase("cpu_attack_charge_units")
	definition.erase("attacks")
	definition.erase("payload")
	definition.erase("insertion")
	var store := Store.new(definition)
	check(submit(store, event(store)).accepted, "normal pair accepted")
	check(store.snapshot().sides.player.attack_charge_units == 1000, "normal pair charge")
	check(is_equal_approx(Charge.normalized(store.snapshot(), definition.charge), 0.25), "normalized charge")
	check(submit(store, event(store)).accepted, "fast pair at inclusive boundary")
	check(store.snapshot().sides.player.attack_charge_units == 2500, "fast bonus")
	submit(store, event(store))
	check(store.snapshot().sides.player.attack_charge_units == 0, "exact threshold consumed")
	check(store.snapshot().sides.cpu.pending_attacks[0].pair_count == 1, "attack queued for opponent")
	check(store.snapshot().sides.cpu.remaining_pairs == definition.cpu_starting_pairs, "queue does not land early")
	submit(store, event(store, {"cleared_layers": [1, 2], "momentum_tier": 4}))
	check(store.snapshot().sides.player.attack_charge_units == 2500, "bonus overflow retained")
	submit(store, event(store, {"cleared_layers": [1, 2], "momentum_tier": 4}))
	check(store.snapshot().sides.player.attack_charge_units == 0, "layer and momentum bonuses cannot repeat")
	var replay := Store.new(definition)
	for transaction in store.transactions():
		check(replay.apply_transaction(transaction).accepted, "charge transaction replays")
	check(replay.snapshot() == store.snapshot(), "complete charge replay identical")
	var tampered: Dictionary = store.transactions()[0].duplicate(true)
	tampered.after.sides.player.attack_charge_units += 1
	check(not Store.new(definition).apply_transaction(tampered).accepted, "tampered charge rejected")
	for overrides in [{"source_hash": "other"}, {"source_revision": 99}, {"at_ms": 0},
		{"cleared_layers": [1, 1]}, {"natural_pairs": 2}, {"pair_count": 999}, {"momentum_tier": 9}]:
		var before := store.snapshot()
		check(not submit(store, event(store, overrides)).accepted and store.snapshot() == before, "invalid event rejected atomically")
	var slow := Store.new(definition)
	submit(slow, event(slow))
	submit(slow, event(slow, {"at_ms": 4001}))
	check(slow.snapshot().sides.player.attack_charge_units == 2000, "outside fast window no bonus")
	submit(slow, event(slow, {"pair_count": 0, "natural_pairs": 0, "streak": 0}))
	submit(slow, event(slow))
	check(slow.snapshot().sides.player.attack_charge_units == 3000, "mistake resets fast cadence")
	submit(slow, event(slow, {"pair_count": 3, "natural_pairs": 0, "cleared_layers": [2], "momentum_tier": 4}))
	check(slow.snapshot().sides.player.attack_charge_units == 3000, "assisted clears progress without charge")
	check(slow.snapshot().sides.player.cleared_pairs == 6, "assisted progress counted")
	var burst_definition := definition.duplicate(true)
	burst_definition.charge.attack_threshold_units = 1000
	var burst := Store.new(burst_definition)
	submit(burst, event(burst, {"cleared_layers": [1, 2]}))
	check(burst.snapshot().sides.cpu.pending_attacks[0].pair_count == 5, "one event can generate multiple attack pairs")
	burst_definition.charge.attack_threshold_units = 0
	check(not Definition.validation_errors(burst_definition).is_empty(), "zero threshold invalid")
	var final_definition := definition.duplicate(true)
	final_definition.player_starting_pairs = 1
	var final_store := Store.new(final_definition)
	submit(final_store, event(final_store))
	check(final_store.snapshot().winner == "player", "player event can win")
	check(not submit(final_store, event(final_store)).accepted, "winner freezes charge")
	# Exercise the actual committed Mahjong stream, including a full layer clear.
	var game_definition: Variant = Factory.new().create_definition(42)
	var game := Game.new(game_definition)
	var integrated := Store.new(definition)
	var adapter := Adapter.new(integrated, game_definition)
	var route: Array[String] = Solver.new().find_pair_solution(game_definition)
	for index in route.size():
		game.select_tile(route[index], index * 100)
		var transaction: RefCounted = game.last_transaction()
		check(adapter.consume(transaction).accepted, "committed Mahjong transaction feeds Battle")
		var before := integrated.snapshot()
		check(not adapter.consume(transaction).accepted and integrated.snapshot() == before, "source transaction cannot count twice")
	check(integrated.snapshot().winner == "player", "real board completion wins Battle")
	check(not integrated.snapshot().player_charge.cleared_layers.is_empty(), "actual layer completion observed")
	check(not integrated.snapshot().sides.cpu.pending_attacks.is_empty(), "real matches generate attacks")
	print("Battle B3: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
