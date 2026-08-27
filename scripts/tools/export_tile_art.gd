extends SceneTree

const EXPORT_ROOTS := [
	["res://art-source/tiles", "res://game-assets/tiles"],
	["res://art-source/modifiers", "res://game-assets/modifiers"],
]
const RUNTIME_SCALE := 0.5


func _init() -> void:
	var failures := 0
	for roots in EXPORT_ROOTS:
		failures += _export_directory(roots[0], roots[0], roots[1])
	if failures == 0:
		printerr("Exported tile SVG masters to runtime PNG assets.")
	else:
		printerr("Failed to export %d tile asset(s)." % failures)
	quit(1 if failures > 0 else 0)


func _export_directory(source_directory: String, source_root: String, runtime_root: String) -> int:
	var failures := 0
	for directory_name in DirAccess.get_directories_at(source_directory):
		failures += _export_directory(source_directory.path_join(directory_name), source_root, runtime_root)
	for file_name in DirAccess.get_files_at(source_directory):
		var source_path := source_directory.path_join(file_name)
		var relative_path := source_path.trim_prefix(source_root + "/")
		var output_path := runtime_root.path_join(relative_path.get_basename() + ".png")
		match file_name.get_extension().to_lower():
			"svg":
				if not _export_svg(source_path, output_path):
					failures += 1
			"png":
				if not _export_raster(source_path, output_path):
					failures += 1
	return failures


func _export_svg(source_path: String, output_path: String) -> bool:
	var image := Image.new()
	var error := image.load_svg_from_string(FileAccess.get_file_as_string(source_path), RUNTIME_SCALE)
	if error != OK:
		push_error("Could not rasterize %s: %s" % [source_path, error_string(error)])
		return false
	var absolute_directory := ProjectSettings.globalize_path(output_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		push_error("Could not create runtime asset directory: %s" % output_path.get_base_dir())
		return false
	error = image.save_png(output_path)
	if error != OK:
		push_error("Could not write %s: %s" % [output_path, error_string(error)])
		return false
	printerr("%s -> %s" % [source_path, output_path])
	return true


func _export_raster(source_path: String, output_path: String) -> bool:
	var image := Image.new()
	var error := image.load(source_path)
	if error != OK:
		push_error("Could not load %s: %s" % [source_path, error_string(error)])
		return false
	image.resize(
		maxi(1, roundi(float(image.get_width()) * RUNTIME_SCALE)),
		maxi(1, roundi(float(image.get_height()) * RUNTIME_SCALE)),
		Image.INTERPOLATE_LANCZOS
	)
	var absolute_directory := ProjectSettings.globalize_path(output_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		push_error("Could not create runtime asset directory: %s" % output_path.get_base_dir())
		return false
	error = image.save_png(output_path)
	if error != OK:
		push_error("Could not write %s: %s" % [output_path, error_string(error)])
		return false
	printerr("%s -> %s" % [source_path, output_path])
	return true
