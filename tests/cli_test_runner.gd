extends SceneTree

const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")
const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")
const TileMatcherScript := preload("res://scripts/simulation/tile_matcher.gd")
const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const BoardOpportunityAnalysisScript := preload("res://scripts/simulation/board_opportunity_analysis.gd")
const FixedLayoutsScript := preload("res://scripts/simulation/fixed_layouts.gd")
const GameDefinitionScript := preload("res://scripts/simulation/game_definition.gd")
const GameConfigurationScript := preload("res://scripts/simulation/game_configuration.gd")
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
const BoardLayoutLoaderScript := preload("res://scripts/simulation/board_layout_loader.gd")
const BoardLayoutRequirementsScript := preload("res://scripts/simulation/board_layout_requirements.gd")
const ProceduralLayoutGeneratorScript := preload("res://scripts/simulation/procedural_layout_generator.gd")
const ModifierLoadoutScript := preload("res://scripts/simulation/modifier_loadout.gd")
const ModifierRulesScript := preload("res://scripts/simulation/modifier_rules.gd")
const ModifierTuningScript := preload("res://scripts/configuration/modifier_tuning.gd")
const TileSkinScript := preload("res://scripts/presentation/tile_skin.gd")
const ArcadeCalloutTuningScript := preload("res://scripts/configuration/arcade_callout_tuning.gd")
const ArcadeCalloutPolicyScript := preload("res://scripts/presentation/arcade_callout_policy.gd")

var _failures := 0
var _assertions := 0


func _init() -> void:
	_log("Running Battle Mahjong simulation tests")
	_run_tile_matcher_tests()
	_run_application_version_tests()
	_run_tile_skin_contract_tests()
	_run_board_selectability_tests()
	_run_board_projection_tests()
	_run_fixed_layout_tests()
	_run_tray_and_game_tests()
	_run_flipped_tile_tests()
	_run_transaction_timeline_tests()
	_run_momentum_tuning_tests()
	_run_arcade_callout_tests()
	_run_momentum_tests()
	_run_combo_tests()
	_run_opportunity_analysis_tests()
	_run_modifier_tests()
	_run_consumable_tests()
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
	_check_equal("east", east_a.logical_id(), "wind uses the canonical skin identifier")
	_check_equal("red_dragon", TileFaceScript.new(TileFaceScript.FAMILY_DRAGON, TileFaceScript.DRAGON_RED).logical_id(), "dragon uses the canonical skin identifier")


func _run_application_version_tests() -> void:
	_log(" - application version contract")
	var presets := ConfigFile.new()
	_check_equal(OK, presets.load("res://export_presets.cfg"), "Android export presets load")
	var release_name := str(presets.get_value("preset.0.options", "version/name", ""))
	var screenshot_name := str(presets.get_value("preset.1.options", "version/name", ""))
	var semantic_version := RegEx.new()
	semantic_version.compile("^[0-9]+\\.[0-9]+\\.[0-9]+$")
	_check(semantic_version.search(release_name) != null, "tracked Android release name is semantic")
	_check_equal("%s-screenshot" % release_name, screenshot_name, "screenshot preset shares the tracked version base")
	_check(
		int(presets.get_value("preset.0.options", "version/code", 0)) > 1,
		"tracked Android debug version code has advanced"
	)


func _run_tile_skin_contract_tests() -> void:
	_log(" - M7 tile skin contract")
	var skin := TileSkinScript.new()
	_check(skin.call("validation_errors").is_empty(), "Default tile skin manifest validates")
	_check_equal(34, skin.canonical_face_ids.size(), "canonical production vocabulary contains 34 identities")
	_check_equal(34, _unique_strings(skin.canonical_face_ids).size(), "canonical production identities are unique")
	_check(skin.call("has_face_id", "bamboo_9"), "skin includes full Bamboo vocabulary")
	_check(skin.call("has_face_id", "dots_9"), "skin includes full Dots vocabulary")
	_check(skin.call("has_face_id", "characters_9"), "skin includes full Characters vocabulary")
	_check(skin.call("has_face_id", "north"), "skin includes all Winds")
	_check(skin.call("has_face_id", "white_dragon"), "skin includes all Dragons")
	_check_equal(Vector2i(512, 640), Vector2i(skin.geometry.source_size[0], skin.geometry.source_size[1]), "skin records canonical source geometry")
	_check_equal(Vector2i(32, 40), Vector2i(skin.geometry.minimum_runtime_size[0], skin.geometry.minimum_runtime_size[1]), "skin records minimum runtime footprint")
	_check_equal(2, skin.base_variants.size(), "Default skin defines portrait and landscape ceramic bases")
	_check(ResourceLoader.exists(str(skin.base_variants.portrait.asset)), "portrait ceramic base runtime asset exists")
	_check(ResourceLoader.exists(str(skin.base_variants.landscape.asset)), "landscape ceramic base runtime asset exists")
	_check(skin.call("tile_aspect") > 1.0, "portrait ceramic base uses a tall footprint")
	skin.call("set_orientation", "landscape")
	_check(skin.call("tile_aspect") < 1.0, "landscape ceramic base uses a wide footprint")
	_check(skin.call("tile_base_texture") != null, "active landscape ceramic base loads")
	_check(
		float(skin.depth_presentation.lowest_layer_brightness) <= 0.5,
		"Default skin preserves strong contrast between the highest and lowest authored layers"
	)
	var blocked_overlay: Array = skin.depth_presentation.blocked_overlay_color
	_check(
		float(blocked_overlay[1]) > float(blocked_overlay[0]) \
			and float(blocked_overlay[2]) > float(blocked_overlay[0]),
		"blocked-state veil is cool rather than another neutral depth step"
	)
	_check(
		float(skin.depth_presentation.shadow_opacity) > 0.0,
		"Default skin enables cast tile shadows"
	)
	_check(float(skin.layout_presentation.adjacent_gap_ratio) <= 0.0, "Default skin joins adjacent tile artwork without gaps")
	var ink_expansion: Array = skin.layout_presentation.ink_outline_expansion_ratio
	_check(float(ink_expansion[0]) > 0.0 and float(ink_expansion[1]) > 0.0, "Default skin expands a manga-ink silhouette around tile artwork")
	_check_equal(24, skin.reference_preview_mapping.size(), "current abstract deal has an explicit visual preview map")
	_check_equal("bamboo_1", skin.call("presentation_id", TileFaceScript.new("reference", "01")), "reference mapping does not change simulation identity")
	for face_id in skin.canonical_face_ids:
		var definition: Dictionary = skin.faces[face_id]
		_check(ResourceLoader.exists(str(definition.get("asset", ""))), "%s Default runtime asset exists" % face_id)


func _run_arcade_callout_tests() -> void:
	_log(" - arcade callout policy")
	var tuning := ArcadeCalloutTuningScript.new()
	var policy := ArcadeCalloutPolicyScript.new()
	_check(tuning.call("validation_errors").is_empty(), "default arcade callout tuning validates")
	_check_equal({}, policy.call("choose_for_pair", {"combo_before": 9, "combo_after": 10}, 0, tuning), "Combo 10 remains below the alert boundary")
	var first_combo: Dictionary = policy.call("choose_for_pair", {"combo_before": 10, "combo_after": 11}, 0, tuning)
	_check_equal("combo", first_combo.type, "Combo 11 starts Combo alerts")
	_check_equal("11 COMBO!", first_combo.text, "first Combo alert includes the live count")
	_check_equal({}, policy.call("choose_for_pair", {"combo_before": 11, "combo_after": 12}, 0, tuning), "non-milestone Combo does not spam the callout lane")
	_check_equal("15 COMBO!", policy.call("choose_for_pair", {"combo_before": 14, "combo_after": 15}, 0, tuning).text, "configured Combo interval recognizes the next milestone")

	var score_alert: Dictionary = policy.call("choose_for_pair", {"score_gain": 250, "combo_before": 2, "combo_after": 3}, 10100, tuning)
	_check_equal("score", score_alert.type, "crossing a current-run score milestone emits a score alert")
	_check_equal("SCORE 10K!", score_alert.text, "score milestone uses compact arcade text")
	var hidden_alert: Dictionary = policy.call("choose_for_pair", {"difficulty_reward": {"callout_key": "great", "difficulty_percentile_bps": 8000}}, 0, tuning)
	_check_equal("WELL HIDDEN!", hidden_alert.text, "notable hidden pair receives specific recognition copy")
	var amazing_alert: Dictionary = policy.call("choose_for_pair", {"difficulty_reward": {"callout_key": "eagle_eyes", "difficulty_percentile_bps": 9800}}, 0, tuning)
	_check_equal("AMAZING FIND!", amazing_alert.text, "top exceptional percentile receives strongest find copy")
	var priority_alert: Dictionary = policy.call("choose_for_pair", {
		"score_gain": 250,
		"combo_before": 10,
		"combo_after": 11,
		"difficulty_reward": {"callout_key": "eagle_eyes"},
	}, 10100, tuning)
	_check_equal("difficulty", priority_alert.type, "coincident pair events choose exactly one specific difficulty alert")
	_check_equal("EAGLE EYES!", priority_alert.text, "difficulty event wins callout arbitration")
	tuning.first_combo_alert = 10
	tuning.score_milestones.assign([10000, 5000])
	_check_equal(2, tuning.call("validation_errors").size(), "invalid callout thresholds report actionable errors")


