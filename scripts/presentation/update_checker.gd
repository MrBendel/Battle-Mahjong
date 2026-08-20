extends Node

signal update_available(latest_version_name: String, store_url: String, is_mandatory: bool)
signal check_completed(up_to_date: bool)

const MANIFEST_URL := "https://raw.githubusercontent.com/MrBendel/Battle-Mahjong/main/version.json"
const DEFAULT_STORE_URL := "https://play.google.com/apps/internaltest/4701554282456194202"

@export var current_version_code: int = 0
@export var manifest_url: String = MANIFEST_URL

var _http_request: HTTPRequest

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "HTTPRequest"
	_http_request.timeout = 5.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)


func check_for_updates() -> void:
	if manifest_url.is_empty():
		check_completed.emit(true)
		return
	var err := _http_request.request(manifest_url)
	if err != OK:
		check_completed.emit(true)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		check_completed.emit(true)
		return

	var json_text := body.get_string_from_utf8()
	var json: Variant = JSON.parse_string(json_text)
	if not (json is Dictionary):
		check_completed.emit(true)
		return

	var latest_code: int = int(json.get("latest_version_code", 0))
	var latest_name: String = str(json.get("latest_version_name", ""))
	var min_code: int = int(json.get("min_version_code", 0))
	var store_url: String = str(json.get("store_url", DEFAULT_STORE_URL))

	if current_version_code > 0 and latest_code > current_version_code:
		var is_mandatory := current_version_code < min_code
		update_available.emit(latest_name, store_url, is_mandatory)
		check_completed.emit(false)
	else:
		check_completed.emit(true)
