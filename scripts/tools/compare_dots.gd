@tool
extends SceneTree

func _init() -> void:
	var ref_path := "C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/crop_dots2_full.png"
	var ref_img := Image.load_from_file(ref_path)
	if ref_img == null:
		printerr("Failed to load reference image")
		quit(1)
		return

	# Load base and face
	var base_img := Image.load_from_file("res://game-assets/tiles/default/tile_base.png")
	var face_img := Image.load_from_file("res://game-assets/tiles/default/faces/dots_2.png")

	var composite := Image.create(base_img.get_width(), base_img.get_height(), false, Image.FORMAT_RGBA8)
	composite.blit_rect(base_img, Rect2i(Vector2i.ZERO, base_img.get_size()), Vector2i.ZERO)

	# Safe area from skin.json at runtime scale (256x368): offset (36, 39)
	composite.blend_rect(face_img, Rect2i(Vector2i.ZERO, face_img.get_size()), Vector2i(36, 39))

	# Target comparison size: height 550
	var h: int = 550
	ref_img.convert(Image.FORMAT_RGBA8)
	var ref_scale: float = float(h) / float(ref_img.get_height())
	var ref_w: int = int(ref_img.get_width() * ref_scale)
	ref_img.resize(ref_w, h, Image.INTERPOLATE_LANCZOS)

	var comp_scale: float = float(h) / float(composite.get_height())
	var comp_w: int = int(composite.get_width() * comp_scale)
	composite.resize(comp_w, h, Image.INTERPOLATE_LANCZOS)

	var out_w: int = ref_w + comp_w + 40
	var out := Image.create(out_w, h + 60, false, Image.FORMAT_RGBA8)
	out.fill(Color("#0d2419"))

	out.blit_rect(ref_img, Rect2i(Vector2i.ZERO, ref_img.get_size()), Vector2i(15, 30))
	out.blit_rect(composite, Rect2i(Vector2i.ZERO, composite.get_size()), Vector2i(ref_w + 25, 30))

	var out_path := "res://docs/images/dots-comparison.png"
	out.save_png(ProjectSettings.globalize_path(out_path))
	out.save_png("C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/dots_side_by_side_comparison.png")
	print("Saved dots side-by-side to: ", out_path)
	quit(0)
