extends SceneTree


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		printerr("Usage: set_android_export_version.gd <version-code> <version-name> [keystore-path] [keystore-user] [keystore-password]")
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
	if arguments.size() >= 5:
		presets.set_value("preset.0.options", "keystore/release", str(arguments[2]).strip_edges())
		presets.set_value("preset.0.options", "keystore/release_user", str(arguments[3]).strip_edges())
		presets.set_value("preset.0.options", "keystore/release_password", str(arguments[4]).strip_edges())

	var save_error := presets.save("res://export_presets.cfg")
	if save_error != OK:
		printerr("Unable to save export_presets.cfg: %s" % error_string(save_error))
		quit(1)
		return

	var version_json_file := FileAccess.open("res://version.json", FileAccess.WRITE)
	if version_json_file != null:
		var version_dict := {
			"latest_version_code": version_code,
			"latest_version_name": version_name,
			"min_version_code": 0,
			"store_url": "https://play.google.com/apps/internaltest/4701554282456194202"
		}
		version_json_file.store_string(JSON.stringify(version_dict, "\t") + "\n")
		version_json_file.close()

	quit()
