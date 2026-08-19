extends RefCounted
class_name TileSkin

const DEFAULT_MANIFEST_PATH := "res://game-assets/tiles/default/skin.json"

var id := ""
var display_name := ""
var geometry: Dictionary = {}
var canonical_face_ids: Array[String] = []
var faces: Dictionary = {}
var reference_preview_mapping: Dictionary = {}

var _textures: Dictionary = {}
var _load_errors: Array[String] = []


func _init(manifest_path: String = DEFAULT_MANIFEST_PATH) -> void:
	_load_manifest(manifest_path)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	errors.assign(_load_errors)
	if id.is_empty():
		errors.append("Tile skin id is required.")
	if canonical_face_ids.size() != 34:
		errors.append("The initial canonical mahjong vocabulary must contain 34 face ids.")
	var unique_ids := {}
	for face_id in canonical_face_ids:
		if unique_ids.has(face_id):
			errors.append("Duplicate canonical face id: %s" % face_id)
		unique_ids[face_id] = true
		if not faces.has(face_id):
			errors.append("Missing face definition: %s" % face_id)
	for logical_id in reference_preview_mapping:
		if not faces.has(str(reference_preview_mapping[logical_id])):
			errors.append("Reference mapping '%s' targets an unknown face." % logical_id)
	return errors


func presentation_id(face: Variant) -> String:
	var logical_id: String = face.logical_id()
	return str(reference_preview_mapping.get(logical_id, logical_id))


func label_for_face(face: Variant) -> String:
	var face_id := presentation_id(face)
	var definition: Dictionary = faces.get(face_id, {})
	return str(definition.get("label", face_id.replace("_", " ").to_upper()))


func texture_for_face(face: Variant) -> Texture2D:
	return texture_for_id(presentation_id(face))


func texture_for_id(face_id: String) -> Texture2D:
	if _textures.has(face_id):
		return _textures[face_id]
	var definition: Dictionary = faces.get(face_id, {})
	var asset_path := str(definition.get("asset", ""))
	var texture: Texture2D = null
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		texture = load(asset_path) as Texture2D
	_textures[face_id] = texture
	return texture


func has_face_id(face_id: String) -> bool:
	return faces.has(face_id)


func _load_manifest(manifest_path: String) -> void:
	if not FileAccess.file_exists(manifest_path):
		_load_errors.append("Tile skin manifest does not exist: %s" % manifest_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		_load_errors.append("Tile skin manifest must contain a JSON object.")
		return
	if int(parsed.get("schema_version", 0)) != 1:
		_load_errors.append("Unsupported tile skin schema version.")
	id = str(parsed.get("id", ""))
	display_name = str(parsed.get("display_name", id))
	geometry = parsed.get("geometry", {}).duplicate(true)
	canonical_face_ids.assign(parsed.get("canonical_face_ids", []))
	faces = parsed.get("faces", {}).duplicate(true)
	reference_preview_mapping = parsed.get("reference_preview_mapping", {}).duplicate(true)
