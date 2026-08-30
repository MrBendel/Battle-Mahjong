extends RefCounted

const GameConfigurationScript := preload("res://scripts/simulation/game_configuration.gd")
const ConsumableInventoryScript := preload("res://scripts/simulation/consumable_inventory.gd")

const SCHEMA_VERSION := 4
const CURRENT_RULES_VERSION := 15
const LEGACY_COMBO_WINDOW_MS := 7000

var seed: int
var rules_version: int
var configuration: Dictionary
var tiles: Array
var modifier_loadout: Array
var modifier_attachments: Dictionary
var consumable_inventory: Dictionary
var flipped_tile_ids: Array[String] = []
var _tiles_by_id: Dictionary = {}
var _definition_hash := ""


func _init(
		game_seed: int,
		tile_definitions: Array,
		game_configuration: Dictionary,
		game_rules_version: int = CURRENT_RULES_VERSION,
		game_modifier_loadout: Array = [],
		game_modifier_attachments: Dictionary = {},
		game_consumable_inventory: Variant = null,
		game_flipped_tile_ids: Array = []
) -> void:
	seed = game_seed
	rules_version = game_rules_version
	tiles = tile_definitions.duplicate()
	configuration = GameConfigurationScript.create()
	configuration.merge(game_configuration, true)
	if rules_version < 7:
		configuration.erase("momentum_selection_gain")
	if rules_version < 8:
		if not configuration.has("combo_window_ms"):
			configuration["combo_window_ms"] = LEGACY_COMBO_WINDOW_MS
	else:
		configuration.erase("combo_window_ms")
	if rules_version < 9:
		configuration.erase("flipped_tile_count")
	_normalize_configuration_numbers()
	modifier_loadout = []
	for modifier in game_modifier_loadout:
		if modifier is Dictionary:
			modifier_loadout.append(_normalize_modifier(modifier))
	modifier_attachments = {}
	for tile_id in game_modifier_attachments:
		var modifier: Variant = game_modifier_attachments[tile_id]
		if modifier is Dictionary:
			modifier_attachments[str(tile_id)] = _normalize_modifier(modifier)
	var inventory: Dictionary = ConsumableInventoryScript.starter() if game_consumable_inventory == null else game_consumable_inventory
	var normalized_inventory: Dictionary = ConsumableInventoryScript.normalize(inventory)
	consumable_inventory = normalized_inventory.inventory
	for tile in tiles:
		_tiles_by_id[tile.id] = tile
	var seen_flipped_ids := {}
	var seen_flipped_faces := {}
	if rules_version >= 9:
		var candidate_flipped_ids: Array[String] = []
		for tile_id_value in game_flipped_tile_ids:
			candidate_flipped_ids.append(str(tile_id_value))
		candidate_flipped_ids.sort()
		for tile_id in candidate_flipped_ids:
			if not _tiles_by_id.has(tile_id) or seen_flipped_ids.has(tile_id):
				continue
			var face_id: String = _tiles_by_id[tile_id].face.logical_id()
			if rules_version >= 10 and seen_flipped_faces.has(face_id):
				continue
			flipped_tile_ids.append(tile_id)
			seen_flipped_ids[tile_id] = true
			seen_flipped_faces[face_id] = true
	flipped_tile_ids.sort()
	if rules_version >= 9:
		configuration["flipped_tile_count"] = flipped_tile_ids.size()


func get_tile(tile_id: String) -> Variant:
	return _tiles_by_id.get(tile_id)


func tray_capacity() -> int:
	return int(configuration.get("tray_capacity", 4))


func modifier_for_tile(tile_id: String) -> Dictionary:
	return modifier_attachments.get(tile_id, {}).duplicate(true)


func _normalize_modifier(modifier: Dictionary) -> Dictionary:
	return {
		"modifier_id": str(modifier.get("modifier_id", "")),
		"type": str(modifier.get("type", "")),
		"level": int(modifier.get("level", 0)),
	}


func _normalize_configuration_numbers() -> void:
	var integer_keys := [
		"tray_capacity",
		"momentum_max",
		"momentum_pair_gain",
		"momentum_selection_gain",
		"pair_base_score",
		"combo_window_ms",
		"difficulty_notable_min_score",
		"difficulty_notable_min_percentile_basis_points",
		"difficulty_notable_bonus_basis_points",
		"difficulty_exceptional_min_score",
		"difficulty_exceptional_min_percentile_basis_points",
		"difficulty_exceptional_bonus_basis_points",
		"layout_revision",
		"modifier_loadout_capacity",
		"modifier_extra_life_base_charges",
		"modifier_extra_life_charges_per_level",
		"modifier_cold_snap_base_duration_ms",
		"modifier_cold_snap_duration_ms_per_level",
		"modifier_score_multiplier_base_basis_points",
		"modifier_score_multiplier_basis_points_per_level",
		"modifier_score_multiplier_duration_ms",
		"modifier_tray_plus_one_base_pairs",
		"modifier_tray_plus_one_pairs_per_level",
		"modifier_three_pair_clear_base_pairs",
		"modifier_three_pair_clear_pairs_per_level",
		"flipped_tile_count",
	]
	for key in integer_keys:
		if configuration.has(key):
			configuration[key] = int(configuration[key])
	for key in ["momentum_thresholds", "momentum_decay_per_ms"]:
		if not configuration.has(key):
			continue
		var normalized_values: Array[int] = []
		for value in configuration[key]:
			normalized_values.append(int(value))
		configuration[key] = normalized_values


