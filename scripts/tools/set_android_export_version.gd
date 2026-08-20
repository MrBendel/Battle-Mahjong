extends SceneTree


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		printerr("Usage: set_android_export_version.gd <version-code> <version-name>")
		quit(1)
		return

	var version_code := int(arguments[0])
	var version_name := str(arguments[1]).strip_edges()
	if version_code <= 0 or version_name.is_empty():
		printerr("Android version code and name must be positive and non-empty.")
		quit(1)
		return

	var presets := ConfigFile.new()
	var load_error := presets.load("res://export_presets.cfg")
	if load_error != OK:
		printerr("Unable to load export_presets.cfg: %s" % error_string(load_error))
		quit(1)
		return

	presets.set_value("preset.0.options", "version/code", version_code)
	presets.set_value("preset.0.options", "version/name", version_name)
	var save_error := presets.save("res://export_presets.cfg")
	if save_error != OK:
		printerr("Unable to save export_presets.cfg: %s" % error_string(save_error))
		quit(1)
		return
	quit()
