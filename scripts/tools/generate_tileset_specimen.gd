extends SceneTree

const BASE_PATH := "res://game-assets/tiles/default/tile_base.png"
const FACES_DIR := "res://game-assets/tiles/default/faces"
const OUTPUT_PATH := "C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/tileset_recreation_specimen.png"

func _init() -> void:
	printerr("Generating tileset visual specimen...")
	var base_img := Image.load_from_file(BASE_PATH)
	if base_img == null:
		printerr("Failed to load tile base")
		quit(1)
		return
	base_img.convert(Image.FORMAT_RGBA8)
	var tile_w: int = base_img.get_width() # 256
	var tile_h: int = base_img.get_height() # 368

	# Layout a specimen showcasing our tiles
	# Let's showcase 24 prominent tiles matching the inspiration image:
	var showcase_faces := [
		"mascot_cat", "east", "bamboo_1", "bamboo_6", "bamboo_2",
		"characters_1", "green_dragon", "mascot_star", "dots_4", "characters_9",
		"mascot_bunny", "west", "red_dragon", "mascot_panda", "dots_3",
		"mascot_oni", "dots_2", "mascot_fuji", "bamboo_3", "dots_1",
		"mascot_skull", "north", "mascot_flower", "mascot_dragon", "dots_8"
	]

	var cols := 5
	var rows := 5
	var spacing_x := 20
	var spacing_y := 24
	var margin_x := 60
	var margin_y := 60
	var canvas_w: int = margin_x * 2 + cols * tile_w + (cols - 1) * spacing_x
	var canvas_h: int = margin_y * 2 + rows * tile_h + (rows - 1) * spacing_y

	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	
	# Fill with deep rich emerald felt gradient
	for y in range(canvas_h):
		var v_factor: float = float(y) / float(canvas_h)
		for x in range(canvas_w):
			var u_factor: float = float(x) / float(canvas_w)
			# Radial vignette
			var dx: float = u_factor - 0.5
			var dy: float = v_factor - 0.5
			var dist: float = sqrt(dx * dx + dy * dy) * 1.414
			var r: float = lerp(0.06, 0.02, clamp(dist, 0.0, 1.0))
			var g: float = lerp(0.24, 0.10, clamp(dist, 0.0, 1.0))
			var b: float = lerp(0.16, 0.06, clamp(dist, 0.0, 1.0))
			canvas.set_pixel(x, y, Color(r, g, b, 1.0))

	# Composite each tile
	for idx in range(showcase_faces.size()):
		var face_name: String = showcase_faces[idx]
		var face_path := "%s/%s.png" % [FACES_DIR, face_name]
		var face_img := Image.load_from_file(face_path)
		if face_img == null:
			print("Could not load face: ", face_path)
			continue
		face_img.convert(Image.FORMAT_RGBA8)

		var c: int = idx % cols
		var r: int = idx / cols
		var pos_x: int = margin_x + c * (tile_w + spacing_x)
		var pos_y: int = margin_y + r * (tile_h + spacing_y)

		# Composite tile base
		canvas.blend_rect(base_img, Rect2i(0, 0, tile_w, tile_h), Vector2i(pos_x, pos_y))

		# Safe area offset for face
		# In skin.json: runtime_size is 256x368, face_safe_area is [72, 78, 368, 506] in 512x736,
		# which is [36, 39, 184, 253] in 256x368
		var face_w: int = face_img.get_width()
		var face_h: int = face_img.get_height()
		var face_offset_x: int = pos_x + 36
		var face_offset_y: int = pos_y + 39

		canvas.blend_rect(face_img, Rect2i(0, 0, face_w, face_h), Vector2i(face_offset_x, face_offset_y))

	canvas.save_png(ProjectSettings.globalize_path("res://docs/images/tileset-specimen.png"))
	var err := canvas.save_png(OUTPUT_PATH)
	if err == OK:
		printerr("Successfully saved specimen to: ", OUTPUT_PATH)
	else:
		printerr("Failed to save specimen, error code: %d" % err)

	# Generate Side-by-Side Comparison
	var insp_path := "C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/.user_uploaded/media_1788823937150.jpg"
	var insp_img := Image.load_from_file(insp_path)
	if insp_img != null:
		insp_img.convert(Image.FORMAT_RGBA8)
		# Resize both to equal height for side-by-side comparison
		var comp_h := 1200
		var insp_w := int(float(insp_img.get_width()) * float(comp_h) / float(insp_img.get_height()))
		insp_img.resize(insp_w, comp_h, Image.INTERPOLATE_LANCZOS)

		var spec_w := int(float(canvas.get_width()) * float(comp_h) / float(canvas.get_height()))
		var spec_resized := Image.create(canvas.get_width(), canvas.get_height(), false, Image.FORMAT_RGBA8)
		spec_resized.copy_from(canvas)
		spec_resized.resize(spec_w, comp_h, Image.INTERPOLATE_LANCZOS)

		var gap := 40
		var header_h := 80
		var side_w: int = insp_w + spec_w + gap + 40
		var side_h: int = comp_h + header_h + 40
		var side_img := Image.create(side_w, side_h, false, Image.FORMAT_RGBA8)
		side_img.fill(Color(0.04, 0.08, 0.06, 1.0))

		side_img.blend_rect(insp_img, Rect2i(0, 0, insp_w, comp_h), Vector2i(20, header_h + 20))
		side_img.blend_rect(spec_resized, Rect2i(0, 0, spec_w, comp_h), Vector2i(20 + insp_w + gap, header_h + 20))

		var side_by_side_path := "C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/tileset_side_by_side_comparison.png"
		var comp_err := side_img.save_png(side_by_side_path)
		if comp_err == OK:
			printerr("Successfully saved side-by-side comparison to: ", side_by_side_path)
	quit(0)
