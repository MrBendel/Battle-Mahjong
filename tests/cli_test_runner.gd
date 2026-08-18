extends SceneTree

const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")
const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")
const TileMatcherScript := preload("res://scripts/simulation/tile_matcher.gd")
const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const FixedLayoutsScript := preload("res://scripts/simulation/fixed_layouts.gd")
const TrayStateScript := preload("res://scripts/simulation/tray_state.gd")
const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const ReferenceGameFactoryScript := preload("res://scripts/simulation/reference_game_factory.gd")
const GameSimulatorScript := preload("res://scripts/simulation/game_simulator.gd")

var _failures := 0
var _assertions := 0

func _init() -> void:
	_log("Running Battle Mahjong simulation tests")

	_run_tile_matcher_tests()
	_run_board_selectability_tests()
	_run_board_state_tests()
	_run_fixed_layout_tests()
	_run_tray_tests()
	_run_game_state_tests()
	_run_reference_game_tests()
	_run_simulation_tests()

	if _failures == 0:
		_log("PASS: %d assertions" % _assertions)
	else:
		_log("FAIL: %d failed assertion(s) across %d assertion(s)" % [_failures, _assertions])

	quit()


func _run_tile_matcher_tests() -> void:
	_log(" - tile matcher")
	var matcher = TileMatcherScript.new()
	var bamboo_1_a = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")
	var bamboo_1_b = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")
	var bamboo_2 = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "2")
	var east_a = TileFaceScript.new(TileFaceScript.FAMILY_WIND, TileFaceScript.WIND_EAST)
	var east_b = TileFaceScript.new(TileFaceScript.FAMILY_WIND, TileFaceScript.WIND_EAST)
	var red_dragon_a = TileFaceScript.new(TileFaceScript.FAMILY_DRAGON, TileFaceScript.DRAGON_RED)
	var red_dragon_b = TileFaceScript.new(TileFaceScript.FAMILY_DRAGON, TileFaceScript.DRAGON_RED)

	_check(matcher.call("faces_match", bamboo_1_a, bamboo_1_b), "bamboo_1 matches bamboo_1")
	_check(not matcher.call("faces_match", bamboo_1_a, bamboo_2), "bamboo_1 does not match bamboo_2")
	_check(matcher.call("faces_match", east_a, east_b), "east matches east")
	_check(matcher.call("faces_match", red_dragon_a, red_dragon_b), "red_dragon matches red_dragon")


func _run_board_selectability_tests() -> void:
	_log(" - board selectability")
	var selectability = BoardSelectabilityScript.new()
	var face = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")

	var covered = TileInstanceScript.new("covered", face, BoardPositionScript.new(0, 0, 0))
	var cover = TileInstanceScript.new("cover", face, BoardPositionScript.new(0, 0, 1))
	_check(not selectability.call("is_selectable", covered, [covered, cover]), "tile with another tile above is blocked")

	var middle = TileInstanceScript.new("middle", face, BoardPositionScript.new(2, 0, 0))
	var left = TileInstanceScript.new("left", face, BoardPositionScript.new(0, 0, 0))
	var right = TileInstanceScript.new("right", face, BoardPositionScript.new(4, 0, 0))
	_check(not selectability.call("is_selectable", middle, [left, middle, right]), "tile with both left and right neighbors is blocked")

	var edge = TileInstanceScript.new("edge", face, BoardPositionScript.new(0, 0, 0))
	var neighbor = TileInstanceScript.new("neighbor", face, BoardPositionScript.new(2, 0, 0))
	_check(selectability.call("is_selectable", edge, [edge, neighbor]), "tile with no cover and one horizontal side free is selectable")


