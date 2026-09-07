extends Resource
class_name GameplayTheme

@export var theme_id := "default"
@export var display_name := "Default"

@export_group("Surface")
@export_file("*.png", "*.svg", "*.webp") var background_path := "res://game-assets/ui/portrait/background.png"
@export_range(0, 512, 1) var background_patch_margin := 48
@export_file("*.png", "*.svg", "*.webp") var hud_scrim_path := "res://game-assets/ui/portrait/hud_top_scrim.svg"

@export_group("Status HUD")
@export_file("*.png", "*.svg", "*.webp") var status_panel_path := "res://game-assets/ui/shared/status-panel.svg"
@export_file("*.png", "*.svg", "*.webp") var score_box_path := "res://game-assets/ui/portrait/score_box.png"
@export_file("*.png", "*.svg", "*.webp") var momentum_frame_path := "res://game-assets/ui/shared/status-momentum-frame.svg"
@export_file("*.png", "*.svg", "*.webp") var momentum_fill_path := "res://game-assets/ui/shared/status-momentum-fill.svg"
@export_file("*.png", "*.svg", "*.webp") var momentum_badge_path := "res://game-assets/ui/shared/status-flame.svg"
@export_file("*.png", "*.svg", "*.webp") var heart_icon_path := "res://game-assets/ui/shared/status-heart.svg"
@export_file("*.ttf", "*.otf", "*.tres") var regular_font_path := "res://assets/fonts/mila-script-sans-regular-tight.tres"
@export_file("*.ttf", "*.otf", "*.tres") var bold_font_path := "res://assets/fonts/mila-script-sans-bold-tight.tres"
@export_file("*.ttf", "*.otf", "*.tres") var poster_font_path := "res://assets/fonts/battle-mahjong-poster-script.tres"

@export_group("Tray")
@export_file("*.png", "*.svg", "*.webp") var tray_cap_path := "res://assets/UI/tile-queue/queue-cap.png"
@export_file("*.png", "*.svg", "*.webp") var tray_repeat_path := "res://assets/UI/tile-queue/queue-repeat.png"
@export_file("*.png", "*.svg", "*.webp") var tray_vertical_cap_path := "res://game-assets/ui/shared/tray-cap-vertical.svg"
@export_file("*.png", "*.svg", "*.webp") var tray_vertical_repeat_path := "res://game-assets/ui/shared/tray-repeat-vertical.svg"
@export_file("*.png", "*.svg", "*.webp") var tray_bonus_icon_path := "res://game-assets/modifiers/tile-overlays/tray_plus_one.png"

@export_group("Controls")
@export_file("*.png", "*.svg", "*.webp") var pause_button_path := "res://game-assets/ui/shared/pause-button.svg"
@export_file("*.png", "*.svg", "*.webp") var consumables_background_path := "res://assets/UI/bottom-bar/bottom-tray-background-export.png"
@export_file("*.png", "*.svg", "*.webp") var consumable_tile_path := "res://assets/UI/bottom-bar/tile-cap.png"
@export_file("*.png", "*.svg", "*.webp") var consumable_count_path := "res://assets/UI/bottom-bar/count-bg.png"
@export_file("*.png", "*.svg", "*.webp") var hint_icon_path := "res://assets/UI/bottom-bar/icon-hint.png"
@export_file("*.png", "*.svg", "*.webp") var shuffle_icon_path := "res://assets/UI/bottom-bar/icon-shuffle.png"
@export_file("*.png", "*.svg", "*.webp") var delete_pair_icon_path := "res://assets/UI/bottom-bar/icon-delete.png"
@export_file("*.png", "*.svg", "*.webp") var undo_icon_path := "res://assets/UI/bottom-bar/icon-undo.png"

@export_group("Tiles")
@export_file("*.json") var tile_skin_manifest_path := "res://game-assets/tiles/default/skin.json"


func consumable_icon_path(consumable_type: String) -> String:
	match consumable_type:
		"hint":
			return hint_icon_path
		"shuffle":
			return shuffle_icon_path
		"delete_pair":
			return delete_pair_icon_path
		"undo":
			return undo_icon_path
	return ""


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if theme_id.strip_edges().is_empty():
		errors.append("Gameplay theme id is required.")
	if background_patch_margin < 0:
		errors.append("Background patch margin cannot be negative.")
	var asset_paths := {
		"background": background_path,
		"HUD scrim": hud_scrim_path,
		"status panel": status_panel_path,
		"Score box": score_box_path,
		"Momentum frame": momentum_frame_path,
		"Momentum fill": momentum_fill_path,
		"Momentum badge": momentum_badge_path,
		"heart icon": heart_icon_path,
		"regular font": regular_font_path,
		"bold font": bold_font_path,
		"poster font": poster_font_path,
		"tray cap": tray_cap_path,
		"tray repeat": tray_repeat_path,
		"vertical tray cap": tray_vertical_cap_path,
		"vertical tray repeat": tray_vertical_repeat_path,
		"tray bonus icon": tray_bonus_icon_path,
		"Pause button": pause_button_path,
		"consumables background": consumables_background_path,
		"consumable tile": consumable_tile_path,
		"consumable count": consumable_count_path,
		"Hint icon": hint_icon_path,
		"Shuffle icon": shuffle_icon_path,
		"Delete Pair icon": delete_pair_icon_path,
		"Undo icon": undo_icon_path,
		"tile skin manifest": tile_skin_manifest_path,
	}
	for label in asset_paths:
		var asset_path := str(asset_paths[label])
		if asset_path.is_empty() or not (ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)):
			errors.append("Missing %s asset: %s" % [label, asset_path])
	return errors
