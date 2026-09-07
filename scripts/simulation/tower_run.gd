extends RefCounted
class_name TowerRun

const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")
const FLOOR_SEED_STRIDE := 104729

var run_seed: int
var floor_number := 1
var requirements_path: String
var tray_capacity: int
var unique_tile_count_start: int
var unique_tile_count_per_floor: int
var unique_tile_count_max: int
var shuffle_basis_points_start: int
var shuffle_basis_points_per_floor: int
var shuffle_basis_points_max: int


func _init(seed: int, configuration: Dictionary) -> void:
	run_seed = seed
	requirements_path = str(configuration.get("requirements_path", ""))
	tray_capacity = int(configuration.get("tray_capacity", 4))
	unique_tile_count_start = int(configuration.get("unique_tile_count_start", 12))
	unique_tile_count_per_floor = int(configuration.get("unique_tile_count_per_floor", 1))
	unique_tile_count_max = int(configuration.get("unique_tile_count_max", 24))
	shuffle_basis_points_start = int(configuration.get("shuffle_basis_points_start", 4000))
	shuffle_basis_points_per_floor = int(configuration.get("shuffle_basis_points_per_floor", 500))
	shuffle_basis_points_max = int(configuration.get("shuffle_basis_points_max", 10000))


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if requirements_path.is_empty():
		errors.append("requirements path must not be empty")
	if tray_capacity < 2:
		errors.append("tray capacity must be at least two")
	if unique_tile_count_start <= 0 or unique_tile_count_start > unique_tile_count_max:
		errors.append("unique tile count range is invalid")
	if unique_tile_count_per_floor < 0:
		errors.append("unique tile count growth must not be negative")
	if shuffle_basis_points_start < 0 or shuffle_basis_points_start > shuffle_basis_points_max \
			or shuffle_basis_points_max > 10000:
		errors.append("shuffle basis point range is invalid")
	if shuffle_basis_points_per_floor < 0:
		errors.append("shuffle growth must not be negative")
	return errors


func floor_spec() -> Dictionary:
	var rng := DeterministicRngScript.new(run_seed + (floor_number - 1) * FLOOR_SEED_STRIDE)
	var layout_seed: int = rng.next_int()
	var deal_seed: int = rng.next_int()
	return {
		"floor_number": floor_number,
		"layout_seed": layout_seed,
		"deal_seed": deal_seed,
		"requirements_path": requirements_path,
		"tray_capacity": tray_capacity,
		"deal_options": {
			"unique_tile_count": mini(
				unique_tile_count_max,
				unique_tile_count_start + (floor_number - 1) * unique_tile_count_per_floor
			),
			"shuffle_basis_points": mini(
				shuffle_basis_points_max,
				shuffle_basis_points_start + (floor_number - 1) * shuffle_basis_points_per_floor
			),
			"randomize_removal_pairs": true,
		},
	}


func advance() -> void:
	floor_number += 1


static func load_configuration(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Tower runtime configuration does not exist: %s" % path)
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("schema_version", 0)) != 1:
		push_error("Tower runtime configuration must contain a JSON object: %s" % path)
		return {}
	return data
