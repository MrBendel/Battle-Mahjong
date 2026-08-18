extends SceneTree

const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")
const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")
const TileMatcherScript := preload("res://scripts/simulation/tile_matcher.gd")
const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const FixedLayoutsScript := preload("res://scripts/simulation/fixed_layouts.gd")
const GameDefinitionScript := preload("res://scripts/simulation/game_definition.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const GameCommandScript := preload("res://scripts/simulation/game_command.gd")
const GameChangeScript := preload("res://scripts/simulation/game_change.gd")
const GameTransactionScript := preload("res://scripts/simulation/game_transaction.gd")
const GameReducerScript := preload("res://scripts/simulation/game_reducer.gd")
const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const ReferenceGameFactoryScript := preload("res://scripts/simulation/reference_game_factory.gd")
const GameSimulatorScript := preload("res://scripts/simulation/game_simulator.gd")
const MomentumRulesScript := preload("res://scripts/simulation/momentum_rules.gd")
const MomentumTuningScript := preload("res://scripts/configuration/momentum_tuning.gd")
const BoardLayoutCatalogScript := preload("res://scripts/simulation/board_layout_catalog.gd")
const BoardLayoutScript := preload("res://scripts/simulation/board_layout.gd")
const GameSolverScript := preload("res://scripts/simulation/game_solver.gd")

var _failures := 0
var _assertions := 0


func _init() -> void:
	_log("Running Battle Mahjong simulation tests")
	_run_tile_matcher_tests()
	_run_board_selectability_tests()
	_run_board_projection_tests()
	_run_fixed_layout_tests()
	_run_tray_and_game_tests()
	_run_transaction_timeline_tests()
	_run_momentum_tuning_tests()
	_run_momentum_tests()
	_run_generator_solver_tests()
	_run_reference_game_tests()
	_run_simulation_tests()

	if _failures == 0:
		_log("PASS: %d assertions" % _assertions)
	else:
		_log("FAIL: %d failed assertion(s) across %d assertion(s)" % [_failures, _assertions])
	quit(1 if _failures > 0 else 0)


func _run_tile_matcher_tests() -> void:
	_log(" - tile matcher")
	var matcher = TileMatcherScript.new()
	var bamboo_1_a = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")
	var bamboo_1_b = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")
	var bamboo_2 = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "2")
	var east_a = TileFaceScript.new(TileFaceScript.FAMILY_WIND, TileFaceScript.WIND_EAST)
	var east_b = TileFaceScript.new(TileFaceScript.FAMILY_WIND, TileFaceScript.WIND_EAST)
	_check(matcher.call("faces_match", bamboo_1_a, bamboo_1_b), "bamboo_1 matches bamboo_1")
	_check(not matcher.call("faces_match", bamboo_1_a, bamboo_2), "bamboo_1 does not match bamboo_2")
	_check(matcher.call("faces_match", east_a, east_b), "east matches east")


func _run_board_selectability_tests() -> void:
	_log(" - board selectability")
	var selectability = BoardSelectabilityScript.new()
	var face = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")
	var covered = TileInstanceScript.new("covered", face, BoardPositionScript.new(0, 0, 0))
	var cover = TileInstanceScript.new("cover", face, BoardPositionScript.new(0, 0, 1))
	_check(not selectability.call("is_selectable", covered, [covered, cover]), "tile with another tile above is blocked")
	var partial_cover = TileInstanceScript.new("partial_cover", face, BoardPositionScript.new(1, 1, 1))
	_check(not selectability.call("is_selectable", covered, [covered, partial_cover]), "half-offset higher tile blocks by partial footprint overlap")

	var middle = TileInstanceScript.new("middle", face, BoardPositionScript.new(2, 0, 0))
	var left = TileInstanceScript.new("left", face, BoardPositionScript.new(0, 0, 0))
	var right = TileInstanceScript.new("right", face, BoardPositionScript.new(4, 0, 0))
	_check(not selectability.call("is_selectable", middle, [left, middle, right]), "tile with both horizontal sides blocked is blocked")
	_check(selectability.call("is_selectable", left, [left, middle]), "tile with one horizontal side free is selectable")


