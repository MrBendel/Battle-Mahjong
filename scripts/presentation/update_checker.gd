extends Node

signal update_available(latest_version_name: String, store_url: String, is_mandatory: bool)
signal check_completed(up_to_date: bool)

const DEFAULT_STORE_URL := "https://play.google.com/apps/internaltest/4701554282456194202"

@export var store_url: String = DEFAULT_STORE_URL

var _plugin_singleton: Object = null


func _ready() -> void:
	_detect_play_core_plugin()


func _detect_play_core_plugin() -> void:
	if OS.get_name() == "Android":
		for candidate in ["GodotPlayCore", "GodotGooglePlayInAppUpdate", "InAppUpdate"]:
			if Engine.has_singleton(candidate):
				_plugin_singleton = Engine.get_singleton(candidate)
				_connect_plugin_signals()
				break


func _connect_plugin_signals() -> void:
	if _plugin_singleton == null:
		return
	if _plugin_singleton.has_signal("on_update_available"):
		_plugin_singleton.connect("on_update_available", Callable(self, "_on_native_update_available"))
	elif _plugin_singleton.has_signal("update_available"):
		_plugin_singleton.connect("update_available", Callable(self, "_on_native_update_available"))

	if _plugin_singleton.has_signal("on_update_not_available"):
		_plugin_singleton.connect("on_update_not_available", Callable(self, "_on_native_update_not_available"))
	elif _plugin_singleton.has_signal("update_not_available"):
		_plugin_singleton.connect("update_not_available", Callable(self, "_on_native_update_not_available"))


func check_for_updates() -> void:
	if _plugin_singleton != null:
		if _plugin_singleton.has_method("checkForUpdate"):
			_plugin_singleton.call("checkForUpdate")
			return
		elif _plugin_singleton.has_method("check_for_update"):
			_plugin_singleton.call("check_for_update")
			return

	check_completed.emit(true)


func start_in_app_update(is_mandatory: bool = false) -> void:
	if _plugin_singleton != null:
		if _plugin_singleton.has_method("startUpdate"):
			_plugin_singleton.call("startUpdate", is_mandatory)
			return
		elif _plugin_singleton.has_method("start_in_app_update"):
			_plugin_singleton.call("start_in_app_update", is_mandatory)
			return

	if not store_url.is_empty():
		OS.shell_open(store_url)


func mock_trigger_update_available(version_name: String = "0.2.0", url: String = DEFAULT_STORE_URL, mandatory: bool = false) -> void:
	update_available.emit(version_name, url, mandatory)
	check_completed.emit(false)


func _on_native_update_available(version_name: String = "", mandatory: bool = false) -> void:
	var url := store_url if not store_url.is_empty() else DEFAULT_STORE_URL
	update_available.emit(version_name, url, mandatory)
	check_completed.emit(false)


func _on_native_update_not_available() -> void:
	check_completed.emit(true)
