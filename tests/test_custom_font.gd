extends SceneTree

func _init():
	print("--- Testing Battle Mahjong Poster Script Font ---")
	var font_ttf = load("res://assets/fonts/battle-mahjong-poster-script.ttf")
	assert(font_ttf != null, "TTF font failed to load")
	print("OK: TTF loaded successfully")

	var font_tres = load("res://assets/fonts/battle-mahjong-poster-script.tres")
	assert(font_tres != null, "TRES font resource failed to load")
	print("OK: TRES loaded successfully")

	# Test string measurement
	var sample_text = "BATTLE MAHJONG 2026! READY? 100% ♥"
	var size = font_ttf.get_string_size(sample_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	print("OK: Sample string measured successfully: '%s' -> width=%.1f, height=%.1f" % [sample_text, size.x, size.y])
	assert(size.x > 0 and size.y > 0, "String size measurement failed")

	# Test lowercase fallback
	var lower_sample = "battle mahjong"
	var lower_size = font_ttf.get_string_size(lower_sample, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	print("OK: Lowercase string measured successfully: '%s' -> width=%.1f, height=%.1f" % [lower_sample, lower_size.x, lower_size.y])
	assert(lower_size.x > 0, "Lowercase fallback measurement failed")

	print("--- ALL CUSTOM FONT TESTS PASSED ---")
	quit(0)
