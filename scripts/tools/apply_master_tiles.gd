@tool
extends SceneTree

func _init() -> void:
	var front_src := Image.load_from_file("res://art-source/tiles/default/bases/tile_base_portrait.png")
	var back_raw := Image.load_from_file("C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/.user_uploaded/media_1788836485162.jpg")
	back_raw.convert(Image.FORMAT_RGBA8)
	back_raw.resize(front_src.get_width(), front_src.get_height(), Image.INTERPOLATE_LANCZOS)
	
	# Apply alpha matte from front to back
	var back_src := Image.create(front_src.get_width(), front_src.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(front_src.get_height()):
		for x in range(front_src.get_width()):
			var alpha: float = front_src.get_pixel(x, y).a
			var c: Color = back_raw.get_pixel(x, y)
			c.a = alpha
			back_src.set_pixel(x, y, c)

	# Save 1024x1536 master back
	back_src.save_png("res://art-source/tiles/default/backs/tile_back_portrait.png")

	# Crop y: 32..1504 (height 1472, aspect ratio 1.4375)
	var crop_rect := Rect2i(0, 32, 1024, 1472)
	var front_cropped := front_src.get_region(crop_rect)
	var back_cropped := back_src.get_region(crop_rect)

	# 512x736 source masters
	var front_512 := Image.create(512, 736, false, Image.FORMAT_RGBA8)
	front_512.copy_from(front_cropped)
	front_512.resize(512, 736, Image.INTERPOLATE_LANCZOS)
	front_512.save_png("res://art-source/tiles/default/tile_base.png")

	var back_512 := Image.create(512, 736, false, Image.FORMAT_RGBA8)
	back_512.copy_from(back_cropped)
	back_512.resize(512, 736, Image.INTERPOLATE_LANCZOS)
	back_512.save_png("res://art-source/tiles/default/tile_back.png")

	# 256x368 runtime assets
	var front_256 := Image.create(256, 368, false, Image.FORMAT_RGBA8)
	front_256.copy_from(front_cropped)
	front_256.resize(256, 368, Image.INTERPOLATE_LANCZOS)
	front_256.save_png("res://game-assets/tiles/default/tile_base.png")

	var back_256 := Image.create(256, 368, false, Image.FORMAT_RGBA8)
	back_256.copy_from(back_cropped)
	back_256.resize(256, 368, Image.INTERPOLATE_LANCZOS)
	back_256.save_png("res://game-assets/tiles/default/tile_back.png")

	print("Successfully exported master and runtime tile base and back!")
	quit()
