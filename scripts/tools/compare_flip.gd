@tool
extends SceneTree

func _init() -> void:
	var base_img := Image.load_from_file("res://game-assets/tiles/default/tile_base.png")
	var back_img := Image.load_from_file("res://game-assets/tiles/default/tile_back.png")
	var face_img := Image.load_from_file("res://game-assets/tiles/default/faces/dots_2.png")
	var spark_img := Image.load_from_file("res://game-assets/tiles/default/back-designs/arcade_spark.png")

	# Composite front
	var front := Image.create(base_img.get_width(), base_img.get_height(), false, Image.FORMAT_RGBA8)
	front.blit_rect(base_img, Rect2i(Vector2i.ZERO, base_img.get_size()), Vector2i.ZERO)
	front.blend_rect(face_img, Rect2i(Vector2i.ZERO, face_img.get_size()), Vector2i(36, 39))

	# Composite back
	var back := Image.create(back_img.get_width(), back_img.get_height(), false, Image.FORMAT_RGBA8)
	back.blit_rect(back_img, Rect2i(Vector2i.ZERO, back_img.get_size()), Vector2i.ZERO)
	
	# Scale down spark to fit back design area (150x172 in runtime)
	if spark_img != null:
		spark_img.convert(Image.FORMAT_RGBA8)
		spark_img.resize(130, 130, Image.INTERPOLATE_LANCZOS)
		var spark_x: int = (back.get_width() - spark_img.get_width()) / 2
		var spark_y: int = (back.get_height() - spark_img.get_height()) / 2 - 10
		back.blend_rect(spark_img, Rect2i(Vector2i.ZERO, spark_img.get_size()), Vector2i(spark_x, spark_y))

	# Output side by side
	var out_w: int = front.get_width() * 2 + 60
	var out_h: int = front.get_height() + 80
	var out := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	out.fill(Color("#081c14"))

	out.blend_rect(front, Rect2i(Vector2i.ZERO, front.get_size()), Vector2i(20, 40))
	out.blend_rect(back, Rect2i(Vector2i.ZERO, back.get_size()), Vector2i(front.get_width() + 40, 40))

	var out_path := "C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/tile_front_back_comparison.png"
	out.save_png(out_path)
	print("Saved front-back comparison to: ", out_path)
	quit(0)
