extends SceneTree

const DEFAULT_SKIN_PATH := "res://game-assets/tiles/default/skin.json"
const PADDING := 4
const ATLAS_SIZE := 2048


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var skin_paths := [
		"res://game-assets/tiles/default/skin.json"
	]
	
	# Parse custom arguments if provided
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--skin="):
			var custom_skin := arg.trim_prefix("--skin=")
			skin_paths = [custom_skin]
	
	for skin_path in skin_paths:
		var success := _build_atlas_for_skin(skin_path)
		if not success:
			printerr("Failed to build atlas for skin: %s" % skin_path)
			quit(1)
			return

	print("Atlas generation complete.")
	quit(0)


func _build_atlas_for_skin(skin_path: String) -> bool:
	print("Building face atlas for: %s" % skin_path)
	if not FileAccess.file_exists(skin_path):
		printerr("Skin manifest does not exist: %s" % skin_path)
		return false
	
	var json_str := FileAccess.get_file_as_string(skin_path)
	var parsed: Variant = JSON.parse_string(json_str)
	if not parsed is Dictionary:
		printerr("Invalid JSON in skin manifest: %s" % skin_path)
		return false
	
	var faces_dict: Dictionary = parsed.get("faces", {})
	if faces_dict.is_empty():
		printerr("No faces defined in skin manifest: %s" % skin_path)
		return false
	
	var base_dir := skin_path.get_base_dir()
	var sorted_face_ids: Array[String] = []
	for k in faces_dict.keys():
		sorted_face_ids.append(str(k))
	sorted_face_ids.sort()
	
	# Load all face images
	var images: Dictionary = {}
	for face_id in sorted_face_ids:
		var face_data: Dictionary = faces_dict[face_id]
		var asset_path := str(face_data.get("asset", ""))
		var global_path := ProjectSettings.globalize_path(asset_path)
		if not FileAccess.file_exists(global_path) and not FileAccess.file_exists(asset_path):
			printerr("Face asset missing: %s (face: %s)" % [asset_path, face_id])
			return false
		
		var img := Image.load_from_file(global_path if FileAccess.file_exists(global_path) else asset_path)
		if img == null or img.is_empty():
			printerr("Could not load image: %s" % asset_path)
			return false
		images[face_id] = img
	
	# Pack images using shelf packing
	var atlas_w := ATLAS_SIZE
	var atlas_h := ATLAS_SIZE
	var atlas_img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0)) # Transparent background
	
	var frames: Dictionary = {}
	var current_x := PADDING
	var current_y := PADDING
	var row_height := 0
	
	for face_id in sorted_face_ids:
		var img: Image = images[face_id]
		var w := img.get_width()
		var h := img.get_height()
		
		# Check if fits in current row
		if current_x + w + PADDING > atlas_w:
			current_x = PADDING
			current_y += row_height + PADDING
			row_height = 0
		
		if current_y + h + PADDING > atlas_h:
			printerr("Atlas overflow! %d faces do not fit in %dx%d atlas." % [sorted_face_ids.size(), atlas_w, atlas_h])
			return false
		
		# Blit image to atlas
		atlas_img.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(current_x, current_y))
		
		frames[face_id] = {
			"x": current_x,
			"y": current_y,
			"w": w,
			"h": h
		}
		
		current_x += w + PADDING
		row_height = maxi(row_height, h)
	
	# Output paths
	var atlas_png_res := base_dir + "/faces_atlas.png"
	var atlas_json_res := base_dir + "/faces_atlas.json"
	var atlas_png_global := ProjectSettings.globalize_path(atlas_png_res)
	var atlas_json_global := ProjectSettings.globalize_path(atlas_json_res)
	
	# Save PNG
	var save_err := atlas_img.save_png(atlas_png_global)
	if save_err != OK:
		printerr("Failed to save atlas PNG to %s, err=%d" % [atlas_png_global, save_err])
		return false
	
	# Save JSON metadata
	var atlas_data := {
		"schema_version": 1,
		"texture": "faces_atlas.png",
		"width": atlas_w,
		"height": atlas_h,
		"face_count": sorted_face_ids.size(),
		"frames": frames
	}
	
	var json_file := FileAccess.open(atlas_json_global, FileAccess.WRITE)
	if json_file == null:
		printerr("Failed to save atlas JSON to %s" % atlas_json_global)
		return false
	json_file.store_string(JSON.stringify(atlas_data, "  "))
	json_file.close()
	
	print("Successfully packed %d faces into %s (%dx%d)" % [
		sorted_face_ids.size(),
		atlas_png_res,
		atlas_w,
		atlas_h
	])
	print("Atlas metadata written to %s" % atlas_json_res)
	return true
