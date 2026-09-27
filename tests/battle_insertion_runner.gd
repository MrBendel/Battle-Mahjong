extends SceneTree

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Store := preload("res://scripts/simulation/battle/battle_store.gd")
const Insertion := preload("res://scripts/simulation/battle/battle_insertion.gd")
const GameDefinition := preload("res://scripts/simulation/game_definition.gd")
const Tile := preload("res://scripts/simulation/tile_instance.gd")
const Face := preload("res://scripts/simulation/tile_face.gd")
const Position := preload("res://scripts/simulation/board_position.gd")
const State := preload("res://scripts/simulation/battle/battle_state.gd")
const Factory := preload("res://scripts/simulation/reference_game_factory.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func board_definition() -> RefCounted:
	return GameDefinition.new(42, [
		Tile.new("a", Face.new("bamboo", "1"), Position.new(0, 0, 0)),
		Tile.new("b", Face.new("bamboo", "1"), Position.new(4, 0, 0)),
		Tile.new("c", Face.new("bamboo", "2"), Position.new(8, 0, 0)),
		Tile.new("d", Face.new("bamboo", "2"), Position.new(12, 0, 0))], {})

func definition(top: int = 10000) -> Dictionary:
	var result := Definition.defaults()
	result.player_starting_pairs = 2
	result.insertion.top_chance_bp = top
	return result

func submit(store: RefCounted, type: String, fields: Dictionary = {}, side: String = "player") -> Dictionary:
	var command := {"id": "cmd_%d" % store.snapshot().revision, "expected_revision": store.snapshot().revision,
		"side": side, "type": type}
	command.merge(fields)
	return store.submit(command)

func run() -> void:
	for corruption in ["reserved_id", "configuration", "position"]:
		var invalid: Dictionary = board_definition().to_dict()
		match corruption:
			"reserved_id": invalid.tiles[0].tile_id = "attack_1_pair_0_tile_0"
			"configuration": invalid.configuration.momentum_thresholds = "bad"
			"position": invalid.tiles[0].position.z = -1
		var unbound := Store.new(definition())
		var initial := unbound.snapshot()
		check(not submit(unbound, "bind_board", {"game_definition": invalid}).accepted and unbound.snapshot() == initial, "invalid binding rejected atomically: %s" % corruption)
	for top in [10000, 0]:
		var tuning := definition(top)
		var store := Store.new(tuning)
		var original: Dictionary = board_definition().to_dict()
		check(submit(store, "bind_board", {"game_definition": original}).accepted, "bind certified board")
		check(submit(store, "board_input", {"action": "select_tile", "tile_id": "a", "at_ms": 0}).accepted, "ordinary selection")
		check(submit(store, "board_input", {"action": "select_tile", "tile_id": "b", "at_ms": 10}).accepted, "ordinary pair advances progress")
		var progress := State.progress(store.snapshot(), "player")
		check(submit(store, "send_attack", {"pair_count": 1, "at_ms": 20}, "cpu").accepted, "CPU sends pair")
		check(submit(store, "advance_attacks", {"at_ms": 1020}).accepted, "landing inserts atomically")
		var state := store.snapshot()
		check(state.player_board.applied_attacks.size() == 1, "landing consumed once")
		check(state.sides.player.remaining_pairs == 2, "insertion adds player work")
		check(State.progress(state, "player") < progress, "insertion pushes race backward")
		check(state.player_board.definition.tiles.size() == 6, "complete pair added without deleting resolved tiles")
		check(state.player_board.original_definition == original, "original definition immutable")
		check(state.player_board.state.tile_slot_ids.c == "c", "authored slot identity preserved")
		var placements: Array = store.transactions()[-1].events[-1].placements
		check(placements[0].kind == ("top" if top == 10000 else "under"), "forced placement tuning respected")
		check(placements[0].column != placements[1].column, "pair spread across different columns")
		if top == 0:
			check(not placements[0].shifted.is_empty(), "under placement shifts existing slots upward")
		var route: Array = state.player_board.route
		check(Insertion.Solver.new().verify_state_route(GameDefinition.from_dict(state.player_board.definition), Insertion.restore(state.player_board.state), route).valid, "inserted state clears through normal transactions")
		submit(store, "advance_attacks", {"at_ms": 1100})
		check(store.snapshot().player_board.definition.tiles.size() == 6, "landing cannot insert twice")
		for id in route:
			check(submit(store, "board_input", {"action": "select_tile", "tile_id": id, "at_ms": 1200}).accepted, "inserted tiles use ordinary input")
		check(store.snapshot().winner == "player", "clear enlarged board wins")
		var replay := Store.new(tuning)
		for transaction in store.transactions():
			check(replay.apply_transaction(transaction).accepted, "insertion and later gameplay replay")
		check(replay.snapshot() == store.snapshot(), "full replay identical")
		var tampered: Dictionary = store.transactions()[4].duplicate(true)
		tampered.after.player_board.definition.tiles[-1].position.z += 1
		var victim := Store.new(tuning)
		for i in 4:
			victim.apply_transaction(store.transactions()[i])
		check(not victim.apply_transaction(tampered).accepted, "tampered insertion rejected")
	var limit := definition()
	limit.insertion.max_layer = 0
	var overflow := Store.new(limit)
	submit(overflow, "bind_board", {"game_definition": board_definition().to_dict()})
	submit(overflow, "send_attack", {"pair_count": 1, "at_ms": 0}, "cpu")
	check(submit(overflow, "advance_attacks", {"at_ms": 1000}).accepted, "overflow is committed outcome")
	check(overflow.snapshot().winner == "cpu", "no legal depth triggers defeat")
	check(overflow.snapshot().player_board.definition.tiles.size() == 4, "overflow leaves board intact")
	var bounded := definition()
	bounded.insertion.solver_nodes = 3
	bounded.insertion.attempts = 1
	var deferred := Store.new(bounded)
	check(submit(deferred, "bind_board", {"game_definition": board_definition().to_dict()}).accepted, "small initial route fits budget")
	submit(deferred, "send_attack", {"pair_count": 1, "at_ms": 0}, "cpu")
	submit(deferred, "advance_attacks", {"at_ms": 1000})
	check(deferred.snapshot().status == "playing" and deferred.snapshot().player_board.applied_attacks.is_empty(), "solver budget is not defeat")
	check(deferred.snapshot().landed_attacks.size() == 1, "unverified payload retained for retry")
	var before := deferred.snapshot()
	check(not submit(deferred, "clear_pairs", {"pair_count": 1}).accepted and deferred.snapshot() == before, "bound board cannot bypass real progress")
	var held := Store.new(definition())
	submit(held, "bind_board", {"game_definition": board_definition().to_dict()})
	submit(held, "board_input", {"action": "select_tile", "tile_id": "a", "at_ms": 0})
	submit(held, "send_attack", {"pair_count": 2, "at_ms": 0}, "cpu")
	check(submit(held, "advance_attacks", {"at_ms": 1000}).accepted, "multi-pair insertion with held tile")
	check(held.snapshot().player_board.applied_attacks.size() == 1, "tray-aware route certified")
	check(held.snapshot().player_board.state.tray_tile_ids == ["a"], "insertion preserves held tile")
	check(held.snapshot().player_board.definition.tiles.size() == 8, "multiple complete pairs inserted")
	var chain: Array = []
	for z in 3:
		chain.append({"tile_id": "layer_%d" % z, "position": {"x": z % 2, "y": 0, "z": z}})
	var options: Array = Insertion.new()._options(chain, {"id": "new", "face_family": "bamboo", "face_value": "1"}, "under", 4)
	check(options[0].shifted == ["layer_0", "layer_1", "layer_2"], "under placement lifts staggered overlap closure")
	var reference: Variant = Factory.new().create_definition(42)
	for chance in [10000, 0, 8000]:
		var full_tuning := Definition.defaults()
		full_tuning.insertion.top_chance_bp = chance
		var full := Store.new(full_tuning)
		var bound := submit(full, "bind_board", {"game_definition": reference.to_dict()})
		check(bound.accepted, "reference board binds: %s" % bound.get("reason", ""))
		if not bound.accepted:
			continue
		submit(full, "send_attack", {"pair_count": 1, "at_ms": 0}, "cpu")
		check(submit(full, "advance_attacks", {"at_ms": 1000}).accepted, "reference attack advances")
		var snapshot := full.snapshot()
		check(snapshot.player_board.applied_attacks.size() == 1, "reference insertion certified for placement mix %d" % chance)
		check(snapshot.player_board.definition.tiles.size() == 98, "reference board retains original 96 tiles")
		check(Insertion.geometry_valid(Insertion.active_slots(snapshot.player_board.definition, snapshot.player_board.state), [], 8), "reference geometry has no overlapping peers")
	print("Battle B6: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