func _run_board_state_tests() -> void:
	_log(" - board state")
	var bamboo_1 = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")
	var bamboo_2 = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "2")

	var lookup_tile = TileInstanceScript.new("tile_a", bamboo_1, BoardPositionScript.new(0, 0, 0))
	var lookup_board = BoardStateScript.new([lookup_tile])
	_check(lookup_tile == lookup_board.call("get_tile", "tile_a"), "can find tile by id")
	_check(lookup_board.call("get_tile", "missing") == null, "missing tile id returns null")

	var first = TileInstanceScript.new("first", bamboo_1, BoardPositionScript.new(0, 0, 0))
	var second = TileInstanceScript.new("second", bamboo_1, BoardPositionScript.new(4, 0, 0))
	var removable_board = BoardStateScript.new([first, second])
	_check(removable_board.call("remove_matching_pair", "first", "second"), "can remove a matching selectable pair")
	_check(first.removed, "first tile is marked removed")
	_check(second.removed, "second tile is marked removed")
	_check_equal(0, removable_board.call("active_tiles").size(), "removed pair is absent from active tiles")

	var mismatch_first = TileInstanceScript.new("first", bamboo_1, BoardPositionScript.new(0, 0, 0))
	var mismatch_second = TileInstanceScript.new("second", bamboo_2, BoardPositionScript.new(4, 0, 0))
	var mismatch_board = BoardStateScript.new([mismatch_first, mismatch_second])
	_check(not mismatch_board.call("remove_matching_pair", "first", "second"), "refuses non-matching pair")
	_check_equal(2, mismatch_board.call("active_tiles").size(), "non-matching pair remains active")

	var blocked = TileInstanceScript.new("blocked", bamboo_1, BoardPositionScript.new(2, 0, 0))
	var mate = TileInstanceScript.new("mate", bamboo_1, BoardPositionScript.new(8, 0, 0))
	var left_blocker = TileInstanceScript.new("left", bamboo_1, BoardPositionScript.new(0, 0, 0))
	var right_blocker = TileInstanceScript.new("right", bamboo_1, BoardPositionScript.new(4, 0, 0))
	var blocked_board = BoardStateScript.new([left_blocker, blocked, right_blocker, mate])
	_check(not blocked_board.call("remove_matching_pair", "blocked", "mate"), "refuses blocked tile")
	_check_equal(4, blocked_board.call("active_tiles").size(), "blocked failed removal leaves board unchanged")


func _run_fixed_layout_tests() -> void:
	_log(" - fixed layout")
	var board = FixedLayoutsScript.new().call("m1_smoke_layout")

	_check_equal(6, board.call("active_tiles").size(), "M1 smoke layout starts with six active tiles")
	_check(board.call("is_tile_selectable", "tile_001"), "outer bottom tile is selectable")
	_check(board.call("is_tile_selectable", "tile_002"), "opposite outer bottom tile is selectable")
	_check(not board.call("is_tile_selectable", "tile_003"), "covered bottom tile is blocked")
	_check(not board.call("is_tile_selectable", "tile_004"), "covered bottom tile on other side is blocked")
	_check(board.call("remove_matching_pair", "tile_005", "tile_006"), "top pair can be cleared")
	_check(board.call("remove_matching_pair", "tile_001", "tile_002"), "outer pair can be cleared")
	_check(board.call("remove_matching_pair", "tile_003", "tile_004"), "middle pair can be cleared after top and outer removal")
	_check_equal(0, board.call("active_tiles").size(), "M1 smoke layout can be fully cleared")


