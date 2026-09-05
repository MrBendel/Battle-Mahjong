extends RefCounted

const SCHEMA_VERSION := 1
const SHAPE_RECTANGLE := "rectangle"
const SHAPE_ELLIPSE := "ellipse"
const SHAPE_DIAMOND := "diamond"
const SHAPES := [SHAPE_RECTANGLE, SHAPE_ELLIPSE, SHAPE_DIAMOND]
const MOTIF_SOLID := "solid"
const MOTIF_WINGS := "wings"
const MOTIF_BRIDGE := "bridge"
const MOTIF_TOWER := "tower"
const MOTIF_HOURGLASS := "hourglass"
const MOTIFS := [MOTIF_SOLID, MOTIF_WINGS, MOTIF_BRIDGE, MOTIF_TOWER, MOTIF_HOURGLASS]

var id: String
var revision: int
var tile_count: int
var columns: int
var rows: int
var layer_counts: Array[int]
var shape: String
var horizontal_symmetry: bool
var require_support: bool
var progressive_layer_inset: bool
var layer_motif_choices: Array
var mobile_constraints: Dictionary


func _init(
		requirements_id: String,
		requirements_tile_count: int,
		requirements_columns: int,
		requirements_rows: int,
		requirements_layer_counts: Array,
		requirements_shape: String = SHAPE_ELLIPSE,
		requirements_horizontal_symmetry: bool = true,
		requirements_require_support: bool = true,
		requirements_revision: int = 1,
		requirements_layer_motif_choices: Array = [],
		requirements_mobile_constraints: Dictionary = {},
		requirements_progressive_layer_inset: bool = true
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
	progressive_layer_inset = requirements_progressive_layer_inset
	for choices in requirements_layer_motif_choices:
		layer_motif_choices.append(choices.duplicate() if choices is Array else [])
	mobile_constraints = requirements_mobile_constraints.duplicate(true)


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
	if not layer_motif_choices.is_empty() and layer_motif_choices.size() != layer_counts.size():
		errors.append("layer motif choices must contain one entry per layer")
	for z in range(layer_motif_choices.size()):
		if layer_motif_choices[z].is_empty():
			errors.append("layer %d must have at least one motif choice" % z)
		for motif in layer_motif_choices[z]:
			if not MOTIFS.has(str(motif)):
				errors.append("layer %d has unknown motif: %s" % [z, motif])
	for key in [
		"maximum_width_to_height_bps",
		"minimum_initial_selectable_tiles",
		"maximum_initial_selectable_tiles",
		"maximum_layer_count",
		"reference_board_width_px",
		"reference_board_height_px",
		"tile_height_to_width_bps",
		"minimum_tile_width_px",
		"minimum_row_width_variation",
		"minimum_widest_row_tiles",
	]:
		if mobile_constraints.has(key) and int(mobile_constraints[key]) < 0:
			errors.append("mobile constraint %s must not be negative" % key)
	if mobile_constraints.has("minimum_initial_selectable_tiles") \
			and mobile_constraints.has("maximum_initial_selectable_tiles") \
			and int(mobile_constraints.minimum_initial_selectable_tiles) \
				> int(mobile_constraints.maximum_initial_selectable_tiles):
		errors.append("minimum initial selectable tiles must not exceed maximum")

	var total := 0
	for z in range(layer_counts.size()):
		var count: int = layer_counts[z]
		total += count
		var inset := z if progressive_layer_inset else z % 2
		var layer_columns := columns - inset
		var layer_rows := rows - inset
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
	var data := {
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
		"progressive_layer_inset": progressive_layer_inset,
	}
	if not layer_motif_choices.is_empty():
		data["layer_motif_choices"] = layer_motif_choices.duplicate(true)
	if not mobile_constraints.is_empty():
		data["mobile_constraints"] = mobile_constraints.duplicate(true)
	return data


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
		int(data.get("revision", 1)),
		data.get("layer_motif_choices", []),
		data.get("mobile_constraints", {}),
		bool(data.get("progressive_layer_inset", true))
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
