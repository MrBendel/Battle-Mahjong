@tool
extends SceneTree

const TRAY_SOURCE_PATH := "res://art-source/inspiration/consumables/consumables-tray.png"
const ICON_SOURCE_PATH := "res://art-source/inspiration/consumables/consumable-icons.png"
const TILE_SOURCE_PATH := "res://art-source/ui/consumables/consumable-tile-clean.png"
const SOURCE_OUTPUT_DIR := "res://art-source/ui/consumables"
const RUNTIME_OUTPUT_DIR := "res://game-assets/ui/consumables"
const RUNTIME_SCALE := 0.5

const TRAY_SLICES := {
	"tray-left.png": Rect2i(108, 190, 170, 360),
	"tray-repeat.png": Rect2i(868, 190, 330, 360),
	"tray-right.png": Rect2i(1791, 190, 170, 360),
}
const ICON_NAMES := ["hint.png", "shuffle.png", "undo.png", "delete-pair.png"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUNTIME_OUTPUT_DIR))
	if not _slice_tray() or not _slice_icons() or not _export_tile():
		quit(1)
		return
	quit()


func _slice_tray() -> bool:
	var source := Image.load_from_file(TRAY_SOURCE_PATH)
	if source == null or source.is_empty():
		push_error("Unable to load consumables tray source: %s" % TRAY_SOURCE_PATH)
		return false
	for file_name in TRAY_SLICES:
		_export_piece(file_name, source.get_region(TRAY_SLICES[file_name]))
	return true


func _slice_icons() -> bool:
	var source := Image.load_from_file(ICON_SOURCE_PATH)
	if source == null or source.is_empty():
		push_error("Unable to load consumable icon source: %s" % ICON_SOURCE_PATH)
		return false
	var cell_width := source.get_width() / ICON_NAMES.size()
	for index in ICON_NAMES.size():
		var width := cell_width if index < ICON_NAMES.size() - 1 else source.get_width() - cell_width * index
		var icon := source.get_region(Rect2i(cell_width * index, 0, width, source.get_height()))
		var used_rect := icon.get_used_rect()
		if used_rect.size != Vector2i.ZERO:
			icon = icon.get_region(used_rect)
		_export_piece(ICON_NAMES[index], icon)
	return true


func _export_tile() -> bool:
	var source := Image.load_from_file(TILE_SOURCE_PATH)
	if source == null or source.is_empty():
		push_error("Unable to load clean consumable tile source: %s" % TILE_SOURCE_PATH)
		return false
	var used_rect := _used_rect_above_alpha(source, 8)
	if used_rect.size != Vector2i.ZERO:
		source = source.get_region(used_rect)
	_export_piece("consumable-tile.png", source)
	return true


func _used_rect_above_alpha(image: Image, threshold: int) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a8 < threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _export_piece(file_name: String, source: Image) -> void:
	source.save_png("%s/%s" % [SOURCE_OUTPUT_DIR, file_name])
	var runtime := source.duplicate()
	runtime.resize(
		maxi(1, roundi(float(source.get_width()) * RUNTIME_SCALE)),
		maxi(1, roundi(float(source.get_height()) * RUNTIME_SCALE)),
		Image.INTERPOLATE_LANCZOS
	)
	runtime.save_png("%s/%s" % [RUNTIME_OUTPUT_DIR, file_name])
	print("%s -> %s" % [file_name, runtime.get_size()])
