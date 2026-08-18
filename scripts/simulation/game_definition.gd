extends RefCounted

const GameConfigurationScript := preload("res://scripts/simulation/game_configuration.gd")

const SCHEMA_VERSION := 1
const CURRENT_RULES_VERSION := 1

var seed: int
var rules_version: int
var configuration: Dictionary
var tiles: Array
var _tiles_by_id: Dictionary = {}
var _definition_hash := ""


func _init(
		game_seed: int,
		tile_definitions: Array,
		game_configuration: Dictionary,
		game_rules_version: int = CURRENT_RULES_VERSION
) -> void:
	seed = game_seed
	rules_version = game_rules_version
	tiles = tile_definitions.duplicate()
	configuration = GameConfigurationScript.create()
	configuration.merge(game_configuration, true)
	for tile in tiles:
		_tiles_by_id[tile.id] = tile


func get_tile(tile_id: String) -> Variant:
	return _tiles_by_id.get(tile_id)


func tray_capacity() -> int:
	return int(configuration.get("tray_capacity", 4))


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
	_definition_hash = ("%d|%d|%s|%s" % [rules_version, seed, ",".join(configuration_parts), ",".join(tile_parts)]).sha256_text()
	return _definition_hash


static func from_dict(data: Dictionary) -> RefCounted:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
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
		int(data.get("rules_version", CURRENT_RULES_VERSION))
	)
