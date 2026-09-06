extends Control
class_name AppRoot

const TownHubViewScript := preload("res://scripts/presentation/town_hub_view.gd")
const GAME_SHELL_SCENE := preload("res://scenes/game_shell.tscn")
const UpdateCheckerScript := preload("res://scripts/presentation/update_checker.gd")
const UpdateBannerViewScript := preload("res://scripts/presentation/update_banner_view.gd")
const SafeAreaScript := preload("res://scripts/presentation/safe_area.gd")

@export var town_theme: Resource

var _active_screen: Control
var _hub: Control
var _game_shell: Control
var _update_checker: Node
var _update_banner: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_update_banner()
	resized.connect(_layout_update_banner)
	_show_hub()
	_update_checker.call("check_for_updates")


func _setup_update_banner() -> void:
	_update_checker = UpdateCheckerScript.new()
	_update_checker.name = "UpdateChecker"
	_update_checker.update_available.connect(_on_update_available)
	add_child(_update_checker)

	_update_banner = UpdateBannerViewScript.new()
	_update_banner.name = "GlobalUpdateBanner"
	_update_banner.visible = false
	_update_banner.z_index = 2000
	_update_banner.dismissed.connect(_layout_update_banner)
	_update_banner.update_requested.connect(_on_update_requested)
	add_child(_update_banner)


func _layout_update_banner() -> void:
	if _update_banner == null or not _update_banner.visible:
		return
	var edge_insets := SafeAreaScript.insets(size, DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size())
	var margin := 12.0
	var banner_height := 44.0
	var available_width := maxf(100.0, size.x - edge_insets.position.x - edge_insets.size.x - margin * 2.0)
	_update_banner.position = Vector2(edge_insets.position.x + margin, edge_insets.position.y + 6.0)
	_update_banner.size = Vector2(available_width, banner_height)


func _on_update_available(version_name: String, store_url: String, mandatory: bool) -> void:
	_update_banner.call("show_update", version_name, store_url, mandatory)
	_layout_update_banner()


func _on_update_requested() -> void:
	if _update_checker != null and _update_checker.has_method("start_in_app_update"):
		_update_checker.call("start_in_app_update", false)


func _show_hub() -> void:
	_replace_active_screen(null)
	_hub = TownHubViewScript.new(town_theme)
	_hub.name = "TownHub"
	_hub.destination_requested.connect(_on_destination_requested)
	_replace_active_screen(_hub)
	_game_shell = null


func _show_game() -> void:
	_replace_active_screen(null)
	_game_shell = GAME_SHELL_SCENE.instantiate()
	_game_shell.name = "GameShell"
	_game_shell.return_to_town_requested.connect(_show_hub)
	_replace_active_screen(_game_shell)
	_hub = null


func _replace_active_screen(next_screen: Control) -> void:
	if _active_screen != null:
		remove_child(_active_screen)
		_active_screen.queue_free()
	_active_screen = next_screen
	if _active_screen != null:
		add_child(_active_screen)
	if _update_banner != null and _update_banner.get_parent() == self:
		move_child(_update_banner, -1)
		_layout_update_banner()


func _on_destination_requested(destination_id: String) -> void:
	if destination_id == "tower":
		_show_game()


func open_destination_for_testing(destination_id: String) -> void:
	_on_destination_requested(destination_id)