func _run_tray_tests() -> void:
	_log(" - four-slot tray")
	var face_a = TileFaceScript.new("test", "a")
	var face_b = TileFaceScript.new("test", "b")
	var face_c = TileFaceScript.new("test", "c")
	var face_d = TileFaceScript.new("test", "d")
	var position = BoardPositionScript.new(0, 0, 0)
	var tray = TrayStateScript.new(4)

	_check_equal(TrayStateScript.STORED, tray.call("add_tile", TileInstanceScript.new("a1", face_a, position)), "first unmatched tile stays in tray")
	_check_equal(TrayStateScript.MATCHED, tray.call("add_tile", TileInstanceScript.new("a2", face_a, position)), "matching tile resolves immediately")
	_check_equal(0, tray.tiles.size(), "resolved pair leaves tray empty")
	_check_equal(1, tray.resolved_pair_count, "tray counts resolved pair")

	tray.call("add_tile", TileInstanceScript.new("a3", face_a, position))
	tray.call("add_tile", TileInstanceScript.new("b1", face_b, position))
	tray.call("add_tile", TileInstanceScript.new("c1", face_c, position))
	_check_equal(TrayStateScript.FAILED, tray.call("add_tile", TileInstanceScript.new("d1", face_d, position)), "four unresolved tiles fail the tray")
	_check(tray.failed, "tray records failure")
	_check_equal(4, tray.tiles.size(), "failed tray retains four unresolved tiles")


func _run_game_state_tests() -> void:
	_log(" - game state")
	var face = TileFaceScript.new("test", "pair")
	var first = TileInstanceScript.new("first", face, BoardPositionScript.new(0, 0, 0))
	var second = TileInstanceScript.new("second", face, BoardPositionScript.new(4, 0, 0))
	var game = GameStateScript.new(BoardStateScript.new([first, second]))

	_check_equal(GameStateScript.SELECTED, game.call("select_tile", "first"), "selectable tile moves into tray")
	_check_equal(1, game.tray.tiles.size(), "selected tile occupies tray slot")
	_check_equal(1, game.board.call("active_tiles").size(), "selected tile leaves board")
	_check_equal(GameStateScript.PAIR_RESOLVED, game.call("select_tile", "second"), "second matching selection resolves pair")
	_check_equal(GameStateScript.WON, game.status, "empty board and tray wins game")
	_check_equal(1, game.tray.resolved_pair_count, "game exposes resolved pair count")


func _run_reference_game_tests() -> void:
	_log(" - 96-tile reference game")
	var factory = ReferenceGameFactoryScript.new()
	var board = factory.call("create_board", 92817361)
	var identity_counts := {}

	for tile in board.tiles:
		var identity: String = tile.face.logical_id()
		identity_counts[identity] = identity_counts.get(identity, 0) + 1

	_check_equal(ReferenceGameFactoryScript.TILE_COUNT, board.tiles.size(), "reference board has 96 tiles")
	_check_equal(ReferenceGameFactoryScript.IDENTITY_COUNT, identity_counts.size(), "reference board has 24 identities")
	for count in identity_counts.values():
		_check_equal(ReferenceGameFactoryScript.COPIES_PER_IDENTITY, count, "each reference identity has four copies")

	var same_seed_board = factory.call("create_board", 92817361)
	var other_seed_board = factory.call("create_board", 92817362)
	_check_equal(_deal_signature(board), _deal_signature(same_seed_board), "same seed reproduces deal")
	_check(_deal_signature(board) != _deal_signature(other_seed_board), "different seed changes deal")


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
	_check(random_result.status != GameStateScript.PLAYING, "random policy reaches a terminal state")

	var bounded_result: Dictionary = simulator.call("run", 92817361, GameSimulatorScript.BOUNDED_ATTENTION)
	var repeated_result: Dictionary = simulator.call("run", 92817361, GameSimulatorScript.BOUNDED_ATTENTION)
	_check(bounded_result.status != GameStateScript.PLAYING, "bounded-attention policy reaches a terminal state")
	_check_equal(bounded_result, repeated_result, "bounded-attention policy is deterministic for a seed")
	_check_equal(GameSimulatorScript.DEFAULT_ATTENTION_LIMIT, bounded_result.policy_config.attention_limit, "bounded-attention result records effective default configuration")
	_check(bounded_result.max_tray <= 4, "bounded-attention policy respects tray capacity")


func _deal_signature(board: Variant) -> String:
	var identities: Array[String] = []
	for tile in board.tiles:
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
