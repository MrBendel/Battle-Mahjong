extends Node

signal update_available(latest_version_name: String, store_url: String, is_mandatory: bool)
signal check_completed(up_to_date: bool)
signal startup_received(startup_data: Dictionary)
signal maintenance_active(message: String)

const DEFAULT_STORE_URL: String = "https://play.google.com/apps/internaltest/4701554282456194202"
const DEFAULT_CHECK_VERSION_URL: String = "https://battle-mahjong-backend-yz6hgthnca-uc.a.run.app/v1/startup"

@export var store_url: String = DEFAULT_STORE_URL
@export var check_version_url: String = DEFAULT_CHECK_VERSION_URL

var startup_config: Dictionary = {}
var _plugin_singleton: Object = null
var _http_request: HTTPRequest = null


func _ready() -> void:
	_detect_play_core_plugin()
	_setup_http_request()


func _setup_http_request() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "VersionHTTPRequest"
	_http_request.request_completed.connect(_on_http_request_completed)
	add_child(_http_request)


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


func get_current_version_code() -> int:
	if FileAccess.file_exists("res://export_presets.cfg"):
		var presets := ConfigFile.new()
		if presets.load("res://export_presets.cfg") == OK:
			var code: Variant = presets.get_value("preset.0.options", "version/code", null)
			if code != null and int(code) > 0:
				return int(code)
	if FileAccess.file_exists("res://version.json"):
		var file := FileAccess.open("res://version.json", FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				var code: int = int(json.data.get("latest_version_code", 0))
				if code > 0:
					return code
	return 1


func get_current_version_name() -> String:
	if FileAccess.file_exists("res://export_presets.cfg"):
		var presets := ConfigFile.new()
		if presets.load("res://export_presets.cfg") == OK:
			var vname: String = str(presets.get_value("preset.0.options", "version/name", ""))
			if not vname.is_empty():
				return vname
	if FileAccess.file_exists("res://version.json"):
		var file := FileAccess.open("res://version.json", FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				var vname: String = str(json.data.get("latest_version_name", ""))
				if not vname.is_empty():
					return vname
	return "0.1.0"


func _build_remote_url(base_url: String) -> String:
	if not base_url.contains("?"):
		var platform := OS.get_name().to_lower()
		var code := get_current_version_code()
		var vname := get_current_version_name()
		return "%s?platform=%s&version_code=%d&version_name=%s" % [base_url, platform, code, vname]
	return base_url


func check_for_updates() -> void:
	if _plugin_singleton != null:
		if _plugin_singleton.has_method("checkForUpdate"):
			_plugin_singleton.call("checkForUpdate")
			return
		elif _plugin_singleton.has_method("check_for_update"):
			_plugin_singleton.call("check_for_update")
			return

	var target_url := check_version_url if not check_version_url.is_empty() else DEFAULT_CHECK_VERSION_URL
	if not target_url.is_empty() and (target_url.begins_with("http://") or target_url.begins_with("https://")):
		if _http_request != null:
			var request_url := _build_remote_url(target_url)
			var err := _http_request.request(request_url)
			if err == OK:
				return

	_check_local_version_file()


func _check_local_version_file() -> void:
	if FileAccess.file_exists("res://version.json"):
		var file := FileAccess.open("res://version.json", FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				_evaluate_version_dict(json.data)
				return
	check_completed.emit(true)


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary:
			_evaluate_version_dict(json.data)
			return

	_check_local_version_file()


func _evaluate_version_dict(dict: Dictionary) -> void:
	startup_config = dict
	startup_received.emit(dict)

	if dict.has("maintenance") and dict["maintenance"] is Dictionary:
		var m_dict: Dictionary = dict["maintenance"]
		if bool(m_dict.get("active", false)):
			maintenance_active.emit(str(m_dict.get("message", "")))

	var version_data: Dictionary = dict
	if dict.has("version") and dict["version"] is Dictionary:
		version_data = dict["version"]

	var remote_code: int = int(version_data.get("latest_version_code", 0))
	var remote_name: String = str(version_data.get("latest_version_name", ""))
	var min_code: int = int(version_data.get("min_version_code", 0))
	var force_update: bool = bool(version_data.get("force_update", false))
	var remote_url: String = str(version_data.get("store_url", store_url))
	if remote_url.is_empty():
		remote_url = DEFAULT_STORE_URL

	var current_code := get_current_version_code()
	if remote_code > current_code:
		var mandatory := force_update or (current_code < min_code)
		update_available.emit(remote_name, remote_url, mandatory)
		check_completed.emit(false)
	else:
		check_completed.emit(true)


func start_in_app_update(is_mandatory: bool = false) -> void:
	if _plugin_singleton != null:
		if _plugin_singleton.has_method("startUpdate"):
			_plugin_singleton.call("startUpdate", is_mandatory)
			return
		elif _plugin_singleton.has_method("start_in_app_update"):
			_plugin_singleton.call("start_in_app_update", is_mandatory)
			return

	var url := store_url if not store_url.is_empty() else DEFAULT_STORE_URL
	OS.shell_open(url)


func mock_trigger_update_available(version_name: String = "0.2.0", url: String = DEFAULT_STORE_URL, mandatory: bool = false) -> void:
	update_available.emit(version_name, url, mandatory)
	check_completed.emit(false)


func _on_native_update_available(arg1: Variant = null, arg2: Variant = null, _arg3: Variant = null) -> void:
	var version_name := ""
	var mandatory := false
	if arg1 is Dictionary:
		version_name = str(arg1.get("version_name", arg1.get("versionName", "")))
		mandatory = bool(arg1.get("is_mandatory", arg1.get("mandatory", false)))
	elif arg1 != null:
		version_name = str(arg1)
		if arg2 != null:
			mandatory = bool(arg2)

	if version_name.is_empty():
		version_name = "0.2.0"

	var url := store_url if not store_url.is_empty() else DEFAULT_STORE_URL
	update_available.emit(version_name, url, mandatory)
	check_completed.emit(false)


func _on_native_update_not_available(_arg1: Variant = null) -> void:
	check_completed.emit(true)
