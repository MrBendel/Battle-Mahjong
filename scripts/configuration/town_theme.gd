extends Resource
class_name TownTheme

const REQUIRED_DESTINATIONS := ["tower", "home", "game_hall", "daily_shrine", "dojo", "downtown"]

@export var theme_id := "default"
@export var display_name := "Mahjong Town"
@export var map_texture: Texture2D
@export var foreground_texture: Texture2D
@export var ambient_tint := Color.WHITE
@export var available_accent := Color("f5d56d")
@export var locked_tint := Color(0.45, 0.50, 0.47, 0.82)
@export var map_clear_color := Color("0b211e")
@export var destination_overlays: Dictionary = {}
@export var decoration_overlays: Dictionary = {}
@export var destination_sign_colors: Dictionary = {}


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if theme_id.strip_edges().is_empty():
		errors.append("theme_id must not be empty")
	if map_texture == null:
		errors.append("map_texture is required")
	for destination_id in REQUIRED_DESTINATIONS:
		if not destination_overlays.get(destination_id) is Texture2D:
			errors.append("destination_overlays.%s is required" % destination_id)
	return errors
