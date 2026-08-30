extends SceneTree

const PairDifficultyRewardsScript := preload("res://scripts/simulation/pair_difficulty_rewards.gd")
const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")
const BoardLayoutCatalogScript := preload("res://scripts/simulation/board_layout_catalog.gd")
const LayoutSolutionPlannerScript := preload("res://scripts/simulation/layout_solution_planner.gd")
const MatchSmokeTuft := preload("res://game-assets/fx/match_smoke_tuft.png")
const PresentationScaleScript := preload("res://scripts/presentation/presentation_scale.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_size := Vector2i(720, 1280)
	if OS.get_cmdline_user_args().has("--large-portrait"):
		requested_size = Vector2i(1080, 2400)
	elif OS.get_cmdline_user_args().has("--small-phone"):
		requested_size = Vector2i(375, 667)
	elif OS.get_cmdline_user_args().has("--landscape"):
		requested_size = Vector2i(1280, 720)
	elif OS.get_cmdline_user_args().has("--portrait"):
		requested_size = Vector2i(430, 932)
	root.size = requested_size
	var shell: Control = load("res://scenes/main.tscn").instantiate()
	var modifier_playtest := OS.get_cmdline_user_args().has("--modifier-playtest") \
		or OS.get_cmdline_user_args().has("--modifier-callout-capture")
	shell.set("playtest_all_modifiers", modifier_playtest)
	root.add_child(shell)
	await process_frame
	var banner_view: Control = shell.get("_update_banner")
	if banner_view != null:
		banner_view.visible = false
		await process_frame

	_check_equal(
		DisplayServer.SCREEN_SENSOR,
		ProjectSettings.get_setting("display/window/handheld/orientation"),
		"Android export declares sensor orientation"
	)
	_check_equal(
		"gl_compatibility",
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"),
		"Android export uses the lifecycle-stable compatibility renderer"
	)
	var projected_insets := SafeAreaScript.insets(
		Vector2(1200.0, 600.0),
		Rect2i(100, 40, 960, 520),
		Vector2i(1200, 600)
	)
	_check_equal(Rect2(100.0, 40.0, 140.0, 40.0), projected_insets, "safe-area projection preserves asymmetric edge insets")
	_check(is_equal_approx(PresentationScaleScript.limiting_scale(Vector2(390.0, 844.0)), 1.0), "presentation scale preserves its authored reference size")
	_check(is_equal_approx(
		PresentationScaleScript.safe_display_scale(
			Vector2(820.0, 1728.0),
			Rect2(20.0, 20.0, 20.0, 20.0)
		),
		2.0
	), "presentation scale applies safe-area insets before calculating a 2x display scale")
	if OS.get_cmdline_user_args().has("--safe-area"):
		var test_insets := Rect2(72.0, 24.0, 44.0, 28.0) if requested_size.x > requested_size.y \
			else Rect2(28.0, 54.0, 46.0, 30.0)
		shell.call("set_safe_area_override_for_testing", test_insets)
		await process_frame
	var gameplay_background: NinePatchRect = shell.get("_gameplay_background")
	_check(gameplay_background != null and gameplay_background.texture != null, "gameplay shell renders the M7 background asset")
	_check_equal(load("res://game-assets/ui/portrait/background.png"), gameplay_background.texture, "gameplay shell reuses the Figma background in every orientation")
	_check_equal(Vector2(941.0, 1672.0), gameplay_background.texture.get_size(), "gameplay background retains the Figma master dimensions required by its scale-9 contract")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_check_equal(48, gameplay_background.get_patch_margin(side), "gameplay background preserves its 48 px scale-9 border")
	_check_equal(NinePatchRect.AXIS_STRETCH_MODE_STRETCH, gameplay_background.axis_stretch_horizontal, "gameplay background stretches its scale-9 interior horizontally")
	_check_equal(NinePatchRect.AXIS_STRETCH_MODE_STRETCH, gameplay_background.axis_stretch_vertical, "gameplay background stretches its scale-9 interior vertically")
	var tuning: Resource = shell.get("momentum_tuning")
	var modifier_tuning: Resource = shell.get("modifier_tuning")
	var callout_tuning: Resource = shell.get("arcade_callout_tuning")
	_check(tuning != null, "main scene exposes a MomentumTuning resource")
	_check(tuning.call("validation_errors").is_empty(), "main scene MomentumTuning resource validates")
	_check(modifier_tuning != null, "main scene exposes a ModifierTuning resource")
	_check(modifier_tuning.call("validation_errors").is_empty(), "main scene ModifierTuning resource validates")
	_check(callout_tuning != null and callout_tuning.call("validation_errors").is_empty(), "main scene ArcadeCalloutTuning resource validates")
	var live_game: Variant = shell.get("_game")
	_check_equal(shell.get("layout_id"), live_game.definition.configuration.layout_id, "main scene selects its exported layout id")
	_check_equal(
		int(shell.get("flipped_tile_count")),
		live_game.definition.flipped_tile_ids.size(),
		"main scene copies Inspector flipped-tile count into game definition"
	)
	_check_equal(
		int(tuning.get("pair_gain")),
		int(live_game.definition.configuration.momentum_pair_gain),
		"main scene copies Inspector tuning into game definition"
	)
	_check_equal(
		int(tuning.get("selection_gain")),
		int(live_game.definition.configuration.momentum_selection_gain),
		"main scene copies selection gain into game definition"
	)
	_check_equal(
		5 if modifier_playtest else int(modifier_tuning.get("loadout_capacity")),
		int(live_game.definition.configuration.modifier_loadout_capacity),
		"main scene uses the expected production or playtest modifier capacity"
	)
	_check_equal(5 if modifier_playtest else 1, live_game.definition.modifier_attachments.size(), "main scene equips the requested modifier loadout")
	var attached_tile_id: String = str(live_game.definition.modifier_attachments.keys()[0])
	var attached_button: Button = shell.get("_regions").board.get("_tile_buttons")[attached_tile_id]
	var modifier_art: TextureRect = attached_button.get_node("ModifierArt")
	_check(modifier_art.visible and modifier_art.texture != null, "starter modifier uses separate visible tile artwork")
	_check_equal(
		load("res://game-assets/modifiers/tile-overlays/extra_life.png") if modifier_playtest \
			else load("res://game-assets/modifiers/tile-overlays/score_multiplier.png"),
		modifier_art.texture,
		"first equipped modifier resolves through the tile skin"
	)
	if modifier_playtest:
		var expected_modifier_textures := {
			"extra_life": load("res://game-assets/modifiers/tile-overlays/extra_life.png"),
			"cold_snap": load("res://game-assets/modifiers/tile-overlays/cold_snap.png"),
			"score_multiplier": load("res://game-assets/modifiers/tile-overlays/score_multiplier.png"),
			"tray_plus_one": load("res://game-assets/modifiers/tile-overlays/tray_plus_one.png"),
			"three_pair_clear": load("res://game-assets/modifiers/tile-overlays/three_pair_clear.png"),
		}
		for modifier_tile_id in live_game.definition.modifier_attachments:
			var attachment: Dictionary = live_game.definition.modifier_attachments[modifier_tile_id]
			var modifier_button: Button = shell.get("_regions").board.get("_tile_buttons")[modifier_tile_id]
			var attached_art: TextureRect = modifier_button.get_node("ModifierArt")
			_check_equal(
				expected_modifier_textures[attachment.type],
				attached_art.texture,
				"playtest %s attachment renders on its board tile" % attachment.type
			)
		await _verify_modifier_activation_feedback(shell)
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
		attached_tile_id = str(live_game.definition.modifier_attachments.keys()[0])
		attached_button = shell.get("_regions").board.get("_tile_buttons")[attached_tile_id]
		modifier_art = attached_button.get_node("ModifierArt")
	var modifier_preview: Control = shell.get("_regions").board.call("create_tile_preview", attached_tile_id, true)
	var preview_modifier: TextureRect = modifier_preview.get_node("ModifierArt")
	_check_equal(modifier_art.texture, preview_modifier.texture, "moving tile preview preserves attached modifier artwork")
	modifier_preview.queue_free()
	var tile_skin: Variant = shell.get("_tile_skin")
	for modifier_id in ["extra_life", "cold_snap", "score_multiplier", "tray_plus_one", "three_pair_clear"]:
		_check(
			tile_skin.call("modifier_texture", modifier_id) != null,
			"%s has runtime tile-attached artwork" % modifier_id
		)
	var revealable_tile_id := ""
	for tile in live_game.board.call("revealable_tiles"):
		revealable_tile_id = tile.id
		break
	_check(not revealable_tile_id.is_empty(), "reference game starts with an accessible face-down tile")
	if not revealable_tile_id.is_empty():
		var reveal_button: Button = shell.get("_regions").board.get("_tile_buttons")[revealable_tile_id]
		var reveal_art: TextureRect = reveal_button.get_node("FaceArt")
		var reveal_base: TextureRect = reveal_button.get_node("BaseArt")
		var reveal_back: TextureRect = reveal_button.get_node("BackArt")
		var reveal_back_design: TextureRect = reveal_button.get_node("BackDesignArt")
		_check(bool(reveal_button.get_meta("face_down")), "face-down presentation records hidden state")
		_check(not reveal_art.visible and reveal_button.text.is_empty(), "face-down presentation hides tile identity without a question mark")
		_check(reveal_back.visible and reveal_back.texture != null and not reveal_base.visible, "face-down presentation uses the dedicated tile back")
		_check(reveal_back_design.visible and reveal_back_design.texture != null, "face-down presentation composites an independent cosmetic back design")
		var hover_style: StyleBoxFlat = reveal_button.get_theme_stylebox("hover")
		var pressed_style: StyleBoxFlat = reveal_button.get_theme_stylebox("pressed")
		_check_equal(Color.TRANSPARENT, hover_style.bg_color, "tile hover adds no rectangular background")
		_check_equal(Color.TRANSPARENT, pressed_style.bg_color, "tile press adds no rectangular background")
		var resting_brightness: float = reveal_button.modulate.r
		shell.get("_regions").board.call("_set_tile_interaction_brightness", revealable_tile_id, true)
		_check(reveal_button.modulate.r > resting_brightness, "tile interaction highlights by brightness")
		shell.get("_regions").board.call("_set_tile_interaction_brightness", revealable_tile_id, false)
		_check_equal(resting_brightness, reveal_button.modulate.r, "tile interaction brightness restores cleanly")
		var forced_face_preview: Panel = shell.get("_regions").board.call("create_tile_preview", revealable_tile_id, true)
		var forced_face_style: StyleBoxFlat = forced_face_preview.get_theme_stylebox("panel")
		_check_equal(Color.TRANSPARENT, forced_face_style.bg_color, "forced face-up preview lets ceramic artwork own its silhouette")
		_check_equal(0, forced_face_style.get_border_width(SIDE_LEFT), "forced face-up preview has no legacy blue outline")
		_check_equal(Color.WHITE, forced_face_preview.modulate, "forced face-up preview remains fully lit")
		forced_face_preview.free()
		var tray_before_reveal: int = live_game.tray.tiles.size()
		var motion_before_reveal: int = shell.get("_tile_motion_count")
		shell.call("_on_tile_selected", revealable_tile_id)
		_check(live_game.board.call("is_tile_revealed_flipped", revealable_tile_id), "shell commits face-down reveal transaction")
		_check_equal(tray_before_reveal, live_game.tray.tiles.size(), "shell reveal leaves tray occupancy unchanged")
		_check_equal(motion_before_reveal, shell.get("_tile_motion_count"), "shell reveal does not start tray transfer")
		_check(reveal_back.visible, "flip animation starts on the tile back")
		await create_timer(0.15).timeout
		_check(
			reveal_art.visible and absf(reveal_button.scale.x - 1.0) > 0.05,
			"flip swaps to the face before its horizontal expansion completes"
		)
		await create_timer(0.12).timeout
		_check(reveal_art.visible and reveal_button.text.is_empty(), "revealed tile displays its face in place")
		_check_equal(Color.WHITE, reveal_button.modulate, "revealed flipped tile uses canonical available-tile brightness")
		_check(bool(reveal_button.get_meta("targetable")), "revealed flipped tile becomes playable into the tray")
		_check(is_equal_approx(reveal_button.scale.x, 1.0), "flip expands the revealed face back to full width")
		var nonmatching_tile_id := ""
		var revealed_face: Variant = live_game.definition.get_tile(revealable_tile_id).face
		for candidate in live_game.board.call("selectable_tiles"):
			if not candidate.face.equals(revealed_face):
				nonmatching_tile_id = candidate.id
				break
		_check(not nonmatching_tile_id.is_empty(), "reference game exposes an ordinary non-match for flip-back validation")
		if not nonmatching_tile_id.is_empty():
			shell.call("_on_tile_selected", nonmatching_tile_id)
			_check(live_game.board.call("is_tile_face_down", revealable_tile_id), "ordinary non-match re-hides the revealed tile")
			await create_timer(0.15).timeout
			_check(reveal_back.visible and reveal_back_design.visible and not reveal_art.visible and reveal_button.text.is_empty(), "flip-back presentation restores both tile-back layers")
			await create_timer(0.12).timeout
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
		shell.call("_on_tile_selected", revealable_tile_id)
		await create_timer(0.27).timeout
		var revealed_motion_before: int = shell.get("_tile_motion_count")
		shell.call("_on_tile_selected", revealable_tile_id)
		_check(revealable_tile_id in live_game.call("current_snapshot").tray_tile_ids, "second flipped-tile tap occupies an authoritative tray slot")
		_check_equal(revealed_motion_before + 1, shell.get("_tile_motion_count"), "second flipped-tile tap starts the normal tray transfer")
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
	var board_view: Control = shell.get("_regions").board
	shell.call("_on_hint_requested")
	var animated_hint_id := ""
	for hinted_tile_id in live_game.call("hinted_tile_ids"):
		if live_game.board.call("is_tile_active", hinted_tile_id):
			animated_hint_id = hinted_tile_id
			break
	_check(not animated_hint_id.is_empty(), "Hint identifies an active board tile for presentation")
	if not animated_hint_id.is_empty():
		var hinted_button: Button = board_view.get("_tile_buttons")[animated_hint_id]
		var hinted_base_position: Vector2 = board_view.get("_tile_layout_positions")[animated_hint_id]
		var hinted_base_brightness: float = float(hinted_button.get_meta("presentation_brightness", 1.0))
		var hinted_style: StyleBoxFlat = hinted_button.get_theme_stylebox("normal")
		board_view.call("_process", 0.3)
		_check_equal(0, hinted_style.get_border_width(SIDE_LEFT), "Hint adds no tile outline")
		_check(hinted_button.position.y < hinted_base_position.y, "Hint sinusoid lifts the suggested tile")
		_check(hinted_button.modulate.r > hinted_base_brightness, "Hint sinusoid brightens the suggested tile")
		_check(hinted_button.get_node("HintGlow").visible, "Hint displays the additive ceramic glow")
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
		var restored_button: Button = board_view.get("_tile_buttons")[animated_hint_id]
		_check(not restored_button.get_node("HintGlow").visible, "clearing Hint removes its glow")
		_check_equal(board_view.get("_tile_layout_positions")[animated_hint_id], restored_button.position, "clearing Hint restores the tile position")
	var stage_visuals := []
	for rect in [Rect2(Vector2(32.0, 120.0), Vector2(42.0, 54.0)), Rect2(Vector2(root.size.x - 74.0, root.size.y - 180.0), Vector2(42.0, 54.0))]:
		var preview := Panel.new()
		stage_visuals.append({"preview": preview, "rect": rect})
	var staging_before: int = shell.get("_flipped_pair_staging_count")
	var stage_collision_before: int = shell.get("_pair_collision_count")
	var stage_feedback_before: int = shell.get("_pair_feedback_count")
	var stage_targets: Array[Rect2] = shell.call("_flipped_pair_staging_rects")
	shell.call("_play_flipped_pair_via_open_slots", stage_visuals)
	_check_equal(staging_before + 1, shell.get("_flipped_pair_staging_count"), "flipped pair starts one two-slot staging presentation")
	_check_equal(stage_targets, shell.get("_last_flipped_pair_stage_targets"), "flipped pair records both open tray targets")
	await create_timer(0.24).timeout
	_check_equal(stage_collision_before, shell.get("_pair_collision_count"), "flipped pair holds in the tray before collision")
	await create_timer(0.26).timeout
	var expected_stage_collision := (stage_targets[0].get_center() + stage_targets[1].get_center()) * 0.5
	_check_equal(stage_collision_before + 1, shell.get("_pair_collision_count"), "flipped pair collides after tray staging")
	_check_equal(expected_stage_collision, shell.get("_last_pair_collision_position"), "flipped pair collides between its staging slots")
	_check_equal(stage_feedback_before + 1, shell.get("_pair_feedback_count"), "flipped tray collision triggers the shared removal burst")
	await create_timer(0.24).timeout
	var tray_match_rect: Rect2 = shell.get("_regions").tray.call("slot_global_rect", 0)
	var flipped_target_rect: Rect2 = shell.get("_regions").tray.call("slot_global_rect", 1)
	var tray_visuals := [
		{"preview": Panel.new(), "rect": Rect2(Vector2(root.size.x * 0.5, root.size.y * 0.7), Vector2(42.0, 54.0))},
		{"preview": Panel.new(), "rect": tray_match_rect},
	]
	var tray_motion_before: int = shell.get("_tile_motion_count")
	var tray_collision_before: int = shell.get("_pair_collision_count")
	shell.call("_play_flipped_match_to_tray", tray_visuals, flipped_target_rect, true)
	_check_equal(tray_motion_before, shell.get("_tile_motion_count"), "flipped tile reveals before starting tray motion")
	var tray_incoming: Control = tray_visuals[0].preview
	var tray_start: Vector2 = tray_incoming.position
	_check(tray_incoming.scale.x < 0.1, "matching flipped tile begins its face reveal edge-on")
	await create_timer(0.13).timeout
	_check_equal(tray_start, tray_incoming.position, "matching flipped tile reveals in place before tray motion")
	_check(tray_incoming.scale.x > 0.1, "matching flipped tile face becomes visible during the reveal beat")
	await create_timer(0.14).timeout
	_check(is_equal_approx(tray_incoming.scale.x, 1.0), "matching flipped tile reaches a fully readable face before moving")
	_check_equal(tray_motion_before, shell.get("_tile_motion_count"), "matching flipped tile holds face-up before tray motion")
	await create_timer(float(shell.get("flipped_auto_match_hold_seconds")) + 0.03).timeout
	_check_equal(tray_motion_before + 1, shell.get("_tile_motion_count"), "revealed flipped tile starts one normal tray transfer")
	_check_equal(flipped_target_rect, shell.get("_last_tile_motion_target"), "revealed flipped tile targets the open slot")
	_check_equal(tray_collision_before, shell.get("_pair_collision_count"), "flipped tile begins tray travel only after revealing")
	await create_timer(0.47).timeout
	_check_equal(tray_collision_before + 1, shell.get("_pair_collision_count"), "flipped tile collides with its held mate")
	var expected_tray_collision := (flipped_target_rect.get_center() + tray_match_rect.get_center()) * 0.5
	_check_equal(expected_tray_collision, shell.get("_last_pair_collision_position"), "flipped-to-tray collision matches ordinary tray behavior")
	await create_timer(0.24).timeout
	var representative_button: Button = null
	for tile in live_game.board.tiles:
		if tile.face.logical_id() == "reference_01":
			representative_button = shell.get("_regions").board.get("_tile_buttons")[tile.id]
			break
	_check(representative_button != null, "reference game contains the representative Bamboo face")
	if representative_button != null:
		var face_art: TextureRect = representative_button.get_node("FaceArt")
		_check(face_art.texture != null and face_art.visible, "representative Default face renders as a layered runtime asset")
	var selectable_tile_id := ""
	for tile in live_game.board.call("selectable_tiles"):
		selectable_tile_id = tile.id
		break
	_check(not selectable_tile_id.is_empty(), "reference game starts with an animatable selectable tile")
	if not selectable_tile_id.is_empty():
		var selection_board: Control = shell.get("_regions").board
		var selection_counters_before: Dictionary = selection_board.call("performance_counters")
		var original_board_rect: Rect2 = selection_board.call("tile_global_rect", selectable_tile_id)
		var expected_target: Rect2 = shell.get("_regions").tray.call("slot_global_rect", 0)
		var tile_motion_before: int = shell.get("_tile_motion_count")
		shell.call("_on_tile_selected", selectable_tile_id)
		var selection_counters_after: Dictionary = selection_board.call("performance_counters")
		_check_equal(
			selection_counters_before.layouts,
			selection_counters_after.layouts,
			"ordinary selection does not recalculate Board geometry"
		)
		_check_equal(
			selection_counters_before.input_sorts,
			selection_counters_after.input_sorts,
			"ordinary selection does not reorder Board input children"
		)
		_check_equal(
			selection_counters_before.style_applications,
			selection_counters_after.style_applications,
			"ordinary selection does not reinitialize tile styles"
		)
		_check_equal(tile_motion_before + 1, shell.get("_tile_motion_count"), "ordinary selection starts one board-to-tray animation")
		_check_equal(
			int(tuning.get("selection_gain")),
			live_game.call("current_snapshot").momentum_units,
			"ordinary selection immediately bumps live Momentum"
		)
		_check_equal(expected_target, shell.get("_last_tile_motion_target"), "selection animation targets the next tray slot")
		_check_equal(1, live_game.tray.tiles.size(), "ordinary transfer commits tray occupancy immediately")
		var first_slot_art: TextureRect = shell.get("_regions").tray.get("_slot_art")[0]
		_check(not first_slot_art.visible, "destination tile stays visually suppressed during transfer")
		var transfer_preview: Control = shell.get("_tile_transfer_previews").get(selectable_tile_id)
		await create_timer(0.20).timeout
		_check(
			not is_instance_valid(transfer_preview) or is_equal_approx(transfer_preview.modulate.a, 1.0),
			"board-to-tray transfer never fades through a transparent landing frame"
		)
		_check(
			is_instance_valid(transfer_preview) and transfer_preview.scale.x < 1.0,
			"board-to-tray transfer visibly scales toward the smaller tray footprint"
		)
		await create_timer(0.12).timeout
		_check(first_slot_art.visible and first_slot_art.texture != null, "arrival reveals the selected face artwork")
		var first_slot_base: TextureRect = shell.get("_regions").tray.get("_slot_bases")[0]
		_check(
			first_slot_base.visible and first_slot_base.texture == shell.get("_tile_skin").call("tile_base_texture"),
			"arrival uses the Board's active ceramic base in the tray"
		)
		var first_slot_ink: TextureRect = shell.get("_regions").tray.get("_slot_ink_outlines")[0]
		_check(first_slot_ink.visible and first_slot_ink.texture == first_slot_base.texture, "tray tile preserves the manga-ink silhouette")
		var landed_undo_before: int = shell.get("_undo_motion_count")
		shell.call("_on_undo_requested")
		_check_equal(landed_undo_before + 1, shell.get("_undo_motion_count"), "landed tray tile animates back on Undo")
		_check_equal(0, live_game.call("current_snapshot").momentum_units, "Undo removes the returned tile's Momentum bump")
		_check_equal(original_board_rect, shell.get("_last_undo_motion_target"), "landed Undo returns to the original board position")
		await create_timer(0.32).timeout
		_check(shell.get("_regions").board.get("_tile_buttons")[selectable_tile_id].visible, "landed Undo reveals the restored board tile on arrival")
		var paused_time: int = shell.call("_playback_time_ms")
		shell.call("_on_pause_requested")
		_check(shell.get("_pause_menu").visible, "pause button opens the first modal menu")
		_check(not shell.get("_pause_button").visible, "pause button yields focus to the open menu")
		var responsive_pause_menu: Control = shell.get("_pause_menu")
		var responsive_pause_safe_rect := SafeAreaScript.content_rect(
			responsive_pause_menu.size,
			shell.call("_get_safe_area_insets")
		)
		var responsive_pause_scale := maxf(
			0.78,
			minf(responsive_pause_safe_rect.size.x / 390.0, responsive_pause_safe_rect.size.y / 844.0)
		)
		_check(is_equal_approx(float(responsive_pause_menu.get("_display_scale")), responsive_pause_scale), "pause menu follows the safe-display UI scale")
		_check(is_equal_approx(responsive_pause_menu.get("_panel").size.x, 330.0 * responsive_pause_scale), "pause panel scales from its portrait reference width")
		_check_equal(roundi(27.0 * responsive_pause_scale), responsive_pause_menu.get("_title").get_theme_font_size("font_size"), "pause title scales with the modal")
		_check(responsive_pause_safe_rect.encloses(responsive_pause_menu.get("_panel").get_rect()), "pause panel stays inside the safe display")
		_check(is_equal_approx(44.0 * responsive_pause_scale, responsive_pause_menu.get("_sound_toggle").custom_minimum_size.y), "pause toggle rows scale with the modal")
		_check_equal(roundi(18.0 * responsive_pause_scale), responsive_pause_menu.get("_sound_toggle").get_theme_font_size("font_size"), "pause toggle text scales with the modal")
		_check_equal(Vector2(1.0, 1.0), responsive_pause_menu.get("_sound_toggle").get_theme_icon("checked").get_size(), "pause toggles do not use Godot's fixed-size indicator artwork")
		_check(responsive_pause_menu.get("_sound_toggle").button_pressed, "pause menu starts with sound enabled")
		_check(responsive_pause_menu.get("_haptics_toggle").button_pressed, "pause menu starts with haptics enabled")
		responsive_pause_menu.get("_sound_toggle").button_pressed = false
		_check(not shell.get("_sound_enabled"), "pause Sound toggle updates the session preference")
		_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "disabled session sound mutes game audio")
		responsive_pause_menu.get("_sound_toggle").button_pressed = true
		_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "re-enabled session sound restores game audio")
		var pause_haptic_count: int = shell.get("_haptic_event_count")
		responsive_pause_menu.get("_haptics_toggle").button_pressed = false
		shell.call("_play_haptic", "selection")
		_check_equal(pause_haptic_count, shell.get("_haptic_event_count"), "disabled Haptics toggle suppresses feedback")
		responsive_pause_menu.get("_haptics_toggle").button_pressed = true
		shell.call("_play_haptic", "selection")
		_check_equal(pause_haptic_count + 1, shell.get("_haptic_event_count"), "enabled Haptics toggle permits feedback")
		_check_equal("selection", shell.get("_last_haptic_kind"), "selection uses the light haptic profile")
		await create_timer(0.05).timeout
		_check_equal(paused_time, shell.call("_playback_time_ms"), "pause menu freezes active gameplay time")
		shell.get("_pause_menu").emit_signal("resumed")
		_check(not shell.get("_pause_menu").visible, "Resume closes the pause menu")
		_check(shell.get("_pause_button").visible, "Resume restores the pause button")
		await create_timer(0.02).timeout
		_check(shell.call("_playback_time_ms") > paused_time, "Resume restarts active gameplay time")
		var lifecycle_revision: int = live_game.revision
		var stale_touch := InputEventScreenTouch.new()
		stale_touch.index = 7
		stale_touch.position = Vector2(120.0, 240.0)
		stale_touch.pressed = true
		shell.call("_input", stale_touch)
		shell.call("_on_delete_pair_requested")
		_check(shell.get("_delete_pair_armed"), "Delete Pair mode can be armed before lifecycle interruption")
		var stale_delete_button: Button = shell.get("_regions").consumables.get("_buttons").delete_pair
		var recovery_before: int = shell.get("_input_recovery_count")
		for cycle in range(3):
			shell.call("_on_application_backgrounded")
			_check(shell.get("_pause_menu").visible, "background cycle %d opens the pause menu" % cycle)
			_check_equal(lifecycle_revision, live_game.revision, "background cycle %d preserves game state" % cycle)
			_check(shell.get("_lifecycle_input_suspended"), "background cycle %d blocks gameplay pointer input" % cycle)
			_check(not shell.get("_delete_pair_armed"), "background cycle %d clears Delete Pair targeting" % cycle)
			_check(stale_delete_button.get_parent() == null, "background cycle %d detaches stale action controls immediately" % cycle)
			shell.call("_on_delete_pair_requested")
			_check(not shell.get("_delete_pair_armed"), "background cycle %d rejects buffered Delete Pair activation" % cycle)
			shell.call("_on_application_foregrounded")
			await process_frame
			await process_frame
			await process_frame
			_check(not shell.get("_lifecycle_input_suspended"), "foreground cycle %d re-enables pointer input after recovery" % cycle)
			if cycle < 2:
				shell.get("_pause_menu").emit_signal("resumed")
				stale_delete_button = shell.get("_regions").consumables.get("_buttons").delete_pair
		_check_equal(recovery_before + 3, shell.get("_input_recovery_count"), "each foreground cycle recovers pointer input")
		_check(shell.get("_active_screen_touches").is_empty(), "foreground recovery cancels stale screen touches")
		shell.get("_pause_menu").emit_signal("resumed")
		var post_resume_tile_id := ""
		for tile in live_game.board.call("selectable_tiles"):
			post_resume_tile_id = tile.id
			break
		_check(not post_resume_tile_id.is_empty(), "a selectable tile remains after lifecycle recovery")
		if not post_resume_tile_id.is_empty():
			shell.get("_regions").board.call("_on_tile_pressed", post_resume_tile_id)
			_check_equal(lifecycle_revision + 1, live_game.revision, "tile input works immediately after repeated foreground recovery")
			shell.call("_on_undo_requested")
		shell.call("_on_pause_requested")
		shell.get("_pause_menu").emit_signal("restart_requested")
		_check_equal(
			shell.get("_regions").board.get("_tile_buttons").size(),
			shell.get("_regions").board.get("_tile_layer").get_child_count(),
			"board rebuild immediately detaches stale tile controls"
		)
		await process_frame
		live_game = shell.get("_game")
		_check_equal(0, live_game.revision, "pause-menu Restart creates a fresh game")
		_check(not shell.get("_pause_menu").visible, "Restart closes the pause menu")
		_check(shell.get("_pause_button").visible, "Restart restores the pause button")
		var undo_tile_id := ""
		for tile in live_game.board.call("selectable_tiles"):
			undo_tile_id = tile.id
			break
		var undo_target: Rect2 = shell.get("_regions").board.call("tile_global_rect", undo_tile_id)
		shell.call("_on_tile_selected", undo_tile_id)
		var undo_motion_before: int = shell.get("_undo_motion_count")
		shell.call("_on_undo_requested")
		_check_equal(0, live_game.tray.tiles.size(), "rapid Undo restores authoritative tray immediately")
		_check(live_game.board.call("is_tile_active", undo_tile_id), "rapid Undo restores authoritative board state immediately")
		_check_equal(undo_motion_before + 1, shell.get("_undo_motion_count"), "Undo reverses the in-flight tile visual")
		_check_equal(undo_target, shell.get("_last_undo_motion_target"), "Undo animation targets the restored board position")
		_check(not shell.get("_regions").board.get("_tile_buttons")[undo_tile_id].visible, "restored board tile stays hidden during return motion")
		await create_timer(0.32).timeout
		_check(shell.get("_regions").board.get("_tile_buttons")[undo_tile_id].visible, "restored board tile appears when Undo animation lands")
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
	var compaction_pair := _find_rewardable_pair(live_game)
	_check_equal(2, compaction_pair.size(), "reference game exposes a pair for queue-compaction validation")
	if compaction_pair.size() == 2:
		shell.call("_on_tile_selected", compaction_pair[0])
		await create_timer(0.30).timeout
		var second_tray_tile_id := _find_selectable_distinct_from_tray(live_game, compaction_pair[1])
		_check(not second_tray_tile_id.is_empty(), "queue-compaction setup finds a distinct second tray tile")
		if not second_tray_tile_id.is_empty():
			shell.call("_on_tile_selected", second_tray_tile_id)
			await create_timer(0.30).timeout
		var third_tray_tile_id := _find_selectable_distinct_from_tray(live_game, compaction_pair[1])
		_check(not third_tray_tile_id.is_empty(), "queue-compaction setup finds a distinct third tray tile")
		if not third_tray_tile_id.is_empty():
			shell.call("_on_tile_selected", third_tray_tile_id)
			await create_timer(0.30).timeout
		if live_game.tray.tiles.size() == 3:
			var survivor_ids: Array[String] = [live_game.tray.tiles[1].id, live_game.tray.tiles[2].id]
			var compaction_before: int = shell.get("_tray_compaction_count")
			shell.call("_on_tile_selected", compaction_pair[1])
			_check_equal(2, live_game.tray.tiles.size(), "interior match compacts authoritative tray immediately")
			_check_equal(survivor_ids[0], live_game.tray.tiles[0].id, "first survivor owns the first authoritative tray slot")
			_check_equal(survivor_ids[1], live_game.tray.tiles[1].id, "second survivor owns the second authoritative tray slot")
			_check_equal(compaction_before + 2, shell.get("_tray_compaction_count"), "interior match starts one compaction motion per survivor")
			var compaction_targets: Array[Rect2] = shell.get("_last_tray_compaction_targets")
			_check_equal(shell.get("_regions").tray.call("slot_global_rect", 0), compaction_targets[0], "first survivor compacts into slot one")
			_check_equal(shell.get("_regions").tray.call("slot_global_rect", 1), compaction_targets[1], "second survivor compacts into slot two")
			var first_preview: Control = shell.get("_tray_compaction_previews").get(survivor_ids[0])
			var second_preview: Control = shell.get("_tray_compaction_previews").get(survivor_ids[1])
			_check(first_preview != null and second_preview != null, "survivors retain visual previews at their old slots")
			var first_start_x := first_preview.position.x
			var second_start_x := second_preview.position.x
			var suppressed: Dictionary = shell.get("_regions").tray.get("_suppressed_tile_ids")
			_check(suppressed.has(survivor_ids[0]) and suppressed.has(survivor_ids[1]), "destination tiles stay hidden behind compaction previews")
			await create_timer(0.52).timeout
			_check(first_preview.position.x < first_start_x and second_preview.position.x < second_start_x, "survivor previews visibly travel left after the pair collision")
			await create_timer(0.18).timeout
			_check(not shell.get("_tray_compaction_previews").has(survivor_ids[0]), "first survivor hands rendering back to its tray slot")
			_check(not shell.get("_tray_compaction_previews").has(survivor_ids[1]), "second survivor hands rendering back to its tray slot")
			_check(not shell.get("_regions").tray.get("_suppressed_tile_ids").has(survivor_ids[0]), "first compacted tray tile is revealed")
			_check(not shell.get("_regions").tray.get("_suppressed_tile_ids").has(survivor_ids[1]), "second compacted tray tile is revealed")
		else:
			_fail("queue-compaction setup fills three distinct tray slots")
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
	var selectable_pair := _find_rewardable_pair(live_game)
	_check_equal(2, selectable_pair.size(), "reference game exposes a rewardable pair for feedback validation")
	if selectable_pair.size() == 2:
		shell.call("_on_tile_selected", selectable_pair[0])
		await create_timer(0.25).timeout
		var pair_feedback_before: int = shell.get("_pair_feedback_count")
		var pair_collision_before: int = shell.get("_pair_collision_count")
		var callout_before: int = shell.get("_performance_callout").get("play_count")
		var open_visual_slot: Rect2 = shell.get("_regions").tray.call("slot_global_rect", 1)
		shell.call("_on_tile_selected", selectable_pair[1])
		_check_equal("pair", shell.get("_last_haptic_kind"), "resolved pair uses the stronger haptic profile")
		_check(float(shell.get("pair_haptic_amplitude")) > float(shell.get("selection_haptic_amplitude")), "pair haptic is stronger than tile selection")
		_check_equal(0, live_game.tray.tiles.size(), "resolved pair leaves no temporary animation occupancy in tray data")
		_check_equal(open_visual_slot, shell.get("_last_tile_motion_target"), "matching tile first targets the next open visual slot")
		await create_timer(0.20).timeout
		_check_equal(pair_collision_before, shell.get("_pair_collision_count"), "pair pauses briefly after landing before collision")
		await create_timer(0.30).timeout
		_check_equal(pair_collision_before + 1, shell.get("_pair_collision_count"), "pair performs one collision before removal pop")
		_check_equal(pair_feedback_before + 1, shell.get("_pair_feedback_count"), "resolved pair emits one reusable match burst")
		var live_smoke_emitters := shell.find_children("SmokeParticles", "CPUParticles2D", true, false)
		_check(not live_smoke_emitters.is_empty(), "pair collision composes a shared spark-and-smoke effect")
		_check_equal(Vector2(64.0, 64.0), MatchSmokeTuft.get_size(), "match particles use the compact smoke-tuft texture")
		_check_equal(2, shell.get("_pair_match_fx_pool").size(), "match smoke reuses a two-emitter pool")
		var active_match_fx: Control = shell.get("_last_match_fx")
		_check(active_match_fx != null, "pair collision records its reused smoke emitter")
		if active_match_fx != null:
			var smoke_particles: CPUParticles2D = active_match_fx.get_node("SmokeParticles")
			var expected_fx_scale := PresentationScaleScript.safe_display_scale(
				shell.get_viewport_rect().size,
				shell.call("_get_safe_area_insets")
			) * float(shell.get("match_fx_scale_multiplier"))
			_check(is_equal_approx(float(shell.get("_last_match_fx_scale")), expected_fx_scale), "match FX records the limiting safe-display scale")
			_check(active_match_fx.scale.is_equal_approx(Vector2.ONE * expected_fx_scale), "match smoke scales responsively with the safe display")
			_check(int(active_match_fx.get("play_count")) >= 2, "match smoke reuses its startup-warmed emitter")
			_check(not smoke_particles.get_parent().is_processing(), "match smoke uses no per-frame GDScript processing")
			_check_equal(1, smoke_particles.get_parent().get_child_count(), "each match burst owns one smoke emitter")
			_check_equal(6, smoke_particles.amount, "match smoke stays within its six-particle mobile budget")
			_check(smoke_particles.one_shot, "match smoke uses one-shot particle emission")
			_check_equal(MatchSmokeTuft, smoke_particles.texture, "match smoke particles share one tuft texture")
			_check(is_equal_approx(float(smoke_particles.scale_amount_min), 0.50), "match smoke tufts remain readable at gameplay scale")
		_check_equal(1, live_game.tray.resolved_pair_count, "match feedback follows a committed pair transaction")
		_check_equal(1, live_game.call("combo_at", shell.call("_playback_time_ms")), "natural pair starts the live Combo readout")
		var reward: Dictionary = live_game.call("last_transaction").telemetry.get("difficulty_reward", {})
		_check(not reward.is_empty(), "qualified pair records its difficulty reward")
		_check_equal(callout_before + 1, shell.get("_performance_callout").get("play_count"), "difficulty reward starts one live-text callout")
		_check_equal("difficulty", shell.get("_performance_callout").get("last_alert_type"), "hard pair owns the single callout lane")
		_check(shell.get("_performance_callout").get("last_text") in ["WELL HIDDEN!", "EAGLE EYES!", "AMAZING FIND!"], "hard pair uses find-specific arcade copy")
		var callout: Control = shell.get("_performance_callout")
		var callout_children_before: int = callout.get_child_count()
		callout.call("play_alert", {"type": "combo", "key": "combo", "text": "11 COMBO!"})
		callout.call("play_alert", {"type": "score", "key": "score_milestone", "text": "SCORE 10K!"})
		_check_equal(callout_children_before, callout.get_child_count(), "rapid alerts reuse the single callout lane without stacking labels")
		_check_equal("score", callout.get("last_alert_type"), "latest alert exclusively owns the callout lane")
		_check_equal("SCORE 10K!", callout.get("last_text"), "single callout lane supports dynamic score text")
		callout.call("play_alert", {"type": "match", "key": "flipped_auto_match", "text": "MATCH!"})
		_check_equal("match", callout.get("last_alert_type"), "flipped auto-match alert is accepted by the callout renderer")
		_check_equal("MATCH!", callout.get("last_text"), "flipped auto-match alert displays its explanation")
		callout.call("play_alert", {"type": "modifier_reward", "key": "extra_life", "text": "EXTRA LIFE +1"})
		_check_equal("modifier_reward", callout.get("last_alert_type"), "single callout lane accepts modifier reward presentation")
	var visible_blocked_tile_id := ""
	for tile in live_game.board.tiles:
		if live_game.board.call("is_tile_visible", tile.id) \
				and not live_game.board.call("is_tile_selectable", tile.id) \
				and not live_game.board.call("is_tile_revealable", tile.id):
			visible_blocked_tile_id = tile.id
			break
	_check(not visible_blocked_tile_id.is_empty(), "reference layout contains a visible tile blocked from normal movement")
	if not visible_blocked_tile_id.is_empty():
		var board: Control = shell.get("_regions").board
		var negative_count: int = board.call("negative_feedback_count")
		var revision_before: int = live_game.revision
		var target_button: Button = board.get("_tile_buttons")[visible_blocked_tile_id]
		var target_overlay: TextureRect = target_button.get_node("BlockedOverlay")
		_check(target_overlay.visible and target_overlay.modulate.a > 0.0, "normally unselectable tile has the cool blocked-state veil")
		board.call("_on_tile_pressed", visible_blocked_tile_id)
		_check_equal(revision_before + 1, live_game.revision, "blocked-tile feedback records a live Combo break")
		_check_equal(0, live_game.call("combo_at", shell.call("_playback_time_ms")), "blocked tile tap kills Combo")
		_check_equal("locked_tile_tap", live_game.call("last_transaction").telemetry.combo_break_reason, "blocked tile break is replay telemetry")
		_check_equal(negative_count + 1, board.call("negative_feedback_count"), "blocked tile tap starts negative feedback")
		await create_timer(0.25).timeout
		shell.call("_on_delete_pair_requested")
		_check(not target_button.disabled, "Delete Pair mode enables visible tiles blocked from normal movement")
		_check_equal(Color.WHITE, target_button.modulate, "Delete Pair target uses canonical available-tile brightness")
		_check(not target_overlay.visible, "Delete Pair target removes the blocked-state veil")
		var delete_target_style: StyleBoxFlat = target_button.get_theme_stylebox("normal")
		_check_equal(Color.TRANSPARENT, delete_target_style.bg_color, "Delete Pair mode adds no target background")
		_check_equal(0, delete_target_style.get_border_width(SIDE_LEFT), "Delete Pair mode adds no selection outline")

	shell.call("_on_restart_requested")
	live_game = shell.get("_game")
	var deletable_pair: Array[String] = []
	if modifier_playtest:
		var delete_modifier_tile_id: String = str(live_game.definition.modifier_attachments.keys()[0])
		deletable_pair = _find_selectable_pair_for_tile(live_game, delete_modifier_tile_id)
	else:
		deletable_pair = _find_visible_pair(live_game)
	_check_equal(2, deletable_pair.size(), "reference game exposes a visible pair for Delete Pair feedback")
	if deletable_pair.size() == 2:
		var delete_feedback_before: int = shell.get("_pair_feedback_count")
		shell.call("_on_delete_pair_requested")
		shell.call("_on_tile_selected", deletable_pair[0])
		await create_timer(0.25).timeout
		_check_equal(delete_feedback_before + 1, shell.get("_pair_feedback_count"), "Delete Pair composes the shared removal burst")
		_check_equal(1, live_game.tray.resolved_pair_count, "Delete Pair feedback follows a committed transaction")
		if modifier_playtest:
			_check_equal("modifier_reward", shell.get("_performance_callout").get("last_alert_type"), "Delete Pair announces an attached modifier reward")

	var shuffle_face_up_id := ""
	var shuffle_face_down_id := ""
	for shuffle_tile in live_game.board.call("active_tiles"):
		if live_game.board.call("is_tile_face_down", shuffle_tile.id):
			if shuffle_face_down_id.is_empty():
				shuffle_face_down_id = shuffle_tile.id
		elif shuffle_face_up_id.is_empty():
			shuffle_face_up_id = shuffle_tile.id
	var shuffle_board: Control = shell.get("_regions").board
	var shuffle_face_up_button: Button = shuffle_board.get("_tile_buttons").get(shuffle_face_up_id)
	var shuffle_face_down_button: Button = shuffle_board.get("_tile_buttons").get(shuffle_face_down_id)
	var shuffle_animation_before: int = shell.get("_shuffle_animation_count")
	var shuffle_reposition_before: int = shuffle_board.get("_shuffle_reposition_count")
	var shuffle_counters_before: Dictionary = shuffle_board.call("performance_counters")
	var shuffle_revision: int = live_game.revision
	shell.call("_on_shuffle_requested")
	await process_frame
	_check_equal(shuffle_revision + 1, live_game.revision, "Shuffle commits before input-order validation")
	_check(shell.get("_shuffle_animation_active"), "successful Shuffle blocks gameplay during its presentation")
	_check_equal(shuffle_animation_before + 1, shell.get("_shuffle_animation_count"), "successful Shuffle starts one presentation sequence")
	_check(shuffle_face_up_button != null and not bool(shuffle_face_up_button.get_meta("flip_animating", false)), "Shuffle keeps face-up tiles visible while moving")
	if shuffle_face_down_button != null:
		_check(shuffle_face_down_button.get_node("BackArt").visible, "Shuffle keeps face-down tiles face-down while moving")
		_check_equal(Vector2.ONE, shuffle_face_down_button.scale, "already face-down Shuffle tiles keep their visual scale")
	await create_timer(float(shell.get("shuffle_move_seconds")) + 0.08).timeout
	_check(not shell.get("_shuffle_animation_active"), "Shuffle restores gameplay input after the reposition settles")
	_check(shuffle_face_up_button == null or shuffle_face_up_button.get_node("FaceArt").visible, "Shuffle reveals face artwork in the new Board position")
	_check_equal(shuffle_reposition_before + 1, shuffle_board.get("_shuffle_reposition_count"), "Shuffle batches one visible reposition phase")
	var shuffle_counters_after: Dictionary = shuffle_board.call("performance_counters")
	_check_equal(
		int(shuffle_counters_before.layouts) + 1,
		int(shuffle_counters_after.layouts),
		"Shuffle performs one Board geometry remap"
	)
	_check_equal(
		int(shuffle_counters_before.input_sorts) + 1,
		int(shuffle_counters_after.input_sorts),
		"Shuffle performs one Board input reorder"
	)
	_check_equal(
		shuffle_counters_before.style_applications,
		shuffle_counters_after.style_applications,
		"Shuffle does not reinitialize tile styles"
	)
	var shuffle_position_changed := false
	for shuffled_tile_id in shuffle_board.get("_last_shuffle_start_positions"):
		if shuffle_board.get("_last_shuffle_start_positions")[shuffled_tile_id] \
				!= shuffle_board.get("_last_shuffle_target_positions").get(shuffled_tile_id):
			shuffle_position_changed = true
			break
	_check(shuffle_position_changed, "Shuffle visibly moves physical tiles between old and new slots")
	_validate_board_input_order(shell, "after Shuffle")

	var orientation := "portrait" if root.size.x < root.size.y else "landscape"
	shell.call("_apply_layout")
	await process_frame
	_validate_regions(shell, orientation)
	_validate_board_tiles(shell, orientation)
	_validate_consumables(shell, orientation)

	shell.call("_on_update_available", "0.2.0-smoke.1", "https://play.google.com/apps/internaltest/4701554282456194202", false)
	await process_frame
	var banner: Control = shell.get("_update_banner")
	_check(banner != null and banner.visible, "%s update banner displays on available update" % orientation)
	if banner != null and banner.visible:
		var banner_rect := Rect2(banner.position, banner.size)
		var safe_viewport := SafeAreaScript.content_rect(shell.get_viewport_rect().size, shell.call("_get_safe_area_insets"))
		_check(shell.get_viewport_rect().encloses(banner_rect), "%s update banner stays inside viewport (%s)" % [orientation, banner_rect])
		_check(safe_viewport.encloses(banner_rect), "%s update banner stays inside safe area (%s in %s)" % [orientation, banner_rect, safe_viewport])
		_check(
			not Rect2(banner.position, banner.size).intersects(Rect2(shell.get("_pause_button").position, shell.get("_pause_button").size)),
			"%s update banner does not cover pause button" % orientation
		)
		banner.call("_on_dismiss_pressed")
		_check(not banner.visible, "%s update banner hides on dismiss" % orientation)
		await process_frame

	shell.call("_on_restart_requested")
	live_game = shell.get("_game")
	var end_game_menu: Control = shell.get("_end_game_menu")
	var loss_tiles: Array = []
	for tile in live_game.board.call("selectable_tiles"):
		var is_unique := true
		for existing in loss_tiles:
			if existing.face.family == tile.face.family and existing.face.value == tile.face.value:
				is_unique = false
				break
		if is_unique:
			loss_tiles.append(tile)
		if loss_tiles.size() == 4:
			break
	if loss_tiles.size() == 4:
		for tile in loss_tiles:
			shell.call("_on_tile_selected", tile.id)
		_check(end_game_menu != null and end_game_menu.visible, "%s end game menu displays on loss" % orientation)
		if end_game_menu != null and end_game_menu.visible:
			var result_panel: Control = end_game_menu.get("_panel")
			var result_safe_rect := SafeAreaScript.content_rect(
				end_game_menu.size,
				shell.call("_get_safe_area_insets")
			)
			var result_scale := maxf(
				0.78,
				minf(result_safe_rect.size.x / 390.0, result_safe_rect.size.y / 844.0)
			)
			_check(is_equal_approx(float(end_game_menu.get("_display_scale")), result_scale), "%s end game overlay uses the shared responsive scale" % orientation)
			_check(is_equal_approx(result_panel.size.x, 330.0 * result_scale), "%s end game panel scales from the shared reference width" % orientation)
			_check_equal(roundi(27.0 * result_scale), end_game_menu.get("_title_label").get_theme_font_size("font_size"), "%s end game title scales with the overlay" % orientation)
			_check(is_equal_approx(48.0 * result_scale, end_game_menu.get("_restart_button").custom_minimum_size.y), "%s end game command targets scale with the overlay" % orientation)
			_check(
				shell.get_viewport_rect().encloses(result_panel.get_global_rect()),
				"%s end game panel stays inside viewport (%s)" % [orientation, result_panel.get_global_rect()]
			)
			var frozen_time: int = shell.call("_playback_time_ms")
			await create_timer(0.05).timeout
			_check_equal(frozen_time, shell.call("_playback_time_ms"), "%s playback time freezes on game over" % orientation)
			if not OS.get_cmdline_user_args().has("--end-game-capture"):
				shell.call("_on_restart_requested")
				live_game = shell.get("_game")
				_check(not end_game_menu.visible, "%s end game menu hides on restart" % orientation)
				await process_frame

	shell.set("_delete_pair_armed", false)
	shell.get("_regions").board.call("set_delete_pair_armed", false)
	if OS.get_cmdline_user_args().has("--hint-capture"):
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
		shell.call("_on_hint_requested")
		shell.get("_regions").board.call("_process", 0.3)
	elif OS.get_cmdline_user_args().has("--modifier-callout-capture"):
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
		var modifier_tile_id: String = str(live_game.definition.modifier_attachments.keys()[0])
		var modifier_pair := _find_selectable_pair_for_tile(live_game, modifier_tile_id)
		if modifier_pair.size() == 2:
			shell.call("_on_tile_selected", modifier_pair[0])
			await create_timer(0.28).timeout
			shell.call("_on_tile_selected", modifier_pair[1])
			await create_timer(0.18).timeout
			_check_equal("modifier_reward", shell.get("_performance_callout").get("last_alert_type"), "resolved modifier pair displays its reward callout")
	elif OS.get_cmdline_user_args().has("--callout-capture"):
		shell.call("_on_restart_requested")
		live_game = shell.get("_game")
		shell.call("_apply_layout")
		var capture_pair := _find_rewardable_pair(live_game)
		if capture_pair.size() == 2:
			shell.call("_on_tile_selected", capture_pair[0])
			await create_timer(0.2).timeout
			shell.call("_on_tile_selected", capture_pair[1])
			await create_timer(0.18).timeout
	elif not modifier_playtest:
		var capture_tile_id := ""
		for tile in live_game.board.call("selectable_tiles"):
			capture_tile_id = tile.id
			break
		if not capture_tile_id.is_empty():
			shell.call("_on_tile_selected", capture_tile_id)
			await create_timer(0.25).timeout
	if OS.get_cmdline_user_args().has("--pause-menu"):
		shell.call("_on_pause_requested")
		await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		printerr("capture skipped: active renderer does not expose a framebuffer")
	else:
		RenderingServer.force_draw()
		var image := root.get_texture().get_image()
		var capture_name := "end-game" if OS.get_cmdline_user_args().has("--end-game-capture") \
			else "difficulty-callout" if OS.get_cmdline_user_args().has("--callout-capture") \
			else "modifier-callout" if OS.get_cmdline_user_args().has("--modifier-callout-capture") \
			else "hint" if OS.get_cmdline_user_args().has("--hint-capture") \
			else "pause-menu" if OS.get_cmdline_user_args().has("--pause-menu") \
			else "modifier-playtest" if modifier_playtest \
			else "small-phone" if OS.get_cmdline_user_args().has("--small-phone") \
			else "safe-%s" % orientation if OS.get_cmdline_user_args().has("--safe-area") else orientation
		var output_path := "user://m7_%s.png" % capture_name
		if image == null:
			printerr("capture skipped: active renderer does not expose a framebuffer")
		elif image.save_png(output_path) != OK:
			_fail("could not save %s capture" % orientation)
		else:
			printerr("capture: %s" % ProjectSettings.globalize_path(output_path))

	printerr("PASS: responsive UI smoke" if _failures == 0 else "FAIL: %d responsive UI check(s)" % _failures)
	shell.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if _failures > 0 else 0)