func to_dict() -> Dictionary:
	var serialized_tiles: Array = []
	for tile in tiles:
		serialized_tiles.append({
			"tile_id": tile.id,
			"face_family": tile.face.family,
			"face_value": tile.face.value,
			"position": {"x": tile.position.x, "y": tile.position.y, "z": tile.position.z},
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"rules_version": rules_version,
		"seed": seed,
		"configuration": configuration.duplicate(true),
		"tiles": serialized_tiles,
		"modifier_loadout": modifier_loadout.duplicate(true),
		"modifier_attachments": modifier_attachments.duplicate(true),
		"consumable_inventory": consumable_inventory.duplicate(true),
		"flipped_tile_ids": flipped_tile_ids.duplicate(),
	}


func definition_hash() -> String:
	if not _definition_hash.is_empty():
		return _definition_hash

	var configuration_keys: Array = configuration.keys()
	configuration_keys.sort()
	var configuration_parts: Array[String] = []
	for key in configuration_keys:
		configuration_parts.append("%s=%s" % [key, JSON.stringify(configuration[key])])

	var sorted_tiles := tiles.duplicate()
	sorted_tiles.sort_custom(func(a: Variant, b: Variant) -> bool: return a.id < b.id)
	var tile_parts: Array[String] = []
	for tile in sorted_tiles:
		tile_parts.append("%s=%s:%s@%d,%d,%d" % [
			tile.id,
			tile.face.family,
			tile.face.value,
			tile.position.x,
			tile.position.y,
			tile.position.z,
		])
	var attachment_ids: Array = modifier_attachments.keys()
	attachment_ids.sort()
	var attachment_parts: Array[String] = []
	for tile_id in attachment_ids:
		var modifier: Dictionary = modifier_attachments[tile_id]
		attachment_parts.append("%s=%s:%s:%d" % [
			tile_id,
			str(modifier.get("modifier_id", "")),
			str(modifier.get("type", "")),
			int(modifier.get("level", 0)),
		])
	var loadout_parts: Array[String] = []
	for modifier in modifier_loadout:
		loadout_parts.append("%s:%s:%d" % [
			str(modifier.get("modifier_id", "")),
			str(modifier.get("type", "")),
			int(modifier.get("level", 0)),
		])
	var consumable_parts: Array[String] = []
	for consumable_type in ConsumableInventoryScript.TYPES:
		consumable_parts.append("%s=%d" % [consumable_type, int(consumable_inventory[consumable_type])])
	var hash_parts: Array[String] = [
		str(rules_version),
		str(seed),
		",".join(configuration_parts),
		",".join(tile_parts),
		",".join(loadout_parts),
		",".join(attachment_parts),
		",".join(consumable_parts),
	]
	if rules_version >= 9:
		hash_parts.append(",".join(flipped_tile_ids))
	_definition_hash = "|".join(hash_parts).sha256_text()
	return _definition_hash


static func from_dict(data: Dictionary) -> RefCounted:
	var schema_version := int(data.get("schema_version", 0))
	if schema_version not in [1, 2, 3, SCHEMA_VERSION]:
		return null
	var position_script: Script = load("res://scripts/simulation/board_position.gd")
	var face_script: Script = load("res://scripts/simulation/tile_face.gd")
	var tile_script: Script = load("res://scripts/simulation/tile_instance.gd")
	var parsed_tiles: Array = []
	for serialized_tile in data.get("tiles", []):
		var position: Dictionary = serialized_tile.get("position", {})
		parsed_tiles.append(tile_script.new(
			str(serialized_tile.get("tile_id", "")),
			face_script.new(str(serialized_tile.get("face_family", "")), str(serialized_tile.get("face_value", ""))),
			position_script.new(int(position.get("x", 0)), int(position.get("y", 0)), int(position.get("z", 0)))
		))
	var script: Script = load("res://scripts/simulation/game_definition.gd")
	return script.new(
		int(data.get("seed", 0)),
		parsed_tiles,
		data.get("configuration", {}),
		int(data.get("rules_version", CURRENT_RULES_VERSION)),
		data.get("modifier_loadout", []),
		data.get("modifier_attachments", {}),
		data.get("consumable_inventory", null),
		data.get("flipped_tile_ids", [])
	)
