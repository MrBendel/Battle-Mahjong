@tool
extends SceneTree

func _init() -> void:
	var img := Image.new()
	img.load("C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/.user_uploaded/media_1788823937150.jpg")
	
	# The full image is 835 x 912
	# Let's crop full tile of Zhong (center):
	# Around (375, 310, 95, 150)
	var zhong := img.get_region(Rect2i(365, 300, 110, 160))
	zhong.save_png("C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/crop_zhong_full.png")

	# Let's crop Mt Fuji (below Zhong):
	var fuji := img.get_region(Rect2i(315, 530, 110, 160))
	fuji.save_png("C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/crop_fuji_full.png")

	# Let's crop bottom center 9-Wan:
	var wan9 := img.get_region(Rect2i(370, 715, 110, 160))
	wan9.save_png("C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/crop_wan9_full.png")

	# Let's crop bottom 2-Dots:
	var dots2 := img.get_region(Rect2i(275, 715, 110, 160))
	dots2.save_png("C:/Users/andre/.gemini/antigravity-ide/brain/35005bd2-3004-434f-8564-00eb2b6c70fb/crop_dots2_full.png")

	print("Full tile crops saved!")
	quit()