func _validate_regions(shell: Control, orientation: String) -> void:
	var regions: Dictionary = shell.get("_regions")
	_check_equal(orientation, shell.get("_tile_skin").orientation, "%s selects its matching tile base variant" % orientation)
	var viewport_rect := shell.get_viewport_rect()
	var safe_viewport: Rect2 = SafeAreaScript.content_rect(viewport_rect.size, shell.call("_get_safe_area_insets"))
	var debug_panel: Control = shell.get("_debug_panel")
	var pause_button: Button = shell.get("_pause_button")
	var momentum: Control = regions.momentum
	var board: Control = regions.board
	var combo_label: Label = momentum.get("_combo")
	var momentum_meter: ProgressBar = momentum.get("_meter")
	_check(not Rect2(combo_label.position, combo_label.size).intersects(Rect2(momentum_meter.position, momentum_meter.size)), "%s Combo readout does not cover Momentum meter" % orientation)
	_check_equal(
		load("res://game-assets/ui/portrait/background.png"),
		shell.get("_gameplay_background").texture,
		"%s uses the shared Figma gameplay background" % orientation
	)
	if orientation == "portrait":
		var expected_portrait_scale := minf(safe_viewport.size.x / 390.0, safe_viewport.size.y / 844.0)
		_check(not board.get("_title_label").visible and not board.get("_status_label").visible, "portrait removes the placeholder Board header to maximize tile space")
		_check(board.get("_tile_layer").position.y <= 6.01, "portrait tile layout begins near the top of the Board region")
		var consumables: Control = regions.consumables
		var bottom_background: NinePatchRect = consumables.get("_portrait_background")
		_check(bottom_background.visible and not consumables.get("_background").visible, "portrait replaces the provisional consumables panel with supplied artwork")
		_check_equal(load("res://assets/UI/bottom-bar/bottom-tray-background-export.png"), bottom_background.texture, "portrait uses the supplied bottom bar background")
		_check_equal(Vector2(2172.0, 724.0), bottom_background.texture.get_size(), "portrait bottom bar retains its authored source dimensions")
		_check_equal(652, bottom_background.get_patch_margin(SIDE_LEFT), "portrait bottom bar preserves its 30 percent left patch")
		_check_equal(652, bottom_background.get_patch_margin(SIDE_RIGHT), "portrait bottom bar preserves its 30 percent right patch")
		_check_equal(362, bottom_background.get_patch_margin(SIDE_TOP), "portrait bottom bar preserves its 50 percent top patch")
		_check_equal(362, bottom_background.get_patch_margin(SIDE_BOTTOM), "portrait bottom bar preserves its 50 percent bottom patch")
		var bottom_component_scale := minf(consumables.size.x / 366.0, consumables.size.y / 149.2696)
		_check(is_equal_approx(bottom_background.size.x * bottom_background.scale.x, 366.0 * bottom_component_scale), "portrait bottom bar stretches to the Figma component width")
		_check(is_equal_approx(bottom_background.size.y * bottom_background.scale.y, 136.0 * bottom_component_scale), "portrait bottom bar preserves the Figma background height")
		var portrait_art: Dictionary = consumables.get("_portrait_art")
		var expected_icons := {
			"hint": load("res://assets/UI/bottom-bar/icon-hint.png"),
			"shuffle": load("res://assets/UI/bottom-bar/icon-shuffle.png"),
			"delete_pair": load("res://assets/UI/bottom-bar/icon-delete.png"),
			"undo": load("res://assets/UI/bottom-bar/icon-undo.png"),
		}
		for consumable_type in ["hint", "shuffle", "delete_pair", "undo"]:
			var art: Dictionary = portrait_art[consumable_type]
			_check(art.root.visible, "portrait displays %s Figma action artwork" % consumable_type)
			_check_equal(load("res://assets/UI/bottom-bar/tile-cap.png"), art.cap.texture, "portrait %s uses the supplied ceramic cap" % consumable_type)
			_check_equal(expected_icons[consumable_type], art.icon.texture, "portrait %s uses its exported Figma icon" % consumable_type)
			_check_equal(load("res://assets/UI/bottom-bar/count-bg.png"), art.number_background.texture, "portrait %s uses the supplied quantity plaque" % consumable_type)
			var action_font: FontVariation = art.title.get_theme_font("font")
			_check_equal(load("res://assets/fonts/mila-script-sans-bold.ttf"), action_font.base_font, "portrait %s label uses Mila Script Sans Bold" % consumable_type)
			_check_equal(-2, action_font.spacing_glyph, "portrait %s label uses tightened glyph spacing" % consumable_type)
			_check_equal(str(shell.get("_game").call("consumable_count", consumable_type)), art.quantity.text, "portrait %s shows its live quantity" % consumable_type)
		var hud_scrim: TextureRect = shell.get("_portrait_hud_scrim")
		_check(hud_scrim.visible, "portrait displays the exported Figma HUD top scrim")
		_check_equal(load("res://game-assets/ui/portrait/hud_top_scrim.svg"), hud_scrim.texture, "portrait uses the latest Figma HUD top scrim asset")
		_check_equal(TextureRect.STRETCH_SCALE, hud_scrim.stretch_mode, "portrait HUD top scrim scales with the viewport width")
		_check(is_equal_approx(hud_scrim.size.x, viewport_rect.size.x), "portrait HUD top scrim spans the full viewport width")
		_check(is_equal_approx(hud_scrim.size.y, viewport_rect.size.x * 167.0 / 390.0), "portrait HUD top scrim preserves its Figma fade depth")
		_check(momentum.get("_portrait_style"), "portrait enables the Figma Momentum presentation")
		_check(momentum.get("_score_art").visible, "portrait shows the exported score-box artwork")
		_check(momentum.get("_momentum_frame").visible, "portrait shows the exported Momentum frame")
		_check(momentum.get("_momentum_badge").visible, "portrait shows the exported multiplier badge")
		_check_equal(7, momentum.get("_ticks").size(), "portrait Momentum exposes seven visible multiplier upgrades")
		for tick_index in range(momentum.get("_ticks").size()):
			_check_equal("%dX" % (tick_index + 2), momentum.get("_ticks")[tick_index].text, "portrait Momentum tick %d skips the default x1 tier" % (tick_index + 1))
		_check(momentum.get("_fill_clip").clip_contents, "portrait Momentum fill is clipped for runtime animation")
		var score_font: FontVariation = momentum.get("_score").get_theme_font("font")
		var score_title_font: FontVariation = momentum.get("_score_title").get_theme_font("font")
		_check_equal(load("res://assets/fonts/mila-script-sans-regular.ttf"), score_font.base_font, "portrait score uses Mila Script Sans Regular")
		_check_equal(load("res://assets/fonts/mila-script-sans-bold.ttf"), score_title_font.base_font, "portrait score heading uses Mila Script Sans Bold")
		_check_equal(-2, score_font.spacing_glyph, "portrait score uses tightened glyph spacing")
		_check_equal(-2, score_title_font.spacing_glyph, "portrait heading uses tightened glyph spacing")
		_check_equal("123,456,789", momentum.call("_format_score", 123456789), "portrait score formatting groups thousands")
		_check_equal("01:02.34", momentum.call("_format_time", 62340), "portrait timer formats runtime playback")
		_check(
			is_equal_approx(momentum.size.y, 81.0 * expected_portrait_scale),
			"portrait HUD scales from both safe display dimensions"
		)
		_check(
			is_equal_approx(momentum.get("_momentum_frame").get_global_rect().get_center().x, safe_viewport.get_center().x),
			"portrait Momentum frame stays centered in the safe display width"
		)
		_check(is_equal_approx(pause_button.size.x, pause_button.size.y), "portrait pause artwork preserves a square control")
		_check(
			is_equal_approx(pause_button.size.x, 48.0 * expected_portrait_scale),
			"portrait pause control scales with the display resolution"
		)
		_check_equal(
			load("res://game-assets/ui/portrait/pause_button.png"),
			pause_button.icon,
			"portrait pause button uses the exported Figma artwork"
		)
	else:
		_check(not shell.get("_portrait_hud_scrim").visible, "landscape hides the portrait-only HUD top scrim")
		_check(not regions.consumables.get("_portrait_background").visible, "landscape hides the portrait bottom bar artwork")
		for art in regions.consumables.get("_portrait_art").values():
			_check(not art.root.visible, "landscape hides portrait action artwork")
		_check(not momentum.get("_portrait_style"), "landscape retains the existing compact HUD presentation")
	_check(viewport_rect.encloses(Rect2(pause_button.position, pause_button.size)), "%s pause button stays inside viewport" % orientation)
	_check(safe_viewport.encloses(Rect2(pause_button.position, pause_button.size)), "%s pause button stays inside safe area" % orientation)
	if debug_panel.visible:
		_check(viewport_rect.encloses(Rect2(debug_panel.position, debug_panel.size)), "%s debug panel stays inside viewport" % orientation)
		_check(safe_viewport.encloses(Rect2(debug_panel.position, debug_panel.size)), "%s debug panel stays inside safe area" % orientation)
	var names: Array = []
	for name in regions:
		if regions[name].visible:
			names.append(name)
	for name in names:
		var region: Control = regions[name]
		var region_rect := Rect2(region.position, region.size)
		_check(
			viewport_rect.encloses(region_rect),
			"%s %s stays inside viewport (%s in %s)" % [orientation, name, region_rect, viewport_rect]
		)
		_check(
			safe_viewport.encloses(region_rect),
			"%s %s stays inside safe area (%s in %s)" % [orientation, name, region_rect, safe_viewport]
		)

	var tray: Control = regions.tray
	var board_tile_size: Vector2 = board.call("tile_visual_size")
	var tray_tile_scale: float = shell.get("tray_tile_scale")
	_check(is_equal_approx(tray_tile_scale, 0.80), "%s uses the tuned 80 percent tray tile scale" % orientation)
	_check(is_equal_approx(float(shell.get("tile_transfer_seconds")), 0.24), "%s uses the slower tray transfer beat" % orientation)
	_check(is_equal_approx(float(shell.get("tile_flip_seconds")), 0.25), "%s uses the tuned quarter-second tile flip" % orientation)
	_check(is_equal_approx(float(shell.get("flipped_auto_match_hold_seconds")), 0.14), "%s uses the shortened auto-match readability hold" % orientation)
	_check(is_equal_approx(float(shell.get("tray_compaction_seconds")), 0.16), "%s uses the tuned queue-compaction beat" % orientation)
	if orientation == "portrait":
		_check(tray.get("_portrait_style"), "portrait enables the Figma queue presentation")
		_check(tray.get("_queue_left_cap").visible and tray.get("_queue_right_cap").visible, "portrait queue renders both exported end caps")
		_check_equal(load("res://assets/UI/tile-queue/queue-cap.png"), tray.get("_queue_left_cap").texture, "portrait queue uses the supplied cap artwork")
		_check_equal(load("res://assets/UI/tile-queue/queue-repeat.png"), tray.get("_queue_repeats")[0].texture, "portrait queue uses the supplied repeat artwork")
		_check_equal(Vector2(25.0, 115.0), tray.get("_queue_left_cap").texture.get_size(), "portrait queue cap keeps its supplied source dimensions")
		_check_equal(Vector2(63.0, 115.0), tray.get("_queue_repeats")[0].texture.get_size(), "portrait queue repeat keeps its supplied source dimensions")
		var queue_repeat_image: Image = tray.get("_queue_repeats")[0].texture.get_image()
		var repeat_right_stroke := queue_repeat_image.get_pixel(57, 58)
		_check(repeat_right_stroke.a > 0.9 and repeat_right_stroke.r > 0.5, "portrait queue repeat retains its closing right-side gold stroke")
		var queue_cap_image: Image = tray.get("_queue_left_cap").texture.get_image()
		var cap_inner_stroke := queue_cap_image.get_pixel(7, 58)
		_check(cap_inner_stroke.a > 0.9 and cap_inner_stroke.r > 0.5, "portrait queue cap retains the latest matching inner gold stroke")
		_check(tray.get("_queue_right_cap").flip_h, "portrait queue mirrors the supplied cap on the right")
		var left_cap_rect: Rect2 = tray.get("_queue_left_cap").get_rect()
		var right_cap_rect: Rect2 = tray.get("_queue_right_cap").get_rect()
		for queue_section in tray.get("_queue_repeats"):
			if queue_section.visible:
				_check(is_equal_approx(queue_section.position.y, left_cap_rect.position.y), "portrait queue repeat aligns to the cap top edge")
				_check(is_equal_approx(queue_section.size.y, left_cap_rect.size.y), "portrait queue repeat aligns to the cap bottom edge")
		_check(is_equal_approx(right_cap_rect.position.y, left_cap_rect.position.y), "portrait queue right cap aligns to the left cap top edge")
		_check(is_equal_approx(right_cap_rect.size.y, left_cap_rect.size.y), "portrait queue caps share the same rendered height")
		_check_equal(6, tray.get("_queue_repeats").size(), "portrait queue owns reusable artwork for its 2-6 slot range")
		var visible_queue_sections := 0
		var previous_queue_section: TextureRect = null
		for queue_section in tray.get("_queue_repeats"):
			if queue_section.visible:
				visible_queue_sections += 1
				if previous_queue_section != null:
					_check(previous_queue_section.get_rect().end.x > queue_section.position.x, "portrait queue repeat artwork overlaps its neighbor to prevent filtered seams")
				previous_queue_section = queue_section
		_check(tray.get("_queue_left_cap").get_rect().end.x > tray.get("_queue_repeats")[0].position.x, "portrait queue left cap overlaps the first repeat without changing its stride")
		_check(previous_queue_section.get_rect().end.x > tray.get("_queue_right_cap").position.x, "portrait queue right cap overlaps the final repeat without changing its stride")
		var tray_capacity: int = shell.get("_game").tray.capacity
		_check_equal(tray_capacity, visible_queue_sections, "portrait queue renders one repeated section per active slot")
		_check_equal(tray_capacity, tray.call("_slot_count"), "portrait queue follows the live tray capacity")
		for slot_index in range(tray_capacity):
			var queue_scale: float = tray.get("_queue_repeats")[slot_index].size.y / 115.0
			var expected_slot_center_x: float = tray.get("_queue_repeats")[slot_index].position.x + (62.42 * 0.5 - 1.5) * queue_scale
			_check(
				is_equal_approx(tray.get("_slots")[slot_index].get_rect().get_center().x, expected_slot_center_x),
				"portrait tray tile %d keeps its approved slight left bias in the visual queue slot" % (slot_index + 1)
			)
		for slot_index in range(shell.get("_game").tray.tiles.size(), tray_capacity):
			var empty_slot_style: StyleBoxFlat = tray.get("_slots")[slot_index].get_theme_stylebox("panel")
			_check_equal(Color.TRANSPARENT, empty_slot_style.bg_color, "portrait empty slot %d is supplied only by Figma artwork" % (slot_index + 1))
	else:
		_check(not tray.get("_portrait_style"), "landscape retains the existing tray presentation")
	for slot in tray.get("_slots"):
		_check(slot.size.is_equal_approx(board_tile_size * tray_tile_scale), "%s tray slot scales down from the board tile footprint" % orientation)
	var callout: Control = shell.get("_performance_callout")
	var callout_label: Label = callout.get("_label")
	_check_equal(Rect2(board.position, board.size), Rect2(callout.position, callout.size), "%s callout tracks the board region" % orientation)
	_check(Rect2(Vector2.ZERO, callout.size).encloses(Rect2(callout_label.position, callout_label.size)), "%s callout text stays inside the board overlay" % orientation)
	callout.call("play_alert", {
		"type": "board_progress",
		"key": "all_tiles_revealed",
		"text": "ALL TILES REVEALED!",
	})
	var expected_callout_scale := maxf(0.72, minf(board.size.x / 390.0, board.size.y / 560.0))
	var callout_font_size := callout_label.get_theme_font_size("font_size")
	var rendered_callout_width := callout_label.get_theme_font("font").get_string_size(
		callout_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		callout_font_size
	).x
	_check(callout_label.visible, "%s board-progress callout is accepted by the shared lane" % orientation)
	_check_equal("board_progress", callout.get("last_alert_type"), "%s board-progress callout records its alert type" % orientation)
	_check(
		callout_font_size >= floori(20.0 * expected_callout_scale),
		"%s callout typography scales with the rendered Board (font=%d scale=%.2f)" % [
			orientation,
			callout_font_size,
			expected_callout_scale,
		]
	)
	_check(
		callout_label.get_theme_constant("outline_size") >= floori(7.0 * expected_callout_scale),
		"%s callout outline scales with the rendered Board" % orientation
	)
	_check(rendered_callout_width <= callout_label.size.x * 0.95, "%s long callout copy fits its responsive lane" % orientation)
	if orientation == "portrait":
		_check(board.position.y < tray.position.y + tray.size.y, "portrait Board reclaims the queue artwork's transparent lower padding")
	else:
		_check(tray.position.y + tray.size.y <= board.position.y, "landscape tray stays above the game board")
	var board_global_rect := board.get_global_rect()
	for slot_index in range(4):
		var tray_tile_rect: Rect2 = tray.call("slot_visual_global_rect", slot_index)
		_check(not tray_tile_rect.intersects(board_global_rect), "%s rendered tray tile %d does not overlap the Board" % [orientation, slot_index + 1])
		_check(tray.get_global_rect().encloses(tray_tile_rect), "%s rendered tray tile %d stays inside the Tray" % [orientation, slot_index + 1])
	if orientation == "portrait":
		_check(board.position.y + board.size.y > regions.consumables.position.y, "portrait Board reclaims the action dock's transparent upper padding")
		for button in regions.consumables.get("_buttons").values():
			_check(not button.get_global_rect().intersects(board_global_rect), "portrait consumable touch targets stay below the Board")
		_check(not regions.character.visible, "portrait decorative region yields to the gameplay stack")
	else:
		_check(regions.momentum.position.x + regions.momentum.size.x <= board.position.x, "landscape Momentum stays in the upper-left rail")
		_check(is_equal_approx(tray.get_rect().get_center().x, board.get_rect().get_center().x), "landscape tray is centered over the Board")
		_check(not regions.character.visible, "landscape decorative region yields to the central Board and side actions")
	var pause_rect := Rect2(pause_button.position, pause_button.size)
	if orientation == "portrait":
		_check(
			regions.consumables.get("_portrait_background").position.y > 7.2696 * minf(regions.consumables.size.x / 366.0, regions.consumables.size.y / 149.2696),
			"portrait action dock shifts its component through transparent lower padding"
		)
		_check(not pause_rect.intersects(momentum.get("_momentum_badge").get_global_rect()), "portrait pause button does not cover the centered Momentum presentation")
	else:
		_check(not pause_rect.intersects(Rect2(regions.momentum.position, regions.momentum.size)), "landscape pause button does not cover Momentum")

	for first_index in range(names.size()):
		for second_index in range(first_index + 1, names.size()):
			if orientation == "landscape" and "consumables" in [names[first_index], names[second_index]]:
				continue
			if orientation == "portrait" and "board" in [names[first_index], names[second_index]] \
				and ("tray" in [names[first_index], names[second_index]] or "consumables" in [names[first_index], names[second_index]]):
				continue
			var first: Control = regions[names[first_index]]
			var second: Control = regions[names[second_index]]
			_check(
				not Rect2(first.position, first.size).intersects(Rect2(second.position, second.size)),
				"%s %s and %s do not overlap" % [orientation, names[first_index], names[second_index]]
			)

	if orientation == "portrait" and debug_panel.visible:
		for name in names:
			var region: Control = regions[name]
			_check(
				not Rect2(debug_panel.position, debug_panel.size).intersects(Rect2(region.position, region.size)),
				"portrait debug panel and %s do not overlap" % name
			)


