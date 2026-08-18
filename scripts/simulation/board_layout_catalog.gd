extends RefCounted

const BoardLayoutLoaderScript := preload("res://scripts/simulation/board_layout_loader.gd")

const CLASSIC_96 := "classic_96"
const STAGGERED_96 := "staggered_96"
const PORTRAIT_STACK_96 := "portrait_stack_96"
const DEFAULT_LAYOUT_ID := PORTRAIT_STACK_96
const LAYOUT_DIRECTORY := "res://configuration/layouts"


func get_layout(layout_id: String = DEFAULT_LAYOUT_ID) -> Variant:
	var loader := BoardLayoutLoaderScript.new()
	var conventional_path := "%s/%s.json" % [LAYOUT_DIRECTORY, layout_id]
	if FileAccess.file_exists(conventional_path):
		var conventional_layout: Variant = loader.call("load_file", conventional_path)
		if conventional_layout != null and conventional_layout.id == layout_id:
			return conventional_layout
	for path in _layout_files():
		if path == conventional_path:
			continue
		var layout: Variant = loader.call("load_file", path)
		if layout != null and layout.id == layout_id:
			return layout
	return null


func layout_ids() -> Array[String]:
	var ids: Array[String] = []
	var loader := BoardLayoutLoaderScript.new()
	for path in _layout_files():
		var layout: Variant = loader.call("load_file", path)
		if layout != null:
			ids.append(layout.id)
	ids.sort()
	return ids


func layout_path(layout_id: String) -> String:
	var conventional_path := "%s/%s.json" % [LAYOUT_DIRECTORY, layout_id]
	var loader := BoardLayoutLoaderScript.new()
	if FileAccess.file_exists(conventional_path):
		var conventional_layout: Variant = loader.call("load_file", conventional_path)
		if conventional_layout != null and conventional_layout.id == layout_id:
			return conventional_path
	for path in _layout_files():
		if path == conventional_path:
			continue
		var layout: Variant = loader.call("load_file", path)
		if layout != null and layout.id == layout_id:
			return path
	return ""


func _layout_files() -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(LAYOUT_DIRECTORY):
		if file_name.get_extension().to_lower() == "json":
			paths.append("%s/%s" % [LAYOUT_DIRECTORY, file_name])
	paths.sort()
	return paths
