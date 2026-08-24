extends RefCounted
class_name TileSkin

const DEFAULT_MANIFEST_PATH := "res://game-assets/tiles/default/skin.json"

var id := ""
var display_name := ""
var geometry: Dictionary = {}
var base_variants: Dictionary = {}
var back_variants: Dictionary = {}
var default_back_id := ""
var back_designs: Dictionary = {}
var depth_presentation: Dictionary = {}
var layout_presentation: Dictionary = {}
var canonical_face_ids: Array[String] = []
var faces: Dictionary = {}
var reference_preview_mapping: Dictionary = {}
var orientation := "portrait"
var back_design_id := ""

var _textures: Dictionary = {}
var _base_textures: Dictionary = {}
var _back_textures: Dictionary = {}
var _back_design_textures: Dictionary = {}
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
	for variant_id in ["portrait", "landscape"]:
		var variant: Dictionary = base_variants.get(variant_id, {})
		if variant.is_empty():
			errors.append("Missing tile base variant: %s" % variant_id)
			continue
		var asset_path := str(variant.get("asset", ""))
		if asset_path.is_empty() or not (ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)):
			errors.append("Tile base variant '%s' has no runtime asset." % variant_id)
		var source_size: Array = variant.get("source_size", [])
		var safe_area: Array = variant.get("face_safe_area", [])
		var back_safe_area: Array = variant.get("back_design_safe_area", [])
		if source_size.size() != 2 or safe_area.size() != 4 or back_safe_area.size() != 4:
			errors.append("Tile base variant '%s' has invalid geometry." % variant_id)
		var back_path := str(back_variants.get(variant_id, ""))
		if back_path.is_empty() or not (ResourceLoader.exists(back_path) or FileAccess.file_exists(back_path)):
			errors.append("Missing tile back variant: %s" % variant_id)
	if default_back_id.is_empty() or not back_designs.has(default_back_id):
		errors.append("Default tile-back design must reference a known design.")
	for design_id in back_designs:
		var design: Dictionary = back_designs[design_id]
		var design_path := str(design.get("asset", ""))
		if design_path.is_empty() or not (ResourceLoader.exists(design_path) or FileAccess.file_exists(design_path)):
			errors.append("Tile-back design '%s' has no runtime asset." % design_id)
	var depth_floor := float(depth_presentation.get("lowest_layer_brightness", 0.0))
	var blocked_overlay: Array = depth_presentation.get("blocked_overlay_color", [])
	var shadow_opacity := float(depth_presentation.get("shadow_opacity", -1.0))
	var shadow_offset: Array = depth_presentation.get("shadow_offset_ratio", [])
	if depth_floor <= 0.0 or depth_floor > 1.0:
		errors.append("Tile depth brightness must be in (0, 1].")
	if blocked_overlay.size() != 4:
		errors.append("Blocked tile overlay color must contain RGBA values.")
	else:
		for channel in blocked_overlay:
			if float(channel) < 0.0 or float(channel) > 1.0:
				errors.append("Blocked tile overlay channels must be in [0, 1].")
				break
	if shadow_opacity < 0.0 or shadow_opacity > 1.0:
		errors.append("Tile shadow opacity must be in [0, 1].")
	if shadow_offset.size() != 2:
		errors.append("Tile shadow offset ratio must contain x and y values.")
	var adjacent_gap_ratio := float(layout_presentation.get("adjacent_gap_ratio", -1.0))
	if adjacent_gap_ratio < -0.1 or adjacent_gap_ratio > 0.25:
		errors.append("Adjacent tile gap ratio must be in [-0.1, 0.25].")
	_validate_color_array(layout_presentation.get("ink_outline_color", []), "Ink outline color", errors)
	_validate_ratio_pair(layout_presentation.get("ink_outline_expansion_ratio", []), "Ink outline expansion", errors)
	_validate_ratio_pair(layout_presentation.get("ink_outline_offset_ratio", []), "Ink outline offset", errors, true)
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
	var texture := _load_texture(asset_path)
	_textures[face_id] = texture
	return texture


func set_orientation(value: String) -> bool:
	var normalized := value.to_lower()
	if not base_variants.has(normalized) or orientation == normalized:
		return false
	orientation = normalized
	return true


func active_geometry() -> Dictionary:
	return base_variants.get(orientation, geometry)


func tile_aspect() -> float:
	var active := active_geometry()
	var source_size: Array = active.get("source_size", geometry.get("source_size", [512, 640]))
	if source_size.size() != 2 or float(source_size[0]) <= 0.0:
		return 1.25
	return float(source_size[1]) / float(source_size[0])


