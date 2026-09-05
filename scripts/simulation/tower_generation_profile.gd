extends RefCounted

const SCHEMA_VERSION := 1

var id: String
var revision: int
var requirements_path: String
var floor_count: int
var candidate_count: int
var tray_capacity: int
var difficulty_weights: Dictionary
var deal_options: Dictionary


func _init(
		profile_id: String,
		profile_requirements_path: String,
		profile_floor_count: int,
		profile_candidate_count: int,
		profile_tray_capacity: int = 4,
		profile_revision: int = 1,
		profile_difficulty_weights: Dictionary = {},
		profile_deal_options: Dictionary = {}
) -> void:
	id = profile_id
	revision = profile_revision
	requirements_path = profile_requirements_path
	floor_count = profile_floor_count
	candidate_count = profile_candidate_count
	tray_capacity = profile_tray_capacity
	difficulty_weights = profile_difficulty_weights.duplicate(true)
	deal_options = profile_deal_options.duplicate(true)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("profile id must not be empty")
	if revision < 1:
		errors.append("profile revision must be positive")
	if requirements_path.is_empty():
		errors.append("requirements path must not be empty")
	if floor_count <= 0:
		errors.append("floor count must be positive")
	if candidate_count < floor_count:
		errors.append("candidate count must be at least floor count")
	if tray_capacity < 2:
		errors.append("tray capacity must be at least two")
	for key in [
		"average_pair_difficulty_bps",
		"peak_pair_difficulty_bps",
		"constrained_route_step_points",
		"low_pair_availability_target",
		"low_pair_availability_points",
	]:
		if not difficulty_weights.has(key) or int(difficulty_weights[key]) < 0:
			errors.append("difficulty weight %s must be a non-negative integer" % key)
	if int(deal_options.get("unique_tile_count", 0)) <= 0:
		errors.append("unique tile count must be positive")
	var shuffle_basis_points := int(deal_options.get("shuffle_basis_points", -1))
	if shuffle_basis_points < 0 or shuffle_basis_points > 10000:
		errors.append("shuffle basis points must be between zero and 10000")
	if not deal_options.has("randomize_removal_pairs") \
			or not deal_options.randomize_removal_pairs is bool:
		errors.append("randomize removal pairs must be a boolean")
	return errors


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": id,
		"revision": revision,
		"requirements_path": requirements_path,
		"floor_count": floor_count,
		"candidate_count": candidate_count,
		"tray_capacity": tray_capacity,
		"difficulty_weights": difficulty_weights.duplicate(true),
		"deal_options": deal_options.duplicate(true),
	}


func content_hash() -> String:
	return JSON.stringify(to_dict()).sha256_text()


static func from_dict(data: Dictionary) -> RefCounted:
	var script: Script = load("res://scripts/simulation/tower_generation_profile.gd")
	return script.new(
		str(data.get("profile_id", "")),
		str(data.get("requirements_path", "")),
		int(data.get("floor_count", 0)),
		int(data.get("candidate_count", 0)),
		int(data.get("tray_capacity", 4)),
		int(data.get("revision", 1)),
		data.get("difficulty_weights", {}),
		data.get("deal_options", {})
	)


static func load_file(path: String) -> RefCounted:
	if not FileAccess.file_exists(path):
		push_error("Tower generation profile does not exist: %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("Invalid Tower generation profile: %s" % path)
		return null
	return from_dict(data)