func _run_board_selectability_tests() -> void:
	_log(" - board selectability")
	var selectability = BoardSelectabilityScript.new()
	var face = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")
	var covered = TileInstanceScript.new("covered", face, BoardPositionScript.new(0, 0, 0))
	var cover = TileInstanceScript.new("cover", face, BoardPositionScript.new(0, 0, 1))
	_check(not selectability.call("is_selectable", covered, [covered, cover]), "tile with another tile above is blocked")
	_check(not selectability.call("is_visible", covered, [covered, cover]), "exact higher tile fully hides lower tile")
	var partial_cover = TileInstanceScript.new("partial_cover", face, BoardPositionScript.new(1, 1, 1))
	_check(not selectability.call("is_selectable", covered, [covered, partial_cover]), "half-offset higher tile blocks by partial footprint overlap")
	_check(selectability.call("is_visible", covered, [covered, partial_cover]), "partially covered tile remains visible")
	var left_half_cover = TileInstanceScript.new("left_half_cover", face, BoardPositionScript.new(-1, 0, 1))
	var right_half_cover = TileInstanceScript.new("right_half_cover", face, BoardPositionScript.new(1, 0, 1))
	_check(not selectability.call("is_visible", covered, [covered, left_half_cover, right_half_cover]), "multiple higher tiles can collectively hide a tile")

	var middle = TileInstanceScript.new("middle", face, BoardPositionScript.new(2, 0, 0))
	var left = TileInstanceScript.new("left", face, BoardPositionScript.new(0, 0, 0))
	var right = TileInstanceScript.new("right", face, BoardPositionScript.new(4, 0, 0))
	_check(not selectability.call("is_selectable", middle, [left, middle, right]), "tile with both horizontal sides blocked is blocked")
	_check(selectability.call("is_visible", middle, [left, middle, right]), "side-blocked tile remains visible")
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

	var rescue_face := TileFaceScript.new("test", "rescue")
	var almost_full_tiles := [
		TileInstanceScript.new("rescue_first", rescue_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("unmatched_b", TileFaceScript.new("test", "b"), BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("unmatched_c", TileFaceScript.new("test", "c"), BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("rescue_second", rescue_face, BoardPositionScript.new(12, 0, 0)),
	]
	var almost_full_game := GameStateScript.new(_definition(almost_full_tiles))
	almost_full_game.call("select_tile", "rescue_first")
	almost_full_game.call("select_tile", "unmatched_b")
	almost_full_game.call("select_tile", "unmatched_c")
	_check_equal(3, almost_full_game.tray.tiles.size(), "matching rescue starts with three authoritative tray tiles")
	_check_equal(GameStateScript.PAIR_RESOLVED, almost_full_game.call("select_tile", "rescue_second"), "fourth visual arrival resolves against tray")
	_check_equal(2, almost_full_game.tray.tiles.size(), "resolved fourth arrival never occupies a temporary data slot")
	_check_equal(GameStateScript.PLAYING, almost_full_game.status, "animation-only fourth slot cannot trigger loss")
	var rescue_transaction: Variant = almost_full_game.call("last_transaction")
	for change in rescue_transaction.changes:
		if change.type == GameChangeScript.TRAY:
			_check_equal(3, change.before.size(), "rescue transaction starts from three tray tiles")
			_check_equal(2, change.after.size(), "rescue transaction atomically removes the match")

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
	_check_equal(0, undo_game.call("current_snapshot").momentum_units, "Undo removes the compensated selection momentum")
	_check_equal(2, undo_game.revision, "Undo advances authoritative revision")

	var barrier_face := TileFaceScript.new("test", "barrier_pair")
	var barrier_tiles := [
		TileInstanceScript.new("held_before_pair", TileFaceScript.new("test", "held"), BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("held_mate", TileFaceScript.new("test", "held"), BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("pair_first", barrier_face, BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("pair_second", barrier_face, BoardPositionScript.new(12, 0, 0)),
		TileInstanceScript.new("selected_after_pair", TileFaceScript.new("test", "after"), BoardPositionScript.new(16, 0, 0)),
		TileInstanceScript.new("after_mate", TileFaceScript.new("test", "after"), BoardPositionScript.new(20, 0, 0)),
	]
	var barrier_game = GameStateScript.new(_definition(barrier_tiles))
	barrier_game.call("select_tile", "held_before_pair")
	barrier_game.call("select_tile", "pair_first")
	_check_equal(GameStateScript.PAIR_RESOLVED, barrier_game.call("select_tile", "pair_second"), "intervening pair resolves")
	var barrier_revision: int = barrier_game.revision
	_check(not barrier_game.call("can_undo"), "resolved pair clears prior Undo eligibility")
	_check_equal(GameStateScript.NOTHING_TO_UNDO, barrier_game.call("undo_last_unmatched"), "Undo cannot cross a resolved pair")
	_check_equal(barrier_revision, barrier_game.revision, "blocked Undo appends no transaction")
	_check_equal(1, barrier_game.call("consumable_count", "undo"), "blocked Undo consumes no charge")
	_check_equal(["held_before_pair"], _tile_ids(barrier_game.tray.tiles), "tile selected before pair remains in tray")
	barrier_game.call("select_tile", "selected_after_pair")
	_check(barrier_game.call("can_undo"), "new unmatched selection establishes fresh Undo eligibility")
	_check_equal(GameStateScript.UNDONE, barrier_game.call("undo_last_unmatched"), "Undo returns selection made after pair barrier")
	_check_equal(["held_before_pair"], _tile_ids(barrier_game.tray.tiles), "fresh Undo leaves older tray tile committed")

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


func _run_flipped_tile_tests() -> void:
	_log(" - deterministic flipped tiles")
	var memory_face := TileFaceScript.new("test", "memory")
	var direct_tiles := [
		TileInstanceScript.new("flipped", memory_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("ordinary", memory_face, BoardPositionScript.new(4, 0, 0)),
	]
	var direct_definition: Variant = _definition_with_flips(direct_tiles, ["flipped"])
	_check_equal(1, direct_definition.configuration.flipped_tile_count, "definition records the actual flipped-tile count")
	_check_equal(["flipped"], direct_definition.flipped_tile_ids, "definition binds physical flipped tile ids")
	var serialized_definition: Variant = GameDefinitionScript.from_dict(
		JSON.parse_string(JSON.stringify(direct_definition.to_dict()))
	)
	_check(serialized_definition != null, "flipped definition round-trips through JSON")
	_check_equal(direct_definition.definition_hash(), serialized_definition.definition_hash(), "flipped ids participate in definition identity")
	var legacy_definition := GameDefinitionScript.new(1, direct_tiles, {}, 8, [], {}, null, ["flipped"])
	_check(legacy_definition.flipped_tile_ids.is_empty(), "pre-version-9 definition ignores flipped ids")
	_check(not legacy_definition.configuration.has("flipped_tile_count"), "pre-version-9 definition preserves legacy configuration identity")

	var direct_game := GameStateScript.new(direct_definition)
	_check(direct_game.board.call("is_tile_revealable", "flipped"), "accessible face-down tile is revealable")
	_check(not direct_game.board.call("is_tile_selectable", "flipped"), "face-down tile cannot enter the tray")
	_check_equal(GameStateScript.TILE_REVEALED, direct_game.call("reveal_tile", "flipped", 100), "accessible face-down tile reveals in place")
	_check(direct_game.board.call("is_tile_revealed_flipped", "flipped"), "revealed flipped tile remains active on the board")
	_check_equal(0, direct_game.tray.tiles.size(), "reveal does not occupy a tray slot")
	_check_equal(GameStateScript.INVALID_SELECTION, direct_game.call("select_tile", "flipped", 100), "revealed flipped tile still cannot enter the tray")
	_check_equal(GameStateScript.HINTED, direct_game.call("request_hint", 150), "Hint can use a known revealed flipped face")
	_check_equal(["flipped", "ordinary"], direct_game.call("hinted_tile_ids"), "Hint points from revealed tile to ordinary mate")
	_check_equal({}, direct_game.call("flipped_match_candidate", "ordinary"), "board mate cannot resolve directly against revealed tile")
	_check_equal(GameStateScript.SELECTED, direct_game.call("select_tile", "ordinary", 200), "matching ordinary board tile enters the tray first")
	_check_equal(["ordinary"], _tile_ids(direct_game.tray.tiles), "board mate occupies the authoritative tray slot")
	_check(direct_game.board.call("is_tile_face_down", "flipped"), "selecting the board mate turns the revealed tile face-down")
	_check_equal("ordinary", direct_game.call("flipped_match_candidate", "flipped").tile_id, "face-down tile becomes targetable against its held mate")
	_check_equal(GameStateScript.FLIPPED_PAIR_RESOLVED, direct_game.call("tap_tile", "flipped", 300), "tapping the tile back reveals and resolves its held mate")
	_check_equal(0, direct_game.tray.tiles.size(), "flipped-to-tray match clears the held tile atomically")
	_check_equal(1, direct_game.tray.resolved_pair_count, "staged flipped match counts as one pair")
	_check_equal(1, direct_game.call("combo_at", 300), "staged flipped match extends natural Combo")
	_check_equal(GameStateScript.WON, direct_game.status, "staged flipped match can complete the board")
	_check(bool(direct_game.call("last_transaction").telemetry.flipped_pair), "staged match records flipped-pair telemetry")

	var replica := GameStateScript.new(direct_definition)
	for transaction in direct_game.call("transactions"):
		_check(bool(replica.call("apply_transaction", transaction).accepted), "flipped transaction replays")
	_check_equal(direct_game.call("current_snapshot").state_hash(), replica.call("current_snapshot").state_hash(), "flipped timeline reaches authoritative state")
	var reversed: Variant = GameReducerScript.new().call(
		"apply_reverse",
		direct_definition,
		direct_game.call("current_snapshot"),
		direct_game.call("last_transaction")
	)
	_check(reversed != null, "direct flipped match applies in reverse")
	_check_equal([], reversed.revealed_flipped_tile_ids, "reverse restores the face-down tile from before final reveal")
	_check_equal(["ordinary"], reversed.tray_tile_ids, "reverse restores the staged ordinary mate")

	var rules_ten_definition := GameDefinitionScript.new(1, direct_tiles, {"tray_capacity": 4}, 10, [], {}, null, ["flipped"])
	var rules_ten_game := GameStateScript.new(rules_ten_definition)
	_check_equal(GameStateScript.TILE_REVEALED, rules_ten_game.call("reveal_tile", "flipped"), "rules version 10 tile reveals")
	_check_equal(GameStateScript.FLIPPED_PAIR_RESOLVED, rules_ten_game.call("select_tile", "ordinary"), "rules version 10 preserves direct board matching")

	var tray_game := GameStateScript.new(_definition_with_flips(direct_tiles, ["flipped"]))
	_check_equal(GameStateScript.SELECTED, tray_game.call("select_tile", "ordinary", 100), "ordinary mate can enter tray before reveal")
	_check_equal(GameStateScript.FLIPPED_PAIR_RESOLVED, tray_game.call("reveal_tile", "flipped", 200), "revealed tile resolves matching tray tile directly")
	_check_equal(0, tray_game.tray.tiles.size(), "tray-to-flipped match clears held tile atomically")

	var danger_tiles := [
		TileInstanceScript.new("held_a", TileFaceScript.new("test", "held_a"), BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("held_b", TileFaceScript.new("test", "held_b"), BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("held_c", TileFaceScript.new("test", "held_c"), BoardPositionScript.new(16, 0, 0)),
		TileInstanceScript.new("danger_flip", memory_face, BoardPositionScript.new(24, 0, 0)),
		TileInstanceScript.new("danger_mate", memory_face, BoardPositionScript.new(32, 0, 0)),
	]
	var danger_game := GameStateScript.new(_definition_with_flips(danger_tiles, ["danger_flip"]))
	for held_id in ["held_a", "held_b", "held_c"]:
		_check_equal(GameStateScript.SELECTED, danger_game.call("select_tile", held_id), "danger setup fills one tray slot")
	_check_equal(GameStateScript.TILE_REVEALED, danger_game.call("reveal_tile", "danger_flip"), "danger setup reveals its flipped tile")
	_check_equal(GameStateScript.GAME_OVER, danger_game.call("select_tile", "danger_mate"), "board mate cannot bypass a three-tile tray")
	_check_equal(GameStateScript.LOST, danger_game.status, "fourth authoritative tray tile loses normally")
	_check(danger_game.board.call("is_tile_face_down", "danger_flip"), "losing board-mate selection still closes the flipped reveal")
	_check_equal(4, danger_game.tray.tiles.size(), "failed staged match retains all four tray tiles")
	_check_equal(0, danger_game.tray.resolved_pair_count, "failed staged match resolves no free pair")
	var hidden_delete_game := GameStateScript.new(_definition_with_flips(direct_tiles, ["flipped"]))
	_check_equal(GameStateScript.NO_DELETABLE_PAIR, hidden_delete_game.call("delete_pair", "flipped"), "Delete Pair cannot target a hidden tile face")
	_check_equal(1, hidden_delete_game.call("consumable_count", "delete_pair"), "hidden Delete Pair rejection consumes no charge")

	var other_face := TileFaceScript.new("test", "other")
	var memory_tiles := [
		TileInstanceScript.new("memory_flip", memory_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("memory_mate", memory_face, BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("other", other_face, BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("other_mate", other_face, BoardPositionScript.new(12, 0, 0)),
	]
	var mismatch_game := GameStateScript.new(_definition_with_flips(memory_tiles, ["memory_flip"]))
	_check_equal(GameStateScript.TILE_REVEALED, mismatch_game.call("reveal_tile", "memory_flip"), "memory tile reveals before a non-match")
	_check_equal(GameStateScript.SELECTED, mismatch_game.call("select_tile", "other"), "ordinary non-match follows normal tray selection")
	_check(mismatch_game.board.call("is_tile_face_down", "memory_flip"), "ordinary non-match turns the exposed tile face-down")
	_check_equal([], mismatch_game.call("current_snapshot").revealed_flipped_tile_ids, "non-match re-hide is authoritative state")
	_check_equal(GameStateScript.UNDONE, mismatch_game.call("undo_last_unmatched"), "ordinary non-match remains undoable")
	_check(mismatch_game.board.call("is_tile_revealed_flipped", "memory_flip"), "Undo restores the preceding exposed memory tile")

	var two_flip_game := GameStateScript.new(_definition_with_flips(memory_tiles, ["memory_flip", "other"]))
	_check_equal(GameStateScript.TILE_REVEALED, two_flip_game.call("reveal_tile", "memory_flip"), "first non-matching flipped tile reveals")
	_check_equal(GameStateScript.TILE_REVEALED, two_flip_game.call("reveal_tile", "other"), "second non-matching flipped tile reveals")
	_check(two_flip_game.board.call("is_tile_face_down", "memory_flip"), "second non-match turns the first flipped tile face-down")
	_check(two_flip_game.board.call("is_tile_revealed_flipped", "other"), "second non-match remains exposed")
	_check_equal(["other"], two_flip_game.call("current_snapshot").revealed_flipped_tile_ids, "only one unmatched flipped face remains exposed")

	var duplicate_flip_definition: Variant = _definition_with_flips(direct_tiles, ["ordinary", "flipped"])
	_check_equal(["flipped"], duplicate_flip_definition.flipped_tile_ids, "current rules keep at most one flipped tile per face")
	var duplicate_flip_game := GameStateScript.new(duplicate_flip_definition)
	_check_equal(GameStateScript.TILE_REVEALED, duplicate_flip_game.call("reveal_tile", "flipped"), "single flipped mate reveals")
	_check_equal(GameStateScript.SELECTED, duplicate_flip_game.call("select_tile", "ordinary"), "ordinary mate stages before the single flipped tile")
	_check_equal(GameStateScript.FLIPPED_PAIR_RESOLVED, duplicate_flip_game.call("tap_tile", "flipped"), "staged ordinary mate resolves the single flipped tile")
	var legacy_double_definition := GameDefinitionScript.new(1, direct_tiles, {"tray_capacity": 4}, 9, [], {}, null, ["ordinary", "flipped"])
	var legacy_double_game := GameStateScript.new(legacy_double_definition)
	_check_equal(GameStateScript.TILE_REVEALED, legacy_double_game.call("reveal_tile", "flipped"), "rules version 9 first flipped mate reveals")
	_check_equal(GameStateScript.FLIPPED_PAIR_RESOLVED, legacy_double_game.call("reveal_tile", "ordinary"), "rules version 9 preserves flipped-to-flipped matching")

	var blocked_tiles := [
		TileInstanceScript.new("blocked_flip", memory_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("cover", TileFaceScript.new("test", "cover"), BoardPositionScript.new(0, 0, 1)),
	]
	var blocked_game := GameStateScript.new(_definition_with_flips(blocked_tiles, ["blocked_flip"]))
	_check(not blocked_game.board.call("is_tile_revealable", "blocked_flip"), "covered face-down tile is not revealable")
	_check_equal(GameStateScript.INVALID_SELECTION, blocked_game.call("reveal_tile", "blocked_flip"), "inaccessible face-down reveal is rejected")
	_check_equal(0, blocked_game.revision, "rejected reveal appends no transaction")

	var cover_face := TileFaceScript.new("test", "cover_pair")
	var uncover_tiles := [
		TileInstanceScript.new("auto_flip", memory_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("auto_mate", memory_face, BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("cover_first", cover_face, BoardPositionScript.new(0, 0, 1)),
		TileInstanceScript.new("cover_second", cover_face, BoardPositionScript.new(4, 0, 1)),
	]
	var uncover_definition: Variant = _definition_with_flips(uncover_tiles, ["auto_flip"])
	var uncover_game := GameStateScript.new(uncover_definition)
	_check(not uncover_game.board.call("is_tile_revealable", "auto_flip"), "covered auto-flip tile begins inaccessible")
	_check_equal(GameStateScript.SELECTED, uncover_game.call("select_tile", "cover_first"), "removing a covering tile remains an ordinary selection")
	_check(uncover_game.board.call("is_tile_revealed_flipped", "auto_flip"), "newly uncovered face-down tile flips automatically")
	_check_equal(["auto_flip"], uncover_game.call("last_transaction").telemetry.auto_revealed_tile_ids, "selection records deterministic auto-reveal telemetry")
	_check_equal(GameStateScript.UNDONE, uncover_game.call("undo_last_unmatched"), "auto-revealing selection remains undoable")
	_check(not uncover_game.board.call("is_tile_revealable", "auto_flip"), "Undo restores the covering tile and hidden state atomically")
	var legacy_auto_definition := GameDefinitionScript.new(1, uncover_tiles, {"tray_capacity": 4}, 9, [], {}, null, ["auto_flip"])
	var legacy_auto_game := GameStateScript.new(legacy_auto_definition)
	_check_equal(GameStateScript.SELECTED, legacy_auto_game.call("select_tile", "cover_first"), "rules version 9 selection still applies")
	_check(legacy_auto_game.board.call("is_tile_revealable", "auto_flip"), "rules version 9 preserves manual reveal after uncovering")

	var factory := ReferenceGameFactoryScript.new()
	var generated_a: Dictionary = factory.call("create_generated", 44881, 4, {"flipped_tile_count": 12})
	var generated_b: Dictionary = factory.call("create_generated", 44881, 4, {"flipped_tile_count": 12})
	var generated_c: Dictionary = factory.call("create_generated", 44882, 4, {"flipped_tile_count": 12})
	_check_equal(12, generated_a.definition.flipped_tile_ids.size(), "reference configuration assigns requested flipped count")
	_check_equal(generated_a.definition.flipped_tile_ids, generated_b.definition.flipped_tile_ids, "same seed reproduces flipped placement")
	_check(generated_a.definition.flipped_tile_ids != generated_c.definition.flipped_tile_ids, "different seed changes flipped placement")
	var generated_flipped_faces := {}
	for generated_flipped_id in generated_a.definition.flipped_tile_ids:
		generated_flipped_faces[generated_a.definition.get_tile(generated_flipped_id).face.logical_id()] = true
	_check_equal(generated_a.definition.flipped_tile_ids.size(), generated_flipped_faces.size(), "seeded placement flips at most one physical tile per face")
	_check(
		bool(GameSolverScript.new().call("verify_solution", generated_a.definition, generated_a.solution).valid),
		"generated pair certificate remains valid with flipped tiles"
	)
	var shuffled_game := GameStateScript.new(generated_a.definition)
	var revealable_ids: Array = shuffled_game.board.call("revealable_tiles")
	_check(not revealable_ids.is_empty(), "flipped reference game exposes a reveal before Shuffle")
	if not revealable_ids.is_empty():
		var remembered_id: String = revealable_ids[0].id
		_check_equal(GameStateScript.TILE_REVEALED, shuffled_game.call("reveal_tile", remembered_id), "pre-Shuffle tile reveals")
		_check_equal(GameStateScript.SHUFFLED, shuffled_game.call("shuffle"), "Shuffle verifies with an active revealed flipped tile")
		_check(remembered_id in shuffled_game.call("current_snapshot").revealed_flipped_tile_ids, "Shuffle preserves remembered reveal state")


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
	_check_equal(11, definition.rules_version, "tray-staged flipped matching uses rules version 11")
	_check_equal(1, MomentumRulesScript.multiplier_for(19999, configuration), "momentum below first threshold stays x1")
	_check_equal(2, MomentumRulesScript.multiplier_for(20000, configuration), "first threshold enters x2")
	_check(
		90000 - MomentumRulesScript.decay(90000, 100, configuration) \
			> 30000 - MomentumRulesScript.decay(30000, 100, configuration),
		"higher tiers lose more momentum over the same interval"
	)
	var legacy_definition := GameDefinitionScript.new(1, definition.tiles, configuration, 6)
	var legacy_game := GameStateScript.new(legacy_definition)
	legacy_game.call("select_tile", "first", 100)
	_check_equal(0, legacy_game.call("current_snapshot").momentum_units, "rules version 6 preserves pre-selection-gain behavior")
	_check(not legacy_definition.configuration.has("momentum_selection_gain"), "legacy definition identity excludes the newer tuning field")

	var game = GameStateScript.new(definition)
	_check_equal(GameStateScript.INVALID_SELECTION, game.call("select_tile", "missing", 50), "rejected selection awards no momentum")
	_check_equal(0, game.call("current_snapshot").momentum_units, "rejected selection leaves momentum unchanged")
	_check_equal(GameStateScript.SELECTED, game.call("select_tile", "first", 100), "timestamped first selection is accepted")
	_check_equal(2500, game.call("current_snapshot").momentum_units, "accepted selection adds configured momentum")
	_check_equal(2500, game.call("last_transaction").telemetry.momentum_selection_gain, "selection telemetry records its actual gain")
	_check_equal(GameStateScript.PAIR_RESOLVED, game.call("select_tile", "second", 200), "timestamped pair resolves")
	var snapshot: Variant = game.call("current_snapshot")
	_check_equal(34500, snapshot.momentum_units, "pair includes both selection bumps and configured pair momentum")
	_check_equal(100, snapshot.score, "completing selection does not increase its own pair multiplier")
	_check_equal(200, snapshot.elapsed_time_ms, "accepted command materializes gameplay time")
	_check_equal(2, snapshot.max_multiplier, "state records peak multiplier")
	_check_equal(28900, game.call("momentum_at", 1000), "presentation preview applies deterministic decay")
	_check_equal(34500, game.call("current_snapshot").momentum_units, "momentum preview does not mutate authoritative state")

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
	_check_equal(4, second_pair_transaction.telemetry.resulting_multiplier, "consistent selections and pair build x4 for the next pair")
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
	_check_equal(2500, default_overrides.momentum_selection_gain, "Inspector selection gain maps to simulation configuration")
	_check_equal([5, 7, 10, 14, 19], default_overrides.momentum_decay_per_ms, "per-second Inspector decay converts exactly")
	_check_equal(MomentumTuningScript.default_overrides(), default_overrides, "Inspector defaults match headless simulation defaults")

	var custom_tuning: Variant = MomentumTuningScript.new()
	custom_tuning.maximum = 120000
	custom_tuning.pair_gain = 15000
	custom_tuning.selection_gain = 1250
	custom_tuning.multiplier_thresholds.assign([0, 30000, 60000, 90000])
	custom_tuning.decay_per_second.assign([4000, 6000, 9000, 13000])
	custom_tuning.pair_base_score = 250
	_check(custom_tuning.call("validation_errors").is_empty(), "valid custom tuning passes validation")
	var custom_overrides: Dictionary = custom_tuning.call("configuration_overrides")
	var factory := ReferenceGameFactoryScript.new()
	var default_definition: Variant = factory.call("create_definition", 42)
	var custom_definition: Variant = factory.call("create_definition", 42, 4, custom_overrides)
	_check_equal(120000, custom_definition.configuration.momentum_max, "factory applies Inspector maximum")
	_check_equal(1250, custom_definition.configuration.momentum_selection_gain, "factory applies Inspector selection gain")
	_check_equal(250, custom_definition.configuration.pair_base_score, "factory applies Inspector scoring")
	_check_equal(160, custom_definition.configuration.difficulty_notable_min_score, "factory applies Inspector difficulty thresholds")
	_check(default_definition.definition_hash() != custom_definition.definition_hash(), "custom tuning changes definition hash")
	custom_overrides.momentum_thresholds[1] = 1
	_check_equal(30000, custom_tuning.multiplier_thresholds[1], "simulation override cannot mutate Inspector resource")

	custom_tuning.multiplier_thresholds.assign([100, 50])
	custom_tuning.decay_per_second.assign([4500])
	_check(custom_tuning.call("validation_errors").size() >= 3, "invalid thresholds and decay report actionable errors")


func _run_combo_tests() -> void:
	_log(" - deterministic Combo chain")
	var face_a := TileFaceScript.new("combo", "a")
	var face_b := TileFaceScript.new("combo", "b")
	var face_c := TileFaceScript.new("combo", "c")
	var face_d := TileFaceScript.new("combo", "d")
	var face_locked := TileFaceScript.new("combo", "locked")
	var face_cover := TileFaceScript.new("combo", "cover")
	var tiles := [
		TileInstanceScript.new("a_1", face_a, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("a_2", face_a, BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("b_1", face_b, BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("b_2", face_b, BoardPositionScript.new(12, 0, 0)),
		TileInstanceScript.new("c_1", face_c, BoardPositionScript.new(16, 0, 0)),
		TileInstanceScript.new("c_2", face_c, BoardPositionScript.new(20, 0, 0)),
		TileInstanceScript.new("d_1", face_d, BoardPositionScript.new(28, 0, 0)),
		TileInstanceScript.new("d_2", face_d, BoardPositionScript.new(32, 0, 0)),
		TileInstanceScript.new("locked", face_locked, BoardPositionScript.new(24, 0, 0)),
		TileInstanceScript.new("cover", face_cover, BoardPositionScript.new(24, 0, 1)),
	]
	var definition: Variant = _definition(tiles)
	_check(not definition.configuration.has("combo_window_ms"), "current definitions have no Combo timeout tuning")

	var game := GameStateScript.new(definition)
	game.call("select_tile", "a_1", 100)
	game.call("select_tile", "a_2", 200)
	_check_equal(1, game.call("combo_at", 200), "first natural pair starts Combo at one")
	_check_equal(0, game.call("combo_remaining_ms_at", 200), "current Combo has no countdown")
	game.call("select_tile", "c_1", 300)
	_check_equal(1, game.call("combo_at", 300), "ordinary unmatched tray selection preserves Combo")
	game.call("select_tile", "b_1", 400)
	game.call("select_tile", "b_2", 500)
	game.call("select_tile", "c_2", 800)
	_check_equal(3, game.call("combo_at", 800), "successive natural pairs extend Combo")
	_check_equal(3, game.max_combo, "state records peak Combo")
	var revision_before_break: int = game.revision
	_check_equal(GameStateScript.COMBO_BROKEN, game.call("break_combo_for_locked_tile", "locked", 900), "locked tile tap breaks a live Combo")
	_check_equal(revision_before_break + 1, game.revision, "locked tile break appends a transaction")
	_check_equal(0, game.call("combo_at", 900), "locked tile break clears Combo")
	var break_transaction: Variant = game.call("last_transaction")
	_check_equal(GameCommandScript.BREAK_COMBO, break_transaction.command_type, "locked tile break has an explicit command type")
	_check_equal("locked_tile_tap", break_transaction.telemetry.combo_break_reason, "locked tile break records its reason")
	var revision_after_break: int = game.revision
	_check_equal(GameStateScript.INVALID_SELECTION, game.call("break_combo_for_locked_tile", "locked", 950), "locked tap without a live Combo remains a no-op")
	_check_equal(revision_after_break, game.revision, "no-op locked tap does not pollute the timeline")

	var replica := GameStateScript.new(definition)
	for transaction in game.call("transactions"):
		_check(replica.call("apply_transaction", transaction).accepted, "Combo transaction replays")
	_check_equal(game.call("current_snapshot").state_hash(), replica.call("current_snapshot").state_hash(), "Combo timeline replays to the authoritative hash")

	var patient_game := GameStateScript.new(definition)
	patient_game.call("select_tile", "a_1", 100)
	patient_game.call("select_tile", "a_2", 200)
	patient_game.call("select_tile", "b_1", 7100)
	patient_game.call("select_tile", "b_2", 7200)
	_check_equal(2, patient_game.call("combo_at", 7200), "waiting for a pair does not break current Combo")
	_check(not patient_game.call("last_transaction").telemetry.has("combo_break_reason"), "patient pair records no timeout break")

	var legacy_definition := GameDefinitionScript.new(1, tiles, {}, 7)
	var legacy_game := GameStateScript.new(legacy_definition)
	legacy_game.call("select_tile", "a_1", 100)
	legacy_game.call("select_tile", "a_2", 200)
	legacy_game.call("select_tile", "b_1", 7100)
	_check_equal(1, legacy_game.call("combo_at", 7199), "rules version 7 retains its recorded Combo window")
	legacy_game.call("select_tile", "b_2", 7200)
	_check_equal(1, legacy_game.call("combo_at", 7200), "legacy pair at expiry starts a new Combo")
	_check_equal("timeout", legacy_game.call("last_transaction").telemetry.combo_break_reason, "legacy timeout remains replay-compatible")

	var flat_definition: Variant = _definition(tiles.slice(0, 8))
	var hint_game: Variant = _game_with_first_combo(flat_definition)
	_check_equal(GameStateScript.HINTED, hint_game.call("request_hint", 300), "successful Hint is available during Combo")
	_check_equal(0, hint_game.call("combo_at", 300), "Hint breaks Combo")
	var undo_game: Variant = _game_with_first_combo(flat_definition)
	undo_game.call("select_tile", "b_1", 300)
	_check_equal(GameStateScript.UNDONE, undo_game.call("undo_last_unmatched", 400), "successful Undo is available during Combo")
	_check_equal(0, undo_game.call("combo_at", 400), "Undo breaks Combo")
	var delete_game: Variant = _game_with_first_combo(flat_definition)
	_check_equal(GameStateScript.PAIR_DELETED, delete_game.call("delete_pair", "b_1", 300), "successful Delete Pair is available during Combo")
	_check_equal(0, delete_game.call("combo_at", 300), "Delete Pair breaks Combo")
	var shuffle_game: Variant = _game_with_first_combo(flat_definition)
	_check_equal(GameStateScript.SHUFFLED, shuffle_game.call("shuffle", 300), "successful Shuffle is available during Combo")
	_check_equal(0, shuffle_game.call("combo_at", 300), "Shuffle breaks Combo")


func _run_opportunity_analysis_tests() -> void:
	_log(" - deterministic tile and pair opportunity analysis")
	var near_face := TileFaceScript.new("difficulty", "near")
	var far_face := TileFaceScript.new("difficulty", "far")
	var tiles := [
		TileInstanceScript.new("near_1", near_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("near_2", near_face, BoardPositionScript.new(2, 0, 0)),
		TileInstanceScript.new("far_1", far_face, BoardPositionScript.new(0, 10, 0)),
		TileInstanceScript.new("far_2", far_face, BoardPositionScript.new(20, 10, 0)),
	]
	var definition: Variant = _definition(tiles)
	var game := GameStateScript.new(definition)
	var analysis: Dictionary = game.call("opportunity_analysis")
	_check_equal(4, analysis.selectable_tile_count, "analysis scores every selectable tile")
	_check_equal(2, analysis.available_pair_count, "analysis enumerates every selectable matching pair")
	_check_equal("far_1|far_2", analysis.hardest_pair.id, "widely separated pair ranks as the harder opportunity")
	_check_equal(1, analysis.hardest_pair.difficulty_rank, "hardest pair receives rank one")
	_check_equal(10000, analysis.hardest_pair.difficulty_percentile_bps, "hardest pair receives the top deterministic percentile")
	_check(int(analysis.hardest_pair.score) > int(analysis.easiest_pair.score), "pair score distinguishes spatial search difficulty")
	var repeated_analysis: Dictionary = game.call("opportunity_analysis")
	_check_equal(
		JSON.stringify(analysis).sha256_text(),
		JSON.stringify(repeated_analysis).sha256_text(),
		"same board state reproduces identical opportunity scores"
	)

	var transposed_tiles := [
		TileInstanceScript.new("near_1", near_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("near_2", near_face, BoardPositionScript.new(0, 2, 0)),
		TileInstanceScript.new("far_1", far_face, BoardPositionScript.new(10, 0, 0)),
		TileInstanceScript.new("far_2", far_face, BoardPositionScript.new(10, 20, 0)),
	]
	var transposed_game := GameStateScript.new(_definition(transposed_tiles))
	var transposed: Dictionary = transposed_game.call("opportunity_analysis")
	_check_equal(analysis.hardest_pair.score, transposed.hardest_pair.score, "difficulty is independent from portrait or landscape axis")
	_check_equal(analysis.easiest_pair.score, transposed.easiest_pair.score, "axis transposition preserves pair ordering")

	var score_before: int = game.score
	game.call("select_tile", "far_1", 100)
	var first_transaction: Variant = game.call("last_transaction")
	_check_equal(0, first_transaction.telemetry.opportunity.board_revision, "selection records its pre-command board revision")
	_check_equal("far_1", first_transaction.telemetry.opportunity.selected_tile.tile_id, "selection records the chosen tile opportunity")
	_check_equal(1, first_transaction.telemetry.opportunity.selected_pair_options.size(), "selection preserves its available matching-pair observation")
	game.call("select_tile", "far_2", 200)
	var pair_transaction: Variant = game.call("last_transaction")
	_check_equal("board_pair", pair_transaction.telemetry.resolved_pair_opportunity.source, "resolved pair links to its original board opportunity")
	_check_equal("far_1|far_2", pair_transaction.telemetry.resolved_pair_opportunity.id, "resolved pair retains stable physical tile identity")
	_check_equal(1, pair_transaction.telemetry.resolved_pair_opportunity.difficulty_rank, "resolved pair retains its original contextual rank")
	_check_equal(score_before + 100, game.score, "ordinary pair stays at base score")
	_check(not pair_transaction.telemetry.has("difficulty_reward"), "pair below absolute threshold receives no reward")
	var serialized: Variant = JSON.parse_string(JSON.stringify(pair_transaction.to_dict()))
	var parsed: Variant = GameTransactionScript.from_dict(serialized)
	_check_equal("board_pair", parsed.telemetry.resolved_pair_opportunity.source, "pair opportunity source round-trips through transaction JSON")
	_check_equal(66, int(parsed.telemetry.resolved_pair_opportunity.score), "pair difficulty score round-trips through transaction JSON")
	_check_equal(1, int(parsed.telemetry.resolved_pair_opportunity.difficulty_rank), "pair difficulty rank round-trips through transaction JSON")

	var notable_configuration := GameConfigurationScript.create()
	notable_configuration.difficulty_notable_min_score = 60
	notable_configuration.difficulty_notable_min_percentile_basis_points = 10000
	notable_configuration.difficulty_exceptional_min_score = 1000
	notable_configuration.difficulty_exceptional_min_percentile_basis_points = 10000
	var notable_game := GameStateScript.new(GameDefinitionScript.new(1, tiles, notable_configuration))
	notable_game.call("select_tile", "far_1", 100)
	notable_game.call("select_tile", "far_2", 200)
	var notable_transaction: Variant = notable_game.call("last_transaction")
	_check_equal(125, notable_game.score, "notable pair adds the configured 25 percent score bonus")
	_check_equal("notable", notable_transaction.telemetry.difficulty_reward.tier, "qualified pair records notable tier")
	_check_equal("great", notable_transaction.telemetry.difficulty_reward.callout_key, "notable tier emits stable callout key")
	_check_equal(25, notable_transaction.telemetry.difficulty_bonus_score, "transaction records notable bonus separately")
	var notable_parsed: Variant = GameTransactionScript.from_dict(
		JSON.parse_string(JSON.stringify(notable_transaction.to_dict()))
	)
	_check_equal("great", notable_parsed.telemetry.difficulty_reward.callout_key, "difficulty reward round-trips through JSON")

	var exceptional_configuration := notable_configuration.duplicate(true)
	exceptional_configuration.difficulty_exceptional_min_score = 60
	var exceptional_game := GameStateScript.new(GameDefinitionScript.new(1, tiles, exceptional_configuration))
	exceptional_game.call("select_tile", "far_1", 100)
	exceptional_game.call("select_tile", "far_2", 200)
	var exceptional_reward: Dictionary = exceptional_game.call("last_transaction").telemetry.difficulty_reward
	_check_equal(150, exceptional_game.score, "exceptional pair adds the configured 50 percent score bonus")
	_check_equal("exceptional", exceptional_reward.tier, "highest qualified tier wins deterministically")
	_check_equal("eagle_eyes", exceptional_reward.callout_key, "exceptional tier emits stable callout key")

	var held_face := TileFaceScript.new("difficulty", "held")
	var cover_face := TileFaceScript.new("difficulty", "cover")
	var tray_completion_game := GameStateScript.new(_definition([
		TileInstanceScript.new("held", held_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("held_mate", held_face, BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("cover_1", cover_face, BoardPositionScript.new(8, 0, 1)),
		TileInstanceScript.new("cover_2", cover_face, BoardPositionScript.new(12, 0, 1)),
	]))
	tray_completion_game.call("select_tile", "held", 100)
	tray_completion_game.call("select_tile", "cover_1", 200)
	tray_completion_game.call("select_tile", "cover_2", 300)
	tray_completion_game.call("select_tile", "held_mate", 400)
	var tray_completion: Dictionary = tray_completion_game.call("last_transaction").telemetry.resolved_pair_opportunity
	_check_equal("tray_completion", tray_completion.source, "pair revealed after its mate was held is classified separately")
	_check(not tray_completion.has("difficulty_rank"), "tray completion does not invent a historical board-pair rank")
	_check(not tray_completion_game.call("last_transaction").telemetry.has("difficulty_reward"), "tray completion cannot receive board-difficulty reward")


func _run_modifier_tests() -> void:
	_log(" - deterministic M5 modifiers and loadouts")
	var tuning: Variant = load("res://configuration/default_modifier_tuning.tres")
	_check(tuning != null, "default ModifierTuning resource loads")
	_check(tuning.call("validation_errors").is_empty(), "default ModifierTuning resource validates")
	_check_equal(3, tuning.loadout_capacity, "default loadout is limited to three equipped tiles")
	var starter: Array = ModifierLoadoutScript.starter()
	_check_equal(1, starter.size(), "new-player loadout contains one starter modifier")
	_check_equal(ModifierLoadoutScript.SCORE_MULTIPLIER, starter[0].type, "starter modifier is the score multiplier")
	var level_two_effect: Dictionary = ModifierRulesScript.effect_for(
		{"type": ModifierLoadoutScript.SCORE_MULTIPLIER, "level": 2},
		GameConfigurationScript.create()
	)
	_check_equal(2200, level_two_effect.basis_points, "multiplier levels advance exactly from 2.0x to 2.2x")
	var overfilled: Dictionary = ModifierLoadoutScript.normalize([
		{"modifier_id": "a", "type": ModifierLoadoutScript.EXTRA_LIFE, "level": 0},
		{"modifier_id": "b", "type": ModifierLoadoutScript.COLD_SNAP, "level": 0},
		{"modifier_id": "c", "type": ModifierLoadoutScript.SCORE_MULTIPLIER, "level": 0},
		{"modifier_id": "d", "type": ModifierLoadoutScript.TRAY_PLUS_ONE, "level": 0},
	], 3)
	_check(not overfilled.errors.is_empty(), "loadout validation rejects more equipped tiles than capacity")

	var multiplier_face := TileFaceScript.new("modifier", "multiplier")
	var normal_face := TileFaceScript.new("modifier", "normal")
	var third_face := TileFaceScript.new("modifier", "third")
	var fourth_face := TileFaceScript.new("modifier", "fourth")
	var multiplier_tiles := [
		TileInstanceScript.new("boost_a", multiplier_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("boost_b", multiplier_face, BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("normal_a", normal_face, BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("normal_b", normal_face, BoardPositionScript.new(12, 0, 0)),
		TileInstanceScript.new("third_a", third_face, BoardPositionScript.new(16, 0, 0)),
		TileInstanceScript.new("third_b", third_face, BoardPositionScript.new(20, 0, 0)),
		TileInstanceScript.new("fourth_a", fourth_face, BoardPositionScript.new(24, 0, 0)),
		TileInstanceScript.new("fourth_b", fourth_face, BoardPositionScript.new(28, 0, 0)),
	]
	var multiplier_modifier := {"modifier_id": "boost", "type": ModifierLoadoutScript.SCORE_MULTIPLIER, "level": 1}
	var multiplier_definition: Variant = _definition_with_modifiers(
		multiplier_tiles,
		[multiplier_modifier],
		{"boost_a": multiplier_modifier}
	)
	var multiplier_game := GameStateScript.new(multiplier_definition)
	multiplier_game.call("select_tile", "boost_a", 100)
	multiplier_game.call("select_tile", "boost_b", 200)
	_check_equal(2100, multiplier_game.call("current_snapshot").score_multiplier_basis_points, "collecting level 1 activates a 2.1x score effect")
	_check_equal(10200, multiplier_game.call("current_snapshot").score_multiplier_until_ms, "score boost records deterministic active-play expiry")
	multiplier_game.call("select_tile", "normal_a", 300)
	multiplier_game.call("select_tile", "normal_b", 400)
	var boosted_transaction: Variant = multiplier_game.call("last_transaction")
	_check_equal(2100, boosted_transaction.telemetry.score_modifier_basis_points, "subsequent pair telemetry records active 2.1x boost")
	_check_equal(420, boosted_transaction.telemetry.score_gain, "2.1x boost combines exactly with the x2 momentum tier")
	multiplier_game.call("select_tile", "third_a", 11000)
	multiplier_game.call("select_tile", "third_b", 11200)
	_check_equal(1000, multiplier_game.call("last_transaction").telemetry.score_modifier_basis_points, "score boost expires on the authoritative active-play clock")

	var cold_modifier := {"modifier_id": "cold", "type": ModifierLoadoutScript.COLD_SNAP, "level": 0}
	var cold_definition: Variant = _definition_with_modifiers(
		multiplier_tiles,
		[cold_modifier],
		{"boost_a": cold_modifier}
	)
	var cold_game := GameStateScript.new(cold_definition)
	cold_game.call("select_tile", "boost_a", 100)
	cold_game.call("select_tile", "boost_b", 200)
	cold_game.call("select_tile", "normal_a", 5000)
	cold_game.call("select_tile", "normal_b", 6000)
	_check_equal(37000, cold_game.call("last_transaction").telemetry.momentum_after_decay, "Cold Snap freezes committed selection momentum decay")

	var tray_modifier := {"modifier_id": "tray", "type": ModifierLoadoutScript.TRAY_PLUS_ONE, "level": 0}
	var tray_definition: Variant = _definition_with_modifiers(
		multiplier_tiles,
		[tray_modifier],
		{"boost_a": tray_modifier}
	)
	var tray_game := GameStateScript.new(tray_definition)
	tray_game.call("select_tile", "boost_a")
	tray_game.call("select_tile", "boost_b")
	_check_equal(5, tray_game.tray.capacity, "Tray +1 expands the projected capacity")
	_check_equal(3, tray_game.call("current_snapshot").tray_bonus_pairs_remaining, "Tray +1 duration begins after its triggering pair")
	for pair_ids in [["normal_a", "normal_b"], ["third_a", "third_b"], ["fourth_a", "fourth_b"]]:
		tray_game.call("select_tile", pair_ids[0])
		tray_game.call("select_tile", pair_ids[1])
	_check_equal(4, tray_game.tray.capacity, "Tray +1 expires after its configured subsequent pair count")
	_check_equal(0, tray_game.call("current_snapshot").tray_bonus_pairs_remaining, "Tray +1 clears its duration state on expiry")

	var life_face := TileFaceScript.new("modifier", "life")
	var life_tiles := [
		TileInstanceScript.new("life_a", life_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("life_b", life_face, BoardPositionScript.new(4, 0, 0)),
	]
	for index in range(4):
		life_tiles.append(TileInstanceScript.new(
			"risk_%d" % index,
			TileFaceScript.new("risk", str(index)),
			BoardPositionScript.new(8 + index * 4, 0, 0)
		))
	var life_modifier := {"modifier_id": "life", "type": ModifierLoadoutScript.EXTRA_LIFE, "level": 0}
	var life_definition: Variant = _definition_with_modifiers(life_tiles, [life_modifier], {"life_a": life_modifier})
	var life_game := GameStateScript.new(life_definition)
	life_game.call("select_tile", "life_a")
	life_game.call("select_tile", "life_b")
	_check_equal(1, life_game.call("current_snapshot").extra_life_charges, "Extra Life grants its configured recovery charge")
	for index in range(3):
		life_game.call("select_tile", "risk_%d" % index)
	_check_equal(GameStateScript.EXTRA_LIFE_USED, life_game.call("select_tile", "risk_3"), "Extra Life intercepts tray failure")
	_check_equal(GameStateScript.PLAYING, life_game.status, "Extra Life preserves the run")
	_check_equal(0, life_game.tray.tiles.size(), "Extra Life returns unresolved tray tiles to the board")
	_check_equal(0, life_game.call("current_snapshot").extra_life_charges, "Extra Life consumes one charge")

	var factory := ReferenceGameFactoryScript.new()
	var placed_a: Variant = factory.call("create_definition", 99)
	var placed_b: Variant = factory.call("create_definition", 99)
	_check_equal(starter, placed_a.modifier_loadout, "reference games use the starter loadout by default")
	_check_equal(placed_a.modifier_attachments, placed_b.modifier_attachments, "same seed places equipped modifiers identically")
	var serialized_definition: Variant = JSON.parse_string(JSON.stringify(placed_a.to_dict()))
	var parsed_definition: Variant = GameDefinitionScript.from_dict(serialized_definition)
	_check_equal(placed_a.modifier_attachments, parsed_definition.modifier_attachments, "modifier attachments round-trip with the game definition")
	_check_equal(placed_a.definition_hash(), parsed_definition.definition_hash(), "modifier definition replay hash survives serialization")


func _run_consumable_tests() -> void:
	_log(" - deterministic M6 consumables")
	var face_a := TileFaceScript.new("consumable", "a")
	var face_b := TileFaceScript.new("consumable", "b")
	var face_c := TileFaceScript.new("consumable", "c")
	var face_d := TileFaceScript.new("consumable", "d")
	var tiles := [
		TileInstanceScript.new("a_1", face_a, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("b_1", face_b, BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("c_1", face_c, BoardPositionScript.new(8, 0, 0)),
		TileInstanceScript.new("d_1", face_d, BoardPositionScript.new(12, 0, 0)),
		TileInstanceScript.new("a_2", face_a, BoardPositionScript.new(16, 0, 0)),
		TileInstanceScript.new("b_2", face_b, BoardPositionScript.new(20, 0, 0)),
		TileInstanceScript.new("c_2", face_c, BoardPositionScript.new(24, 0, 0)),
		TileInstanceScript.new("d_2", face_d, BoardPositionScript.new(28, 0, 0)),
	]
	var definition: Variant = _definition(tiles)
	_check_equal({"hint": 1, "undo": 1, "delete_pair": 1, "shuffle": 1}, definition.consumable_inventory, "new run snapshots starter consumable quantities")
	var parsed: Variant = GameDefinitionScript.from_dict(JSON.parse_string(JSON.stringify(definition.to_dict())))
	_check_equal(definition.consumable_inventory, parsed.consumable_inventory, "consumable inventory round-trips with definition")
	_check_equal(definition.definition_hash(), parsed.definition_hash(), "consumables participate in replay definition identity")

	var hint_game := GameStateScript.new(definition)
	hint_game.call("select_tile", "a_1")
	_check_equal(GameStateScript.HINTED, hint_game.call("request_hint"), "Hint finds a selectable mate for a tray tile first")
	_check_equal(["a_1", "a_2"], hint_game.call("hinted_tile_ids"), "Hint records the tray-to-board suggestion deterministically")
	_check_equal(0, hint_game.call("consumable_count", "hint"), "successful Hint consumes exactly one Hint")
	_check_equal(1, hint_game.call("consumable_count", "undo"), "Hint never consumes Undo")
	hint_game.call("select_tile", "a_2")
	_check(hint_game.call("hinted_tile_ids").is_empty(), "next accepted action clears the transient Hint")

	var no_pair_tiles := [
		TileInstanceScript.new("only_a", face_a, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("only_b", face_b, BoardPositionScript.new(4, 0, 0)),
	]
	var no_pair_game := GameStateScript.new(_definition(no_pair_tiles))
	no_pair_game.call("select_tile", "only_a")
	var revision_before_hint: int = no_pair_game.revision
	_check_equal(GameStateScript.NO_HINT_AVAILABLE, no_pair_game.call("request_hint"), "Hint reports when no available pair exists")
	_check_equal(revision_before_hint, no_pair_game.revision, "failed Hint records no transaction")
	_check_equal(1, no_pair_game.call("consumable_count", "hint"), "failed Hint consumes no Hint")
	_check_equal(1, no_pair_game.call("consumable_count", "undo"), "failed Hint consumes no Undo")

	var delete_game := GameStateScript.new(definition)
	delete_game.call("select_tile", "a_1")
	var momentum_before_delete: int = delete_game.call("current_snapshot").momentum_units
	_check_equal(GameStateScript.PAIR_DELETED, delete_game.call("delete_pair", "d_2"), "Delete Pair removes a selectable matching pair")
	var delete_snapshot: Variant = delete_game.call("current_snapshot")
	_check_equal(0, delete_snapshot.score, "Delete Pair awards no score")
	_check_equal(momentum_before_delete, delete_snapshot.momentum_units, "Delete Pair awards no additional momentum")
	_check_equal(1, delete_snapshot.resolved_pair_count, "Delete Pair advances resolved pair state")
	_check_equal(0, delete_game.call("consumable_count", "delete_pair"), "successful Delete Pair consumes one charge")
	var revision_after_delete: int = delete_game.revision
	_check(not delete_game.call("can_undo"), "Delete Pair clears prior Undo eligibility")
	_check_equal(GameStateScript.NOTHING_TO_UNDO, delete_game.call("undo_last_unmatched"), "Undo cannot cross a Delete Pair transaction")
	_check_equal(revision_after_delete, delete_game.revision, "Undo blocked by Delete Pair appends no transaction")
	_check_equal(1, delete_game.call("consumable_count", "undo"), "Undo blocked by Delete Pair consumes no charge")
	_check_equal(["a_1"], _tile_ids(delete_game.tray.tiles), "Delete Pair leaves the committed tray tile in place")

	var obstructed_face := TileFaceScript.new("consumable", "obstructed")
	var obstructed_tiles := [
		TileInstanceScript.new("left_blocker", face_b, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("obstructed_a", obstructed_face, BoardPositionScript.new(2, 0, 0)),
		TileInstanceScript.new("right_blocker", face_c, BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("obstructed_b", obstructed_face, BoardPositionScript.new(10, 0, 0)),
		TileInstanceScript.new("partial_upper", face_d, BoardPositionScript.new(11, 1, 1)),
	]
	var obstructed_game := GameStateScript.new(_definition(obstructed_tiles))
	_check(not obstructed_game.board.call("is_tile_selectable", "obstructed_a"), "side-blocked Delete Pair target is not normally movable")
	_check(not obstructed_game.board.call("is_tile_selectable", "obstructed_b"), "partially covered Delete Pair mate is not normally movable")
	_check(obstructed_game.board.call("is_tile_visible", "obstructed_a"), "side-blocked Delete Pair target remains visible")
	_check(obstructed_game.board.call("is_tile_visible", "obstructed_b"), "partially covered Delete Pair mate remains visible")
	_check_equal(GameStateScript.PAIR_DELETED, obstructed_game.call("delete_pair", "obstructed_a"), "Delete Pair removes a visible pair that normal selection cannot move")
	_check(not obstructed_game.board.call("is_tile_active", "obstructed_a"), "Delete Pair resolves the obstructed target")
	_check(not obstructed_game.board.call("is_tile_active", "obstructed_b"), "Delete Pair resolves the obstructed visible mate")

	var hidden_face := TileFaceScript.new("consumable", "hidden")
	var hidden_tiles := [
		TileInstanceScript.new("hidden_target", hidden_face, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("exact_cover", face_b, BoardPositionScript.new(0, 0, 1)),
		TileInstanceScript.new("visible_mate", hidden_face, BoardPositionScript.new(6, 0, 0)),
	]
	var hidden_game := GameStateScript.new(_definition(hidden_tiles))
	_check(not hidden_game.board.call("is_tile_visible", "hidden_target"), "fully covered tile is not a Delete Pair target")
	_check_equal(GameStateScript.NO_DELETABLE_PAIR, hidden_game.call("delete_pair", "hidden_target"), "Delete Pair rejects a fully covered target")
	_check_equal(0, hidden_game.revision, "hidden Delete Pair rejection appends no transaction")
	_check_equal(1, hidden_game.call("consumable_count", "delete_pair"), "hidden Delete Pair rejection consumes no charge")

	var shuffle_game := GameStateScript.new(definition)
	shuffle_game.call("select_tile", "a_1")
	shuffle_game.call("select_tile", "b_1")
	shuffle_game.call("select_tile", "c_1")
	var tray_before: Array = shuffle_game.call("current_snapshot").tray_tile_ids
	_check_equal(3, tray_before.size(), "Shuffle scenario starts with an almost-full tray")
	_check_equal(GameStateScript.SHUFFLED, shuffle_game.call("shuffle"), "Shuffle works with three unresolved tray tiles")
	_check_equal(tray_before, shuffle_game.call("current_snapshot").tray_tile_ids, "Shuffle preserves tray contents and order")
	_check_equal(0, shuffle_game.call("consumable_count", "shuffle"), "successful Shuffle consumes exactly one charge")
	_check(shuffle_game.call("current_snapshot").rng_state != definition.seed, "Shuffle advances deterministic RNG state")
	var repeat_game := GameStateScript.new(definition)
	for tile_id in ["a_1", "b_1", "c_1"]:
		repeat_game.call("select_tile", tile_id)
	repeat_game.call("shuffle")
	_check_equal(shuffle_game.call("current_snapshot").tile_slot_ids, repeat_game.call("current_snapshot").tile_slot_ids, "same state and seed produce the same Shuffle")
	_check_equal(shuffle_game.call("current_snapshot").state_hash(), repeat_game.call("current_snapshot").state_hash(), "deterministic Shuffle reproduces the authoritative state hash")
	var two_tile_tray_game := GameStateScript.new(definition)
	two_tile_tray_game.call("select_tile", "a_1")
	two_tile_tray_game.call("select_tile", "b_1")
	_check_equal(GameStateScript.SHUFFLED, two_tile_tray_game.call("shuffle"), "Shuffle also works with two unresolved tray tiles")

	var undo_game := GameStateScript.new(definition)
	undo_game.call("select_tile", "a_1")
	undo_game.call("undo_last_unmatched")
	_check_equal(0, undo_game.call("consumable_count", "undo"), "successful Undo consumes its own charge")
	undo_game.call("select_tile", "a_1")
	_check_equal(GameStateScript.CONSUMABLE_UNAVAILABLE, undo_game.call("undo_last_unmatched"), "Undo rejects when its run quantity is exhausted")


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
	var portrait_footprint := _layout_grid_footprint(portrait_stack)
	_check(portrait_footprint.y > portrait_footprint.x, "default gameplay layout has a portrait-authored footprint")
	var portrait_layer_counts := {0: 0, 1: 0, 2: 0, 3: 0}
	for position in portrait_stack.positions:
		portrait_layer_counts[position.z] += 1
	_check_equal({0: 42, 1: 31, 2: 17, 3: 6}, portrait_layer_counts, "portrait stack preserves authored layer counts plus one balancing cap")
	_check(not classic.call("has_partial_overlap"), "classic layout remains fully aligned")
	_check(staggered.call("has_partial_overlap"), "staggered layout includes half-tile higher-layer overlap")
	_check(portrait_stack.call("has_partial_overlap"), "portrait stack includes irregular half-tile overlap")
	_check(catalog.call("layout_path", BoardLayoutCatalogScript.PORTRAIT_STACK_96).ends_with(".json"), "authored layout resolves to a data asset")
	var parsed_layout: Variant = BoardLayoutLoaderScript.new().call("from_dict", portrait_stack.to_dict())
	_check(parsed_layout != null, "expanded layout data round-trips through loader")
	_check_equal(portrait_stack.content_hash(), parsed_layout.content_hash(), "layout round-trip preserves geometry hash")
	var reordered_positions: Array = portrait_stack.positions
	reordered_positions.reverse()
	var reordered_layout := BoardLayoutScript.new(portrait_stack.id, reordered_positions, portrait_stack.revision)
	_check_equal(portrait_stack.content_hash(), reordered_layout.content_hash(), "source ordering does not change canonical layout identity")
	_check_equal(portrait_stack.slots[0].id, reordered_layout.slots[0].id, "coordinate-derived slot ids remain stable after reordering")

	var invalid_layout := BoardLayoutScript.new("invalid", [
		BoardPositionScript.new(0, 0, 0),
		BoardPositionScript.new(1, 0, 0),
	])
	_check(not invalid_layout.call("validation_errors").is_empty(), "same-layer physical overlap is rejected")

	var factory := ReferenceGameFactoryScript.new()
	var solver := GameSolverScript.new()
	for layout_id in catalog.call("layout_ids"):
		var authored_layout: Variant = catalog.call("get_layout", layout_id)
		var generated: Dictionary = factory.call("create_generated", 92817361, 4, {}, layout_id)
		var definition: Variant = generated.definition
		_check_equal(layout_id, definition.configuration.layout_id, "%s id is embedded in definition" % layout_id)
		_check_equal(authored_layout.revision, definition.configuration.layout_revision, "%s revision is embedded in definition" % layout_id)
		_check_equal(authored_layout.content_hash(), definition.configuration.layout_hash, "%s geometry hash is embedded in definition" % layout_id)
		var certificate_result: Dictionary = solver.call("verify_solution", definition, generated.solution)
		_check(certificate_result.valid, "%s generated certificate wins through transactions: %s" % [layout_id, certificate_result.reason])
		var solved: Array[String] = solver.call("find_pair_solution", definition)
		_check_equal(definition.tiles.size(), solved.size(), "%s independent solver finds every selection" % layout_id)
		_check(solver.call("verify_solution", definition, solved).valid, "%s independent solution replays to a win" % layout_id)

	var classic_definition: Variant = factory.call("create_definition", 77, 4, {}, BoardLayoutCatalogScript.CLASSIC_96)
	var staggered_definition: Variant = factory.call("create_definition", 77, 4, {}, BoardLayoutCatalogScript.STAGGERED_96)
	_check(classic_definition.definition_hash() != staggered_definition.definition_hash(), "layout geometry participates in definition identity")

	var requirements: Variant = BoardLayoutRequirementsScript.load_file("res://configuration/layout_requirements/portrait_diamond_96.json")
	_check(requirements != null, "procedural requirements load from JSON")
	_check(requirements.call("validation_errors").is_empty(), "procedural requirements validate")
	var procedural_generator := ProceduralLayoutGeneratorScript.new()
	var generated_layout: Variant = procedural_generator.call("generate", requirements, 4242)
	_check(generated_layout != null, "requirements generate a board layout")
	_check_equal(96, generated_layout.positions.size(), "procedural layout satisfies tile count")
	_check_equal({0: 42, 1: 30, 2: 18, 3: 6}, _layout_layer_counts(generated_layout), "procedural layout satisfies layer distribution")
	_check(_is_horizontally_symmetric(generated_layout), "procedural layout satisfies horizontal symmetry")
	_check(_all_upper_slots_supported(generated_layout), "procedural upper slots overlap their immediate lower layer")
	_check(generated_layout.call("has_partial_overlap"), "procedural inset layers create partial overlap")
	var repeated_layout: Variant = procedural_generator.call("generate", requirements, 4242)
	var alternate_layout: Variant = procedural_generator.call("generate", requirements, 4243)
	_check_equal(generated_layout.content_hash(), repeated_layout.content_hash(), "same requirements seed reproduces geometry")
	_check(generated_layout.content_hash() != alternate_layout.content_hash(), "different requirements seed varies geometry")

	var procedural_game: Dictionary = factory.call("create_generated_for_layout", 92817361, generated_layout)
	_check_equal(generated_layout.content_hash(), procedural_game.definition.configuration.layout_hash, "procedural geometry hash reaches game definition")
	_check(solver.call("verify_solution", procedural_game.definition, procedural_game.solution).valid, "procedural solution certificate replays to a win")
	var procedural_solution: Array[String] = solver.call("find_pair_solution", procedural_game.definition)
	_check_equal(96, procedural_solution.size(), "independent solver clears procedural layout")

	for shape in BoardLayoutRequirementsScript.SHAPES:
		var shape_requirements := BoardLayoutRequirementsScript.new(
			"generated_%s_96" % shape,
			96,
			6,
			7,
			[42, 30, 18, 6],
			shape
		)
		_check(procedural_generator.call("generate", shape_requirements, 101) != null, "%s shape generates a planned layout" % shape)

	var invalid_requirements := BoardLayoutRequirementsScript.new("invalid", 95, 6, 7, [42, 30, 17, 6])
	_check(not invalid_requirements.call("validation_errors").is_empty(), "odd or inconsistent procedural requirements are rejected")


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
	_check_equal(48, fast_result.max_combo, "fast pair-aware play maintains Combo through the board")
	_check_equal(48, slow_result.max_combo, "Combo chain remains independent from Momentum speed")
	_check_equal(48, fast_result.analyzed_pair_count, "pair-aware simulation analyzes every resolved board pair")
	_check(fast_result.average_pair_difficulty > 0, "simulation reports average selected-pair difficulty")
	_check(fast_result.hardest_pair_difficulty >= fast_result.average_pair_difficulty, "simulation reports a valid hardest selected pair")
	_check(fast_result.difficulty_reward_count > 0, "reference simulation recognizes qualified hard pairs")
	_check(fast_result.difficulty_bonus_score > 0, "reference simulation reports awarded difficulty score")
	_check_equal(
		fast_result.difficulty_reward_count,
		int(fast_result.difficulty_reward_tiers.notable) + int(fast_result.difficulty_reward_tiers.exceptional),
		"simulation reports every difficulty reward by tier"
	)
	var hunting_result: Dictionary = simulator.call("run", 92817361, GameSimulatorScript.PAIR_AWARE, {"selection_interval_ms": 4000})
	_check_equal(48, hunting_result.max_combo, "waiting to hunt for pairs no longer breaks Combo")
	var flipped_result: Dictionary = simulator.call(
		"run",
		92817361,
		GameSimulatorScript.PAIR_AWARE,
		{"selection_interval_ms": 450, "flipped_tile_count": 12}
	)
	_check_equal(GameStateScript.WON, flipped_result.status, "pair-aware policy clears a 12-flipped-tile game")
	_check_equal(48, flipped_result.pairs, "flipped simulation resolves every pair")
	_check(flipped_result.max_tray < 4, "flipped direct matches preserve tray safety in verified route")


func _definition(tiles: Array, tray_capacity: int = 4) -> Variant:
	return GameDefinitionScript.new(1, tiles, {"tray_capacity": tray_capacity})


func _definition_with_flips(tiles: Array, flipped_tile_ids: Array) -> Variant:
	return GameDefinitionScript.new(
		1,
		tiles,
		{"tray_capacity": 4},
		GameDefinitionScript.CURRENT_RULES_VERSION,
		[],
		{},
		null,
		flipped_tile_ids
	)


func _game_with_first_combo(definition: Variant) -> Variant:
	var game := GameStateScript.new(definition)
	game.call("select_tile", "a_1", 100)
	game.call("select_tile", "a_2", 200)
	return game


func _definition_with_modifiers(tiles: Array, loadout: Array, attachments: Dictionary) -> Variant:
	return GameDefinitionScript.new(
		1,
		tiles,
		GameConfigurationScript.create(),
		GameDefinitionScript.CURRENT_RULES_VERSION,
		loadout,
		attachments
	)


func _deal_signature(definition: Variant) -> String:
	var identities: Array[String] = []
	for tile in definition.tiles:
		identities.append(tile.face.logical_id())
	return "|".join(identities)


func _unique_strings(values: Array[String]) -> Dictionary:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique


func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile in tiles:
		ids.append(tile.id)
	return ids


func _layout_layer_counts(layout: Variant) -> Dictionary:
	var counts := {}
	for position in layout.positions:
		counts[position.z] = counts.get(position.z, 0) + 1
	return counts


func _layout_grid_footprint(layout: Variant) -> Vector2i:
	var positions: Array = layout.positions
	var minimum_x: int = positions[0].x
	var maximum_x: int = positions[0].x
	var minimum_y: int = positions[0].y
	var maximum_y: int = positions[0].y
	for position in positions:
		minimum_x = mini(minimum_x, position.x)
		maximum_x = maxi(maximum_x, position.x)
		minimum_y = mini(minimum_y, position.y)
		maximum_y = maxi(maximum_y, position.y)
	return Vector2i(maximum_x - minimum_x + 2, maximum_y - minimum_y + 2)


func _is_horizontally_symmetric(layout: Variant) -> bool:
	var positions: Array = layout.positions
	var minimum_x: int = positions[0].x
	var maximum_x: int = positions[0].x
	var keys := {}
	for position in positions:
		minimum_x = mini(minimum_x, position.x)
		maximum_x = maxi(maximum_x, position.x)
		keys[position.to_key()] = true
	for position in positions:
		var mirror_key := "%d,%d,%d" % [minimum_x + maximum_x - position.x, position.y, position.z]
		if not keys.has(mirror_key):
			return false
	return true


func _all_upper_slots_supported(layout: Variant) -> bool:
	var positions: Array = layout.positions
	for position in positions:
		if position.z == 0:
			continue
		var supported := false
		for lower in positions:
			if lower.z == position.z - 1 and position.overlaps_footprint(lower):
				supported = true
				break
		if not supported:
			return false
	return true


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