func _run_board_projection_tests() -> void:
	_log(" - normalized board projection")
	var face = TileFaceScript.new("test", "a")
	var tile = TileInstanceScript.new("tile_a", face, BoardPositionScript.new(0, 0, 0))
	var definition = _definition([tile])
	var state = GameStateDataScript.new(definition)
	var board = BoardStateScript.new(definition, state)
	_check_equal(tile, board.call("get_tile", "tile_a"), "board resolves immutable tile definition")
	_check_equal(1, board.call("active_tiles").size(), "board zone projects active tile")
	state.tile_zones[tile.id] = GameStateDataScript.ZONE_RESOLVED
	_check_equal(0, board.call("active_tiles").size(), "resolved zone removes tile from board projection")
	_check(board.call("get_tile", "missing") == null, "missing tile id returns null")


func _run_fixed_layout_tests() -> void:
	_log(" - fixed M1 layout through transactions")
	var game = GameStateScript.new(FixedLayoutsScript.new().call("m1_smoke_definition"))
	_check_equal(6, game.board.call("active_tiles").size(), "M1 layout starts with six board tiles")
	_check(game.board.call("is_tile_selectable", "tile_005"), "top tile is selectable")
	_check_equal(GameStateScript.SELECTED, game.call("select_tile", "tile_005"), "first top tile enters tray")
	_check_equal(GameStateScript.PAIR_RESOLVED, game.call("select_tile", "tile_006"), "top pair resolves")
	game.call("select_tile", "tile_001")
	_check_equal(GameStateScript.PAIR_RESOLVED, game.call("select_tile", "tile_002"), "outer pair resolves")
	game.call("select_tile", "tile_003")
	_check_equal(GameStateScript.PAIR_RESOLVED, game.call("select_tile", "tile_004"), "middle pair resolves")
	_check_equal(GameStateScript.WON, game.status, "clearing board and tray wins")
	_check_equal(0, game.board.call("active_tiles").size(), "fixed layout clears fully")
	_check_equal(6, game.revision, "each selection commits one transaction")