func _validate_board_tiles(shell: Control, orientation: String) -> void:
	var board: Control = shell.get("_regions").board
	var skin: Variant = shell.get("_tile_skin")
	var tile_layer: Control = board.get("_tile_layer")
	var tile_layer_rect := Rect2(Vector2.ZERO, tile_layer.size)
	var minimum_tile_size := Vector2(INF, INF)
	var has_visible_tile := false
	var has_visible_base := false
	var has_visible_shadow := false
	var has_visible_ink_outline := false
	var selectable_brightness_is_canonical := true
	var shadow_bands_isolate_layers := true
	for tile in shell.get("_game").board.tiles:
		var button: Button = board.get("_tile_buttons")[tile.id]
		var tile_rect := Rect2(button.position, button.size)
		_check(tile_layer_rect.encloses(tile_rect), "%s %s stays inside board bounds" % [orientation, button.name])
		minimum_tile_size.x = minf(minimum_tile_size.x, button.size.x)
		minimum_tile_size.y = minf(minimum_tile_size.y, button.size.y)
		var shadow_art: TextureRect = button.get_node("DepthShadow")
		var surface_band: int = tile.position.z * 2 + 1
		var shadow_band: int = button.z_index + shadow_art.z_index
		if button.z_index != surface_band or shadow_band != tile.position.z * 2:
			shadow_bands_isolate_layers = false
		if tile.position.z > 0 and not ((tile.position.z - 1) * 2 + 1 < shadow_band and shadow_band < surface_band):
			shadow_bands_isolate_layers = false
		if button.visible:
			has_visible_tile = true
			if bool(button.get_meta("targetable", false)) and button.modulate != Color.WHITE:
				selectable_brightness_is_canonical = false
			var ink_outline: TextureRect = button.get_node("InkOutline")
			if ink_outline.visible and not has_visible_ink_outline:
				has_visible_ink_outline = true
				_check(ink_outline.texture == skin.call("tile_base_texture"), "%s ink outline follows the active tile silhouette" % orientation)
				_check(ink_outline.anchor_left < 0.0 and ink_outline.anchor_right > 1.0, "%s ink outline expands beyond the ceramic edge" % orientation)
			if shadow_art.visible and not has_visible_shadow:
				has_visible_shadow = true
				_check(shadow_art.texture == skin.call("tile_base_texture"), "%s tile shadow follows the active base silhouette" % orientation)
				_check(shadow_art.position.x > 0.0 and shadow_art.position.y > 0.0, "%s tile shadow projects down and right" % orientation)
			var base_art: TextureRect = button.get_node("BaseArt")
			if base_art.visible and not has_visible_base:
				has_visible_base = true
				_check(base_art.texture == skin.call("tile_base_texture"), "%s board tile uses the active ceramic base" % orientation)
	if not OS.get_cmdline_user_args().has("--safe-area"):
		var active_geometry: Dictionary = skin.call("active_geometry")
		var minimum_runtime: Array = active_geometry.minimum_runtime_size
		_check(
			minimum_tile_size.x >= float(minimum_runtime[0]) \
				and minimum_tile_size.y >= float(minimum_runtime[1]),
			"%s tiles preserve their orientation minimum footprint (%s)" % [orientation, minimum_tile_size]
		)
	_check(has_visible_tile, "%s board renders visible tiles" % orientation)
	_check(has_visible_base, "%s board renders the supplied ceramic base artwork" % orientation)
	_check(has_visible_shadow, "%s board renders cast shadows beneath tiles" % orientation)
	_check(shadow_bands_isolate_layers, "%s shadows render below their own layer and above the next tile layer" % orientation)
	_check(has_visible_ink_outline, "%s board renders manga-ink tile silhouettes" % orientation)
	_check(selectable_brightness_is_canonical, "%s all selectable tiles share canonical brightness" % orientation)
	var adjacent_pair_checked := false
	var board_tiles: Array = shell.get("_game").board.tiles
	for left_tile in board_tiles:
		if adjacent_pair_checked:
			break
		for right_tile in board_tiles:
			if left_tile.position.z == right_tile.position.z \
					and left_tile.position.y == right_tile.position.y \
					and left_tile.position.x + 2 == right_tile.position.x:
				var left_button: Button = board.get("_tile_buttons")[left_tile.id]
				var right_button: Button = board.get("_tile_buttons")[right_tile.id]
				if left_button.visible and right_button.visible:
					var rendered_gap := right_button.position.x - (left_button.position.x + left_button.size.x)
					_check(rendered_gap <= 0.0, "%s adjacent tile artwork meets without a seam" % orientation)
					adjacent_pair_checked = true
					break
	_check(adjacent_pair_checked, "%s validates a visible authored adjacent pair" % orientation)
	var maximum_depth := 0
	for tile in shell.get("_game").board.tiles:
		maximum_depth = maxi(maximum_depth, tile.position.z)
	if maximum_depth > 0:
		var previous_brightness := float(board.call("_depth_brightness", 0, maximum_depth))
		for depth in range(1, maximum_depth + 1):
			var brightness := float(board.call("_depth_brightness", depth, maximum_depth))
			_check(brightness > previous_brightness, "%s authored layer %d is brighter than layer %d" % [orientation, depth, depth - 1])
			previous_brightness = brightness
		_check(is_equal_approx(previous_brightness, 1.0), "%s highest authored layer remains fully lit" % orientation)
		if maximum_depth > 1:
			_check(
				is_equal_approx(
					float(board.call("_depth_brightness", maximum_depth - 1, maximum_depth)),
					float(skin.depth_presentation.near_top_layer_brightness)
				),
				"%s layer directly below the top uses the lighter skin-defined brightness" % orientation
			)
	if orientation == "portrait":
		_check(minimum_tile_size.y > minimum_tile_size.x, "portrait uses tall tile artwork (%s)" % minimum_tile_size)
	else:
		_check(minimum_tile_size.x > minimum_tile_size.y, "landscape uses wide tile artwork (%s)" % minimum_tile_size)