func tile_base_texture() -> Texture2D:
	if _base_textures.has(orientation):
		return _base_textures[orientation]
	var active := active_geometry()
	var asset_path := str(active.get("asset", ""))
	var texture := _load_texture(asset_path)
	_base_textures[orientation] = texture
	return texture


func tile_back_texture() -> Texture2D:
	if _back_textures.has(orientation):
		return _back_textures[orientation]
	var texture := _load_texture(str(back_variants.get(orientation, "")))
	_back_textures[orientation] = texture
	return texture


func set_back_design(value: String) -> bool:
	if not back_designs.has(value) or back_design_id == value:
		return false
	back_design_id = value
	return true


func back_design_texture() -> Texture2D:
	if _back_design_textures.has(back_design_id):
		return _back_design_textures[back_design_id]
	var design: Dictionary = back_designs.get(back_design_id, {})
	var texture := _load_texture(str(design.get("asset", "")))
	_back_design_textures[back_design_id] = texture
	return texture


func configure_back_design(design_art: TextureRect) -> void:
	var active := active_geometry()
	var source_size: Array = active.get("source_size", [512, 640])
	var safe_area: Array = active.get("back_design_safe_area", [92, 104, 328, 400])
	design_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design_art.texture = back_design_texture()
	design_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	design_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	design_art.anchor_left = float(safe_area[0]) / float(source_size[0])
	design_art.anchor_top = float(safe_area[1]) / float(source_size[1])
	design_art.anchor_right = float(safe_area[0] + safe_area[2]) / float(source_size[0])
	design_art.anchor_bottom = float(safe_area[1] + safe_area[3]) / float(source_size[1])
	design_art.offset_left = 0.0
	design_art.offset_top = 0.0
	design_art.offset_right = 0.0
	design_art.offset_bottom = 0.0


func _load_texture(asset_path: String) -> Texture2D:
	if asset_path.is_empty():
		return null
	if ResourceLoader.exists(asset_path):
		return load(asset_path) as Texture2D
	elif FileAccess.file_exists(asset_path):
		var img := Image.load_from_file(asset_path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


func configure_ink_outline(outline: TextureRect) -> void:
	var expansion: Array = layout_presentation.get("ink_outline_expansion_ratio", [0.055, 0.04])
	var offset: Array = layout_presentation.get("ink_outline_offset_ratio", [-0.004, 0.006])
	var color: Array = layout_presentation.get("ink_outline_color", [0.07, 0.035, 0.02, 0.92])
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.texture = tile_base_texture()
	outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	outline.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	outline.anchor_left = -float(expansion[0]) * 0.5 + float(offset[0])
	outline.anchor_top = -float(expansion[1]) * 0.5 + float(offset[1])
	outline.anchor_right = 1.0 + float(expansion[0]) * 0.5 + float(offset[0])
	outline.anchor_bottom = 1.0 + float(expansion[1]) * 0.5 + float(offset[1])
	outline.offset_left = 0.0
	outline.offset_top = 0.0
	outline.offset_right = 0.0
	outline.offset_bottom = 0.0
	outline.modulate = Color(float(color[0]), float(color[1]), float(color[2]), float(color[3]))
	outline.visible = outline.texture != null


func has_face_id(face_id: String) -> bool:
	return faces.has(face_id)


func _validate_color_array(value: Variant, label: String, errors: Array[String]) -> void:
	if not value is Array or value.size() != 4:
		errors.append("%s must contain RGBA values." % label)
		return
	for channel in value:
		if float(channel) < 0.0 or float(channel) > 1.0:
			errors.append("%s channels must be in [0, 1]." % label)
			return


func _validate_ratio_pair(
	value: Variant,
	label: String,
	errors: Array[String],
	allow_negative: bool = false
) -> void:
	if not value is Array or value.size() != 2:
		errors.append("%s must contain x and y ratios." % label)
		return
	for ratio in value:
		var numeric := float(ratio)
		if numeric > 0.25 or (numeric < -0.25 if allow_negative else numeric < 0.0):
			errors.append("%s ratios are outside the supported range." % label)
			return


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
	base_variants = parsed.get("base_variants", {}).duplicate(true)
	back_variants = parsed.get("back_variants", {}).duplicate(true)
	default_back_id = str(parsed.get("default_back_id", ""))
	back_designs = parsed.get("back_designs", {}).duplicate(true)
	back_design_id = default_back_id
	depth_presentation = parsed.get("depth_presentation", {}).duplicate(true)
	layout_presentation = parsed.get("layout_presentation", {}).duplicate(true)
	canonical_face_ids.assign(parsed.get("canonical_face_ids", []))
	faces = parsed.get("faces", {}).duplicate(true)
	reference_preview_mapping = parsed.get("reference_preview_mapping", {}).duplicate(true)
