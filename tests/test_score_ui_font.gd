extends SceneTree

const MomentumViewScript := preload("res://scripts/presentation/momentum_view.gd")
const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const ReferenceGameFactoryScript := preload("res://scripts/simulation/reference_game_factory.gd")

func _init() -> void:
	print("--- Testing In-Game Score UI Font ---")
	var game = ReferenceGameFactoryScript.create_standard_game(42)
	var momentum_view := MomentumViewScript.new(game)
	root.add_child(momentum_view)
	
	# Set portrait style and dimensions
	momentum_view.set("_portrait_style", true)
	momentum_view.size = Vector2(390.0, 844.0)
	momentum_view.call("_build_portrait_chrome")
	momentum_view.call("_layout")
	
	var score_label: Label = momentum_view.get("_score")
	assert(score_label != null, "_score Label must exist in MomentumView")
	
	var font: Font = score_label.get_theme_font("font")
	assert(font != null, "Score label must have a theme font override")
	print("OK: Score label font loaded: %s" % font.resource_path)
	assert(font.resource_path.ends_with("battle-mahjong-poster-script.tres") or font.resource_path.ends_with("battle-mahjong-poster-script.ttf"), "Score label must use Battle Mahjong Poster Script font")
	
	# Verify score formatting and refresh with 72,590
	game.score = 72590
	momentum_view.refresh(0)
	print("OK: Score label text after refresh(0): '%s'" % score_label.text)
	assert(score_label.text == "72,590", "Score label should display '72,590', got '%s'" % score_label.text)
	
	# Verify score update with million tier
	game.score = 1048576
	momentum_view.refresh(0)
	print("OK: Million tier score text: '%s'" % score_label.text)
	assert(score_label.text == "1,048,576", "Score label should display '1,048,576'")
	
	# Verify score update with 0
	game.score = 0
	momentum_view.refresh(0)
	print("OK: Zero score text: '%s'" % score_label.text)
	# Verify style overrides (face color and shadow layering)
	assert(score_label.get_theme_color("font_color") == Color("fff6e5"), "Score label font_color must be #fff6e5")
	assert(score_label.get_theme_color("font_shadow_color") == Color("d9485c"), "Score label font_shadow_color must be #d9485c")
	assert(score_label.get_theme_constant("shadow_offset_x") >= 1, "shadow_offset_x must be positive")
	assert(score_label.get_theme_constant("shadow_offset_y") >= 1, "shadow_offset_y must be positive")
	print("OK: Score label shadow layering verified (coral-pink shadow #d9485c at offset %d, %d)" % [
		score_label.get_theme_constant("shadow_offset_x"),
		score_label.get_theme_constant("shadow_offset_y")
	])

	# Verify other HUD labels use the custom font and shadow styling
	for label_prop in ["_score_title", "_timer", "_multiplier", "_combo"]:
		var lbl: Label = momentum_view.get(label_prop)
		assert(lbl != null, "%s must exist" % label_prop)
		var lbl_font: Font = lbl.get_theme_font("font")
		assert(lbl_font.resource_path.ends_with("battle-mahjong-poster-script.tres") or lbl_font.resource_path.ends_with("battle-mahjong-poster-script.ttf"), "%s must use poster script font" % label_prop)
		assert(lbl.get_theme_color("font_shadow_color") == Color("d9485c"), "%s must have #d9485c shadow" % label_prop)
	print("OK: All HUD labels (_score_title, _timer, _multiplier, _combo) use poster script with shadow layering")

	print("--- ALL SCORE UI FONT CHECKS PASSED ---")
	quit(0)