func _validate_consumables(shell: Control, orientation: String) -> void:
	var consumables: Control = shell.get("_regions").consumables
	var board: Control = shell.get("_regions").board
	var buttons: Dictionary = consumables.get("_buttons")
	var panel_rect := Rect2(Vector2.ZERO, consumables.size)
	var controls: Array[Control] = []
	for button in buttons.values():
		controls.append(button)
	var notice: Label = consumables.get("_notice")
	if notice.visible:
		controls.append(notice)
	for control in controls:
		_check(panel_rect.encloses(Rect2(control.position, control.size)), "%s consumable control stays inside its panel" % orientation)
	if orientation == "portrait":
		_check(consumables.get("_horizontal_dock"), "portrait keeps consumables in bottom-dock mode")
		_check(buttons.hint.position.x < buttons.shuffle.position.x, "portrait places Shuffle after Hint")
		_check(buttons.shuffle.position.x < buttons.delete_pair.position.x, "portrait places Delete after Shuffle")
		_check(buttons.delete_pair.position.x < buttons.undo.position.x, "portrait keeps Undo rightmost")
		var first_button_y: float = buttons.values()[0].position.y
		for button in buttons.values():
			_check(is_equal_approx(button.position.y, first_button_y), "portrait consumables remain in one bottom row")
			_check(button.text.is_empty(), "portrait action touch targets do not draw generic Button text")
	for first_index in range(controls.size()):
		for second_index in range(first_index + 1, controls.size()):
			var first_rect := Rect2(controls[first_index].position, controls[first_index].size)
			var second_rect := Rect2(controls[second_index].position, controls[second_index].size)
			_check(
				not first_rect.intersects(second_rect),
				"%s consumable controls do not overlap (%s %s, %s %s)" % [
					orientation,
					controls[first_index].name,
					first_rect,
					controls[second_index].name,
					second_rect,
				]
			)
	_check(buttons.has("undo"), "%s consumables own Undo" % orientation)
	if orientation == "landscape":
		var board_rect := Rect2(board.position, board.size)
		for consumable_type in buttons:
			var button: Button = buttons[consumable_type]
			var button_rect := Rect2(consumables.position + button.position, button.size)
			_check(not button_rect.intersects(board_rect), "landscape %s stays in a side rail outside the Board" % consumable_type)
			_check(button.size.x >= 120.0 and button.size.y >= 54.0, "landscape %s preserves a large touch target" % consumable_type)
		_check(buttons.hint.position.x == buttons.delete_pair.position.x, "landscape left rail groups Hint and Delete Pair")
		_check(buttons.shuffle.position.x == buttons.undo.position.x, "landscape right rail groups Shuffle and Undo")
		_check(buttons.hint.position.y < buttons.delete_pair.position.y, "landscape Hint sits above Delete Pair")
		_check(buttons.shuffle.position.y < buttons.undo.position.y, "landscape Shuffle sits above Undo")
	else:
		for consumable_type in buttons:
			if consumable_type != "undo":
				_check(buttons.undo.position.x > buttons[consumable_type].position.x, "%s Undo stays rightmost" % orientation)
	var tray_has_command_button := false
	for child in shell.get("_regions").tray.get_children():
		tray_has_command_button = tray_has_command_button or child is Button
	_check(not tray_has_command_button, "%s tray contains no command buttons" % orientation)


