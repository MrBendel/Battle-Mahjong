extends RefCounted

const GameConfigurationScript := preload("res://scripts/simulation/game_configuration.gd")
const ConsumableInventoryScript := preload("res://scripts/simulation/consumable_inventory.gd")

const SCHEMA_VERSION := 3
const CURRENT_RULES_VERSION := 4

var seed: int
var rules_version: int
var configuration: Dictionary
var tiles: Array
var modifier_loadout: Array
var modifier_attachments: Dictionary
var consumable_inventory: Dictionary
var _tiles_by_id: Dictionary = {}
var _definition_hash := ""


func _init(
		game_seed: int,
		tile_definitions: Array,
		game_configuration: Dictionary,
		game_rules_version: int = CURRENT_RULES_VERSION,
		game_modifier_loadout: Array = [],
		game_modifier_attachments: Dictionary = {},
		game_consumable_inventory: Variant = null
) -> void:
	seed = game_seed
	rules_version = game_rules_version
	tiles = tile_definitions.duplicate()
	configuration = GameConfigurationScript.create()
	configuration.merge(game_configuration, true)
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
		"pair_base_score",
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
	_definition_hash = ("%d|%d|%s|%s|%s|%s|%s" % [
		rules_version,
		seed,
		",".join(configuration_parts),
		",".join(tile_parts),
		",".join(loadout_parts),
		",".join(attachment_parts),
		",".join(consumable_parts),
	]).sha256_text()
	return _definition_hash


static func from_dict(data: Dictionary) -> RefCounted:
	var schema_version := int(data.get("schema_version", 0))
	if schema_version not in [1, 2, SCHEMA_VERSION]:
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
		data.get("consumable_inventory", null)
	)
