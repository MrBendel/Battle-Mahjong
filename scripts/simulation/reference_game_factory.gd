extends RefCounted

const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")
const GameDefinitionScript := preload("res://scripts/simulation/game_definition.gd")
const GameConfigurationScript := preload("res://scripts/simulation/game_configuration.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")
const BoardLayoutCatalogScript := preload("res://scripts/simulation/board_layout_catalog.gd")
const LayoutSolutionPlannerScript := preload("res://scripts/simulation/layout_solution_planner.gd")

const IDENTITY_COUNT := 24
const COPIES_PER_IDENTITY := 4
const PAIR_COUNT := 48
const TILE_COUNT := 96

func create_definition(
		seed: int,
		tray_capacity: int = 4,
		configuration_overrides: Dictionary = {},
		layout_id: String = BoardLayoutCatalogScript.DEFAULT_LAYOUT_ID
) -> Variant:
	return create_generated(seed, tray_capacity, configuration_overrides, layout_id).definition


func create_generated(
		seed: int,
		tray_capacity: int = 4,
		configuration_overrides: Dictionary = {},
		layout_id: String = BoardLayoutCatalogScript.DEFAULT_LAYOUT_ID
) -> Dictionary:
	var layout: Variant = BoardLayoutCatalogScript.new().call("get_layout", layout_id)
	if layout == null:
		push_error("Unknown board layout: %s" % layout_id)
		return {}
	var placement_pairs: Array = LayoutSolutionPlannerScript.new().call("build_plan", layout)
	if placement_pairs.size() * 2 != layout.positions.size():
		push_error("Board layout has no complete pair-removal plan: %s" % layout_id)
		return {}
	var pair_faces := _build_pair_faces()
	_shuffle(pair_faces, DeterministicRngScript.new(seed))

	var tiles: Array = []
	tiles.resize(layout.positions.size())
	var solution: Array[String] = []
	for pair_index in range(placement_pairs.size()):
		var face: Variant = pair_faces[pair_index]
		var position_indexes: Array = placement_pairs[pair_index]
		for copy_index in range(2):
			var tile_number: int = position_indexes[copy_index]
			var tile_id := "tile_%03d" % tile_number
			tiles[tile_number] = TileInstanceScript.new(
				tile_id,
				face,
				layout.positions[tile_number]
			)
			solution.append(tile_id)

	var configuration := GameConfigurationScript.create(tray_capacity)
	configuration.merge(configuration_overrides, true)
	configuration["layout_id"] = layout.id
	return {
		"definition": GameDefinitionScript.new(seed, tiles, configuration),
		"solution": solution,
	}


func _build_pair_faces() -> Array:
	var faces: Array = []
	for identity_index in range(IDENTITY_COUNT):
		var face = TileFaceScript.new("reference", "%02d" % (identity_index + 1))
		for _pair_copy in range(COPIES_PER_IDENTITY / 2):
			faces.append(face)

	return faces


func _shuffle(values: Array, rng: Variant) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.call("range_int", 0, index)
		var value: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