func _validate_board_input_order(shell: Control, context: String) -> void:
	var board: Control = shell.get("_regions").board
	var ordered_tiles: Array = shell.get("_game").board.tiles.duplicate()
	ordered_tiles.sort_custom(Callable(board, "_tile_precedes_for_input"))
	var controls_follow_stack := true
	for index in range(ordered_tiles.size()):
		var button: Button = board.get("_tile_buttons")[ordered_tiles[index].id]
		if button.get_index() != index:
			controls_follow_stack = false
			break
	_check(controls_follow_stack, "%s tile controls follow visual stack for overlapping touch routing" % context)


func _find_rewardable_pair(game: Variant) -> Array[String]:
	var analysis: Dictionary = game.call("opportunity_analysis")
	for pair in analysis.pair_scores:
		var observed: Dictionary = pair.duplicate(true)
		observed["source"] = "board_pair"
		if not PairDifficultyRewardsScript.evaluate(observed, game.definition.configuration).is_empty():
			var ids: Array[String] = []
			ids.assign(pair.tile_ids)
			return ids
	return []


func _verify_modifier_activation_feedback(shell: Control) -> void:
	var game: Variant = shell.get("_game")
	var feedback: Control = shell.get("_modifier_feedback")
	var momentum: Control = shell.get("_regions").momentum
	var tray: Control = shell.get("_regions").tray
	var expected_types := ["extra_life", "cold_snap", "score_multiplier", "tray_plus_one", "three_pair_clear"]
	for modifier_type in expected_types:
		var modifier_tile_id := _find_modifier_tile_id(game, modifier_type)
		var pair := _find_solver_pair_for_tile(game, modifier_tile_id)
		_check_equal(2, pair.size(), "%s playtest modifier sits on the next solver-route pair" % modifier_type)
		if pair.size() != 2:
			continue
		var feedback_before: int = feedback.get("play_count")
		var capacity_feedback_before: int = tray.get("capacity_feedback_count")
		var pair_feedback_before: int = shell.get("_pair_feedback_count")
		shell.call("_on_tile_selected", pair[0])
		await create_timer(0.28).timeout
		shell.call("_on_tile_selected", pair[1])
		await process_frame
		_check_equal(feedback_before + 1, feedback.get("play_count"), "%s starts one shared activation sequence" % modifier_type)
		_check_equal(modifier_type, feedback.get("last_modifier_type"), "%s selects its activation treatment" % modifier_type)
		_check_equal("modifier_reward", shell.get("_performance_callout").get("last_alert_type"), "%s owns the live-text callout lane" % modifier_type)
		var snapshot: Variant = game.call("current_snapshot")
		match modifier_type:
			"extra_life":
				_check(int(snapshot.extra_life_charges) > 0, "Extra Life persists as an available charge")
				_check(momentum.get("_extra_life_icon").visible, "Extra Life status appears beside Score")
				_check_equal(str(snapshot.extra_life_charges), momentum.get("_extra_life_count").text, "Extra Life HUD shows its live charge count")
			"cold_snap":
				_check(int(snapshot.cold_snap_until_ms) > shell.call("_playback_time_ms"), "Cold Snap persists with a live expiry")
				_check("FROZEN" in momentum.get("_effect_status").text, "Cold Snap status appears on Momentum")
			"score_multiplier":
				_check(int(snapshot.score_multiplier_until_ms) > shell.call("_playback_time_ms"), "Score Multiplier persists with a live expiry")
				_check("SCORE" in momentum.get("_effect_status").text, "Score Multiplier status appears on Momentum")
			"tray_plus_one":
				_check_equal(5, game.tray.capacity, "Tray +1 expands the authoritative tray to five slots")
				_check_equal(capacity_feedback_before + 1, tray.get("capacity_feedback_count"), "Tray +1 emphasizes the new queue section")
				if tray.get("_portrait_style"):
					_check(tray.get("_queue_repeats")[4].visible, "Tray +1 reveals a fifth repeat section in the existing queue artwork")
				else:
					_check(tray.get("_slots")[4].visible, "Tray +1 reveals a fifth live slot in the landscape queue")
				_check(tray.get("_bonus_icon").visible, "Tray +1 marks the expanded queue section")
				_check("PAIRS" in tray.get("_bonus_label").text, "Tray +1 displays its remaining pair duration")
				_check(shell.get_viewport_rect().encloses(tray.get_global_rect()), "expanded tray remains inside the responsive viewport")
			"three_pair_clear":
				var transaction: Variant = game.call("last_transaction")
				_check_equal(3, transaction.telemetry.get("auto_clear_pairs", []).size(), "Three Pair Clear records its ordered visual sequence")
				_check(shell.get("_auto_clear_animation_active"), "Three Pair Clear blocks input during its serial presentation")
				await create_timer(1.65).timeout
				_check_equal(pair_feedback_before + 4, shell.get("_pair_feedback_count"), "Three Pair Clear presents its trigger and three assisted pairs")
				_check(not shell.get("_auto_clear_animation_active"), "Three Pair Clear releases input after the third pair")
		await create_timer(0.55).timeout


