@tool
extends SceneTree

const SOURCE_PATH := "res://art-source/inspiration/tiles/tile-tray.png"
const SOURCE_OUTPUT_DIR := "res://art-source/ui/tray/porcelain"
const RUNTIME_OUTPUT_DIR := "res://game-assets/ui/tray/porcelain"
const RUNTIME_SCALE := 0.5

const SLICES := {
	"tray-left.png": Rect2i(282, 180, 334, 477),
	"tray-repeat.png": Rect2i(616, 180, 299, 477),
	"tray-right.png": Rect2i(1214, 180, 331, 477),
}


func _init() -> void:
	var source := Image.load_from_file(SOURCE_PATH)
	if source == null or source.is_empty():
		push_error("Unable to load porcelain tray source: %s" % SOURCE_PATH)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUNTIME_OUTPUT_DIR))
	for file_name in SLICES:
		var piece := source.get_region(SLICES[file_name])
		piece.save_png("%s/%s" % [SOURCE_OUTPUT_DIR, file_name])
		var runtime := piece.duplicate()
		runtime.resize(
			maxi(1, roundi(float(piece.get_width()) * RUNTIME_SCALE)),
			maxi(1, roundi(float(piece.get_height()) * RUNTIME_SCALE)),
			Image.INTERPOLATE_LANCZOS
		)
		runtime.save_png("%s/%s" % [RUNTIME_OUTPUT_DIR, file_name])
		print("%s -> %s" % [file_name, runtime.get_size()])

	quit()
