extends RefCounted

const SCHEMA_VERSION := 1
const SHAPE_RECTANGLE := "rectangle"
const SHAPE_ELLIPSE := "ellipse"
const SHAPE_DIAMOND := "diamond"
const SHAPES := [SHAPE_RECTANGLE, SHAPE_ELLIPSE, SHAPE_DIAMOND]

var id: String
var revision: int
var tile_count: int
var columns: int
var rows: int
var layer_counts: Array[int]
var shape: String
var horizontal_symmetry: bool
var require_support: bool


func _init(
		requirements_id: String,
		requirements_tile_count: int,
		requirements_columns: int,
		requirements_rows: int,
		requirements_layer_counts: Array,
		requirements_shape: String = SHAPE_ELLIPSE,
		requirements_horizontal_symmetry: bool = true,
		requirements_require_support: bool = true,
		requirements_revision: int = 1
) -> void:
	id = requirements_id
	revision = requirements_revision
	tile_count = requirements_tile_count
	columns = requirements_columns
	rows = requirements_rows
	for count in requirements_layer_counts:
		layer_counts.append(int(count))
	shape = requirements_shape
	horizontal_symmetry = requirements_horizontal_symmetry
	require_support = requirements_require_support


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("requirements id must not be empty")
	if revision < 1:
		errors.append("requirements revision must be positive")
	if tile_count <= 0 or tile_count % 2 != 0:
		errors.append("tile count must be a positive even number")
	if columns <= 0 or rows <= 0:
		errors.append("columns and rows must be positive")
	if layer_counts.is_empty():
		errors.append("at least one layer count is required")
	if not SHAPES.has(shape):
		errors.append("shape must be one of: %s" % ", ".join(SHAPES))

	var total := 0
	for z in range(layer_counts.size()):
		var count: int = layer_counts[z]
		total += count
		var layer_columns := columns - z
		var layer_rows := rows - z
		if count <= 0:
			errors.append("layer %d count must be positive" % z)
		elif layer_columns <= 0 or layer_rows <= 0 or count > layer_columns * layer_rows:
			errors.append("layer %d count exceeds its inset grid capacity" % z)
		elif horizontal_symmetry and layer_columns % 2 == 0 and count % 2 != 0:
			errors.append("layer %d needs an even count for horizontal symmetry" % z)
	if total != tile_count:
		errors.append("layer counts must sum to tile count")
	return errors


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"requirements_id": id,
		"revision": revision,
		"tile_count": tile_count,
		"columns": columns,
		"rows": rows,
		"layer_counts": layer_counts.duplicate(),
		"shape": shape,
		"horizontal_symmetry": horizontal_symmetry,
		"require_support": require_support,
	}


func content_hash() -> String:
	return JSON.stringify(to_dict()).sha256_text()


static func from_dict(data: Dictionary) -> RefCounted:
	var script: Script = load("res://scripts/simulation/board_layout_requirements.gd")
	return script.new(
		str(data.get("requirements_id", "")),
		int(data.get("tile_count", 0)),
		int(data.get("columns", 0)),
		int(data.get("rows", 0)),
		data.get("layer_counts", []),
		str(data.get("shape", SHAPE_ELLIPSE)),
		bool(data.get("horizontal_symmetry", true)),
		bool(data.get("require_support", true)),
		int(data.get("revision", 1))
	)


static func load_file(path: String) -> RefCounted:
	if not FileAccess.file_exists(path):
		push_error("Board layout requirements file does not exist: %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("Invalid board layout requirements file: %s" % path)
		return null
	return from_dict(data)