func _find_modifier_tile_id(game: Variant, modifier_type: String) -> String:
	for tile_id in game.definition.modifier_attachments:
		if str(game.definition.modifier_attachments[tile_id].type) == modifier_type:
			return str(tile_id)
	return ""


func _find_solver_pair_for_tile(game: Variant, tile_id: String) -> Array[String]:
	var layout: Variant = BoardLayoutCatalogScript.new().call(
		"get_layout",
		game.definition.configuration.layout_id
	)
	var plan: Array = LayoutSolutionPlannerScript.new().call("build_plan", layout)
	var tile_index := -1
	for index in range(game.definition.tiles.size()):
		if game.definition.tiles[index].id == tile_id:
			tile_index = index
			break
	for pair_indexes in plan:
		if tile_index in pair_indexes:
			var first_id: String = game.definition.tiles[int(pair_indexes[0])].id
			var second_id: String = game.definition.tiles[int(pair_indexes[1])].id
			if game.board.call("is_tile_selectable", first_id) \
					and game.board.call("is_tile_selectable", second_id):
				return [first_id, second_id]
			return []
	return []


func _find_selectable_pair_for_tile(game: Variant, tile_id: String) -> Array[String]:
	var tile: Variant = game.board.call("get_tile", tile_id)
	if tile == null or not game.board.call("is_tile_selectable", tile_id):
		return []
	for candidate in game.board.call("selectable_tiles"):
		if candidate.id != tile_id and candidate.face.equals(tile.face):
			return [tile_id, candidate.id]
	return []


func _find_selectable_distinct_from_tray(game: Variant, excluded_tile_id: String) -> String:
	for candidate in game.board.call("selectable_tiles"):
		if candidate.id == excluded_tile_id:
			continue
		var matches_held_tile := false
		for held in game.tray.tiles:
			if held.face.family == candidate.face.family and held.face.value == candidate.face.value:
				matches_held_tile = true
				break
		if not matches_held_tile:
			return candidate.id
	return ""


func _find_visible_pair(game: Variant) -> Array[String]:
	var visible: Array = game.board.call("visible_tiles")
	for first_index in range(visible.size()):
		for second_index in range(first_index + 1, visible.size()):
			var first: Variant = visible[first_index]
			var second: Variant = visible[second_index]
			if first.face.family == second.face.family and first.face.value == second.face.value:
				return [first.id, second.id]
	return []

func _check(condition: bool, message: String) -> void:
	if condition:
		printerr("OK: %s" % message)
	else:
		_fail(message)


func _check_equal(expected: Variant, actual: Variant, message: String) -> void:
	_check(expected == actual, "%s (expected=%s actual=%s)" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures += 1
	printerr("ERR: %s" % message)