func _run_tray_and_game_tests() -> void:
	_log(" - transactional tray and game state")
	var pair_face = TileFaceScript.new("test", "pair")
	var pair_tiles := [
		TileInstanceScript.new("first", pair_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("second", pair_face, BoardPositionScript.new(4, 0, 0)),
	]
	var pair_game = GameStateScript.new(_definition(pair_tiles))
	_check_equal(GameStateScript.SELECTED, pair_game.call("select_tile", "first"), "unmatched selection enters tray")
	_check_equal(1, pair_game.tray.tiles.size(), "tray projection contains unresolved tile")
	_check_equal(GameStateScript.PAIR_RESOLVED, pair_game.call("select_tile", "second"), "matching selection resolves pair")
	_check_equal(0, pair_game.tray.tiles.size(), "resolved pair leaves tray")
	_check_equal(1, pair_game.tray.resolved_pair_count, "pair count is projected from state")
	_check_equal(GameStateScript.WON, pair_game.status, "empty board and tray wins")

	var undo_tiles := [
		TileInstanceScript.new("undo", TileFaceScript.new("test", "a"), BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("other", TileFaceScript.new("test", "b"), BoardPositionScript.new(4, 0, 0)),
	]
	var undo_game = GameStateScript.new(_definition(undo_tiles))
	undo_game.call("select_tile", "undo")
	_check(undo_game.call("can_undo"), "unresolved tray tile enables Undo")
	_check_equal(GameStateScript.UNDONE, undo_game.call("undo_last_unmatched"), "Undo commits compensation")
	_check(undo_game.board.call("is_tile_active", "undo"), "Undo restores tile zone to board")
	_check_equal(0, undo_game.tray.tiles.size(), "Undo removes tile from tray projection")
	_check_equal(2, undo_game.revision, "Undo advances authoritative revision")

	var loss_tiles: Array = []
	for index in range(GameStateScript.BASE_TRAY_CAPACITY):
		loss_tiles.append(TileInstanceScript.new(
			"loss_%d" % index,
			TileFaceScript.new("loss", str(index)),
			BoardPositionScript.new(index * 4, 0, 0)
		))
	var loss_game = GameStateScript.new(_definition(loss_tiles))
	for tile in loss_tiles:
		loss_game.call("select_tile", tile.id)
	_check_equal(GameStateScript.LOST, loss_game.status, "four unresolved selections lose")
	_check_equal(4, loss_game.tray.tiles.size(), "failed tray retains four unresolved tiles")
	_check_equal(GameStateScript.NOTHING_TO_UNDO, loss_game.call("undo_last_unmatched"), "terminal loss cannot be undone")
	var projected_tiles: Array = loss_game.tray.tiles
	projected_tiles.clear()
	_check_equal(4, loss_game.tray.tiles.size(), "mutating tray projection cannot mutate store")


func _run_transaction_timeline_tests() -> void:
	_log(" - transaction timeline")
	var definition = FixedLayoutsScript.new().call("m1_smoke_definition")
	var game = GameStateScript.new(definition)
	var initial = game.call("current_snapshot")
	var initial_hash: String = initial.state_hash()
	game.call("select_tile", "tile_005")
	var selected = game.call("current_snapshot")
	var timeline: Array = game.call("transactions")
	var transaction: Variant = timeline[0]
	_check_equal(1, timeline.size(), "accepted command appends one transaction")
	_check_equal(1, game.store.call("transactions_since", 0).size(), "store exposes transactions after revision")
	_check_equal(0, game.store.call("transactions_since", 1).size(), "transaction range excludes current revision")
	_check_equal(initial_hash, transaction.previous_state_hash, "transaction links previous state hash")
	_check_equal(selected.state_hash(), transaction.next_state_hash, "transaction links next state hash")
	_check_equal(1, transaction.revision, "transaction receives monotonic revision")
	_check_equal(definition.definition_hash(), transaction.definition_hash, "transaction binds exact game definition")
	_check(not transaction.to_dict().changes.is_empty(), "transaction serializes typed changes")
	var serialized_transaction: Variant = JSON.parse_string(JSON.stringify(transaction.to_dict()))
	_check(serialized_transaction is Dictionary, "transaction dictionary round-trips through JSON")
	var parsed_transaction: Variant = GameTransactionScript.from_dict(serialized_transaction)
	var replica = GameStateScript.new(definition)
	var replicated_result: Dictionary = replica.call("apply_transaction", parsed_transaction)
	_check(replicated_result.accepted, "serialized transaction applies through store API")
	_check_equal(selected.state_hash(), replica.call("current_snapshot").state_hash(), "replica reaches authoritative state hash")
	var exposed_transaction: Variant = game.call("transactions")[0]
	exposed_transaction.next_state_hash = "caller_mutation"
	_check_equal(selected.state_hash(), game.call("transactions")[0].next_state_hash, "mutating returned transaction cannot alter timeline")

	var reducer = GameReducerScript.new()
	var replayed: Variant = reducer.call("apply_forward", definition, GameStateDataScript.new(definition), transaction)
	_check(replayed != null, "production reducer replays transaction")
	_check_equal(selected.state_hash(), replayed.state_hash(), "replay produces recorded state hash")
	var reversed: Variant = reducer.call("apply_reverse", definition, replayed, transaction)
	_check(reversed != null, "transaction applies in reverse")
	_check_equal(initial_hash, reversed.state_hash(), "reverse application restores exact prior state")

	var isolated_snapshot = game.call("current_snapshot")
	isolated_snapshot.tile_zones["tile_006"] = GameStateDataScript.ZONE_RESOLVED
	_check(game.board.call("is_tile_active", "tile_006"), "mutating snapshot cannot mutate store")

	var stale_command = GameCommandScript.new(GameCommandScript.SELECT_TILE, {"tile_id": "tile_006"}, 0, "stale")
	var before_stale_hash: String = game.call("current_snapshot").state_hash()
	var stale_result: Dictionary = game.store.call("submit_command", stale_command)
	_check(not stale_result.accepted, "stale revision is rejected")
	_check_equal(before_stale_hash, game.call("current_snapshot").state_hash(), "rejected command leaves state unchanged")
	_check_equal(1, game.call("transactions").size(), "rejected command leaves timeline unchanged")

	var bad_change = GameChangeScript.new(GameChangeScript.TILE_ZONE, "tile_006", GameStateDataScript.ZONE_BOARD, GameStateDataScript.ZONE_TRAY)
	var bad_command = GameCommandScript.new(GameCommandScript.SELECT_TILE, {"tile_id": "tile_006"}, selected.revision)
	var bad_transaction = GameTransactionScript.new(bad_command, [bad_change], GameStateScript.SELECTED)
	bad_transaction.definition_hash = definition.definition_hash()
	bad_transaction.previous_state_hash = selected.state_hash()
	bad_transaction.next_state_hash = "tampered"
	_check(reducer.call("apply_forward", definition, selected, bad_transaction) == null, "hash mismatch rejects entire transaction")
	_check_equal(transaction.next_state_hash, selected.state_hash(), "failed apply does not partially mutate source state")
	var wrong_definition = ReferenceGameFactoryScript.new().call("create_definition", 92817361)
	_check(reducer.call("apply_forward", wrong_definition, GameStateDataScript.new(wrong_definition), transaction) == null, "definition mismatch rejects transaction")

	game.call("undo_last_unmatched")
	var undo_timeline: Array = game.call("transactions")
	var undo_transaction: Variant = undo_timeline[-1]
	_check_equal(2, undo_timeline.size(), "gameplay Undo appends instead of deleting history")
	_check_equal(transaction.transaction_id, undo_transaction.reverts_transaction_id, "Undo references compensated transaction")
	_check_equal(2, undo_transaction.revision, "Undo keeps revision monotonic")

	var replay_state: Variant = GameStateDataScript.new(definition)
	for recorded_transaction in undo_timeline:
		replay_state = reducer.call("apply_forward", definition, replay_state, recorded_transaction)
		if replay_state == null:
			break
	_check(replay_state != null, "complete timeline replays")
	_check_equal(game.call("current_snapshot").state_hash(), replay_state.state_hash(), "complete replay reaches live state")

	var same_game = GameStateScript.new(definition)
	same_game.call("select_tile", "tile_005")
	_check_equal(transaction.next_state_hash, same_game.call("transactions")[0].next_state_hash, "same definition and command produce same hash")


func _run_momentum_tests() -> void:
	_log(" - deterministic momentum and score")
	var face = TileFaceScript.new("test", "pair")
	var second_face = TileFaceScript.new("test", "second_pair")
	var definition = _definition([
		TileInstanceScript.new("first", face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("second", face, BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("third", second_face, BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("fourth", second_face, BoardPositionScript.new(12, 0, 0)),
	])
	var configuration: Dictionary = definition.configuration
	_check_equal(2, definition.rules_version, "gradual multiplier scoring uses rules version 2")
	_check_equal(1, MomentumRulesScript.multiplier_for(19999, configuration), "momentum below first threshold stays x1")
	_check_equal(2, MomentumRulesScript.multiplier_for(20000, configuration), "first threshold enters x2")
	_check(
		90000 - MomentumRulesScript.decay(90000, 100, configuration) \
			> 30000 - MomentumRulesScript.decay(30000, 100, configuration),
		"higher tiers lose more momentum over the same interval"
	)

	var game = GameStateScript.new(definition)
	_check_equal(GameStateScript.SELECTED, game.call("select_tile", "first", 100), "timestamped first selection is accepted")
	_check_equal(GameStateScript.PAIR_RESOLVED, game.call("select_tile", "second", 200), "timestamped pair resolves")
	var snapshot: Variant = game.call("current_snapshot")
	_check_equal(30000, snapshot.momentum_units, "pair adds configured momentum")
	_check_equal(100, snapshot.score, "first pair scores at x1 before its momentum gain")
	_check_equal(200, snapshot.elapsed_time_ms, "accepted command materializes gameplay time")
	_check_equal(2, snapshot.max_multiplier, "state records peak multiplier")
	_check_equal(24400, game.call("momentum_at", 1000), "presentation preview applies deterministic decay")
	_check_equal(30000, game.call("current_snapshot").momentum_units, "momentum preview does not mutate authoritative state")

	var pair_transaction: Variant = game.call("transactions")[-1]
	_check_equal(200, pair_transaction.playback_time_ms, "transaction records command playback time")
	_check_equal(1, pair_transaction.telemetry.score_multiplier, "pair telemetry records awarded multiplier")
	_check_equal(2, pair_transaction.telemetry.resulting_multiplier, "pair telemetry records tier reached for the next pair")
	_check_equal(100, pair_transaction.telemetry.score_gain, "pair telemetry records score delta")
	_check_equal(100, pair_transaction.telemetry.selection_interval_ms, "pair telemetry records selection interval")
	var serialized: Variant = JSON.parse_string(JSON.stringify(pair_transaction.to_dict()))
	var parsed: Variant = GameTransactionScript.from_dict(serialized)
	_check_equal(
		int(pair_transaction.telemetry.score_gain),
		int(parsed.telemetry.score_gain),
		"transaction telemetry round-trips through JSON"
	)
	_check_equal(pair_transaction.playback_time_ms, parsed.playback_time_ms, "playback time round-trips through JSON")

	var stale_time_command = GameCommandScript.new(
		GameCommandScript.SELECT_TILE,
		{"tile_id": "missing"},
		game.revision,
		"stale_time",
		"local",
		199
	)
	var before_stale_hash: String = game.call("current_snapshot").state_hash()
	var stale_result: Dictionary = game.store.call("submit_command", stale_time_command)
	_check(not stale_result.accepted, "command time cannot move backward")
	_check_equal(before_stale_hash, game.call("current_snapshot").state_hash(), "rejected stale time leaves state unchanged")

	game.call("select_tile", "third", 300)
	_check_equal(GameStateScript.PAIR_RESOLVED, game.call("select_tile", "fourth", 400), "consistent second pair resolves")
	var second_pair_transaction: Variant = game.call("last_transaction")
	_check_equal(2, second_pair_transaction.telemetry.score_multiplier, "consistent second pair earns x2")
	_check_equal(3, second_pair_transaction.telemetry.resulting_multiplier, "consistent second pair builds x3 for the next pair")
	_check_equal(300, game.score, "gradual x1 then x2 awards accumulate")

	var slow_game = GameStateScript.new(definition)
	slow_game.call("select_tile", "first", 100)
	slow_game.call("select_tile", "second", 200)
	slow_game.call("select_tile", "third", 3000)
	slow_game.call("select_tile", "fourth", 6000)
	_check_equal(1, slow_game.call("last_transaction").telemetry.score_multiplier, "delayed second pair falls back to x1")
	_check_equal(200, slow_game.score, "hesitation does not receive the consistency bonus")


func _run_momentum_tuning_tests() -> void:
	_log(" - Inspector momentum tuning")
	var default_tuning: Variant = load("res://configuration/default_momentum_tuning.tres")
	_check(default_tuning != null, "default MomentumTuning resource loads")
	_check(default_tuning.call("validation_errors").is_empty(), "default MomentumTuning resource validates")
	var default_overrides: Dictionary = default_tuning.call("configuration_overrides")
	_check_equal(100000, default_overrides.momentum_max, "Inspector maximum maps to simulation configuration")
	_check_equal([5, 7, 10, 14, 19], default_overrides.momentum_decay_per_ms, "per-second Inspector decay converts exactly")
	_check_equal(MomentumTuningScript.default_overrides(), default_overrides, "Inspector defaults match headless simulation defaults")

	var custom_tuning: Variant = MomentumTuningScript.new()
	custom_tuning.maximum = 120000
	custom_tuning.pair_gain = 15000
	custom_tuning.multiplier_thresholds.assign([0, 30000, 60000, 90000])
	custom_tuning.decay_per_second.assign([4000, 6000, 9000, 13000])
	custom_tuning.pair_base_score = 250
	_check(custom_tuning.call("validation_errors").is_empty(), "valid custom tuning passes validation")
	var custom_overrides: Dictionary = custom_tuning.call("configuration_overrides")
	var factory := ReferenceGameFactoryScript.new()
	var default_definition: Variant = factory.call("create_definition", 42)
	var custom_definition: Variant = factory.call("create_definition", 42, 4, custom_overrides)
	_check_equal(120000, custom_definition.configuration.momentum_max, "factory applies Inspector maximum")
	_check_equal(250, custom_definition.configuration.pair_base_score, "factory applies Inspector scoring")
	_check(default_definition.definition_hash() != custom_definition.definition_hash(), "custom tuning changes definition hash")
	custom_overrides.momentum_thresholds[1] = 1
	_check_equal(30000, custom_tuning.multiplier_thresholds[1], "simulation override cannot mutate Inspector resource")

	custom_tuning.multiplier_thresholds.assign([100, 50])
	custom_tuning.decay_per_second.assign([4500])
	_check(custom_tuning.call("validation_errors").size() >= 3, "invalid thresholds and decay report actionable errors")


func _run_reference_game_tests() -> void:
	_log(" - 96-tile reference game")
	var factory = ReferenceGameFactoryScript.new()
	var definition = factory.call("create_definition", 92817361)
	_check_equal(BoardLayoutCatalogScript.PORTRAIT_STACK_96, definition.configuration.layout_id, "reference game uses portrait stack by default")
	var identity_counts := {}
	for tile in definition.tiles:
		var identity: String = tile.face.logical_id()
		identity_counts[identity] = identity_counts.get(identity, 0) + 1
	_check_equal(ReferenceGameFactoryScript.TILE_COUNT, definition.tiles.size(), "reference game has 96 tile definitions")
	_check_equal(ReferenceGameFactoryScript.IDENTITY_COUNT, identity_counts.size(), "reference game has 24 identities")
	for count in identity_counts.values():
		_check_equal(ReferenceGameFactoryScript.COPIES_PER_IDENTITY, count, "each identity has four copies")

	var same_definition = factory.call("create_definition", 92817361)
	var other_definition = factory.call("create_definition", 92817362)
	_check_equal(_deal_signature(definition), _deal_signature(same_definition), "same seed reproduces definition")
	_check(_deal_signature(definition) != _deal_signature(other_definition), "different seed changes definition")
	var serialized_definition: Variant = JSON.parse_string(JSON.stringify(definition.to_dict()))
	var parsed_definition: Variant = GameDefinitionScript.from_dict(serialized_definition)
	_check_equal(_deal_signature(definition), _deal_signature(parsed_definition), "definition round-trips through JSON")
	_check_equal(definition.tray_capacity(), parsed_definition.tray_capacity(), "definition preserves effective configuration")
	_check_equal(definition.rules_version, parsed_definition.rules_version, "definition preserves rules version")

	var game = GameStateScript.new(definition)
	var reference_solution: Array[String] = GameSolverScript.new().call("find_pair_solution", definition)
	var removed_pairs := 0
	for index in range(0, reference_solution.size(), 2):
		game.call("select_tile", reference_solution[index])
		if game.call("select_tile", reference_solution[index + 1]) != GameStateScript.PAIR_RESOLVED:
			break
		removed_pairs += 1
	_check_equal(ReferenceGameFactoryScript.PAIR_COUNT, removed_pairs, "reference game clears through legal transactional pairs")
	_check_equal(GameStateScript.WON, game.status, "reference game reaches won state")
	_check_equal(96, game.call("transactions").size(), "full game records every selection")


func _run_generator_solver_tests() -> void:
	_log(" - M4 layouts, generator, and solver")
	var catalog := BoardLayoutCatalogScript.new()
	var classic: Variant = catalog.call("get_layout", BoardLayoutCatalogScript.CLASSIC_96)
	var staggered: Variant = catalog.call("get_layout", BoardLayoutCatalogScript.STAGGERED_96)
	var portrait_stack: Variant = catalog.call("get_layout", BoardLayoutCatalogScript.PORTRAIT_STACK_96)
	_check(classic.call("validation_errors").is_empty(), "classic layout geometry validates")
	_check(staggered.call("validation_errors").is_empty(), "staggered layout geometry validates")
	_check(portrait_stack.call("validation_errors").is_empty(), "portrait stack geometry validates")
	_check_equal(96, staggered.positions.size(), "staggered layout contains 96 positions")
	_check_equal(96, portrait_stack.positions.size(), "portrait stack contains 96 positions")
	_check(not classic.call("has_partial_overlap"), "classic layout remains fully aligned")
	_check(staggered.call("has_partial_overlap"), "staggered layout includes half-tile higher-layer overlap")
	_check(portrait_stack.call("has_partial_overlap"), "portrait stack includes irregular half-tile overlap")

	var invalid_layout := BoardLayoutScript.new("invalid", [
		BoardPositionScript.new(0, 0, 0),
		BoardPositionScript.new(1, 0, 0),
	])
	_check(not invalid_layout.call("validation_errors").is_empty(), "same-layer physical overlap is rejected")

	var factory := ReferenceGameFactoryScript.new()
	var solver := GameSolverScript.new()
	for layout_id in catalog.call("layout_ids"):
		var generated: Dictionary = factory.call("create_generated", 92817361, 4, {}, layout_id)
		var definition: Variant = generated.definition
		_check_equal(layout_id, definition.configuration.layout_id, "%s id is embedded in definition" % layout_id)
		var certificate_result: Dictionary = solver.call("verify_solution", definition, generated.solution)
		_check(certificate_result.valid, "%s generated certificate wins through transactions: %s" % [layout_id, certificate_result.reason])
		var solved: Array[String] = solver.call("find_pair_solution", definition)
		_check_equal(definition.tiles.size(), solved.size(), "%s independent solver finds every selection" % layout_id)
		_check(solver.call("verify_solution", definition, solved).valid, "%s independent solution replays to a win" % layout_id)

	var classic_definition: Variant = factory.call("create_definition", 77, 4, {}, BoardLayoutCatalogScript.CLASSIC_96)
	var staggered_definition: Variant = factory.call("create_definition", 77, 4, {}, BoardLayoutCatalogScript.STAGGERED_96)
	_check(classic_definition.definition_hash() != staggered_definition.definition_hash(), "layout geometry participates in definition identity")


func _run_simulation_tests() -> void:
	_log(" - full game simulation")
	var simulator = GameSimulatorScript.new()
	for seed in range(1, 21):
		var result: Dictionary = simulator.call("run", seed, GameSimulatorScript.PAIR_AWARE)
		_check_equal(GameStateScript.WON, result.status, "pair-aware policy wins seed %d" % seed)
		_check_equal(ReferenceGameFactoryScript.TILE_COUNT, result.selections, "seed %d selects every tile" % seed)
		_check_equal(ReferenceGameFactoryScript.PAIR_COUNT, result.pairs, "seed %d resolves 48 pairs" % seed)
		_check(result.max_tray <= 3, "seed %d stays below failure occupancy" % seed)

	var random_result: Dictionary = simulator.call("run", 92817361, GameSimulatorScript.RANDOM)
	_check(random_result.status != GameStateScript.PLAYING, "random policy reaches terminal state")
	var bounded_result: Dictionary = simulator.call("run", 92817361, GameSimulatorScript.BOUNDED_ATTENTION)
	var repeated_result: Dictionary = simulator.call("run", 92817361, GameSimulatorScript.BOUNDED_ATTENTION)
	_check(bounded_result.status != GameStateScript.PLAYING, "bounded-attention policy reaches terminal state")
	_check_equal(bounded_result, repeated_result, "bounded-attention policy remains deterministic")

	var fast_result: Dictionary = simulator.call("run", 92817361, GameSimulatorScript.PAIR_AWARE, {"selection_interval_ms": 250})
	var slow_result: Dictionary = simulator.call("run", 92817361, GameSimulatorScript.PAIR_AWARE, {"selection_interval_ms": 3000})
	_check_equal(GameStateScript.WON, fast_result.status, "fast momentum simulation still clears the board")
	_check_equal(GameStateScript.WON, slow_result.status, "slow momentum simulation still clears the board")
	_check(fast_result.score > slow_result.score, "fast play produces a higher score than slow play")
	_check(fast_result.max_multiplier > slow_result.max_multiplier, "fast play reaches a higher multiplier tier")


func _definition(tiles: Array, tray_capacity: int = 4) -> Variant:
	return GameDefinitionScript.new(1, tiles, {"tray_capacity": tray_capacity})


func _deal_signature(definition: Variant) -> String:
	var identities: Array[String] = []
	for tile in definition.tiles:
		identities.append(tile.face.logical_id())
	return "|".join(identities)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		_log("   OK  %s" % message)
	else:
		_failures += 1
		_log("   ERR %s" % message)


func _check_equal(expected: Variant, actual: Variant, message: String) -> void:
	_check(expected == actual, "%s | expected=%s actual=%s" % [message, str(expected), str(actual)])


func _log(message: String) -> void:
	printerr(message)
