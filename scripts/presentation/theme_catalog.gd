extends RefCounted
class_name ThemeCatalog

const GameplayThemeScript := preload("res://scripts/presentation/gameplay_theme.gd")

const DEFAULT_THEME_ID := "default"
const THEME_DIRECTORY := "res://configuration/themes"
const ORDERED_THEME_IDS: Array[String] = [
	"default",
	"neon_nights",
	"imperial_jade",
	"kawaii_pop",
	"vintage_washi",
]

var _cached_themes := {}


func theme_ids() -> Array[String]:
	return ORDERED_THEME_IDS.duplicate()


func get_theme(theme_id: String = DEFAULT_THEME_ID) -> GameplayTheme:
	var target_id := theme_id.strip_edges()
	if target_id.is_empty():
		target_id = DEFAULT_THEME_ID
	if _cached_themes.has(target_id):
		return _cached_themes[target_id]
	var path := theme_path(target_id)
	if not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var res: Resource = load(path)
		if res is GameplayTheme:
			_cached_themes[target_id] = res
			return res
	# Fallback to default if not found
	if target_id != DEFAULT_THEME_ID:
		return get_theme(DEFAULT_THEME_ID)
	return null


func next_theme(current_id: String) -> GameplayTheme:
	var index := ORDERED_THEME_IDS.find(current_id)
	var next_index: int
	if index == -1:
		next_index = 0
	else:
		next_index = (index + 1) % ORDERED_THEME_IDS.size()
	return get_theme(ORDERED_THEME_IDS[next_index])


func all_themes() -> Array[GameplayTheme]:
	var list: Array[GameplayTheme] = []
	for id in ORDERED_THEME_IDS:
		var theme := get_theme(id)
		if theme != null:
			list.append(theme)
	return list


func theme_path(theme_id: String) -> String:
	return "%s/%s.tres" % [THEME_DIRECTORY, theme_id]
