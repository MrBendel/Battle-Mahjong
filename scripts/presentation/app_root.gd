extends Control
class_name AppRoot

const TownHubViewScript := preload("res://scripts/presentation/town_hub_view.gd")
const GAME_SHELL_SCENE := preload("res://scenes/game_shell.tscn")

@export var town_theme: Resource

var _active_screen: Control
var _hub: Control
var _game_shell: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_hub()


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


func _on_destination_requested(destination_id: String) -> void:
	if destination_id == "tower":
		_show_game()


func open_destination_for_testing(destination_id: String) -> void:
	_on_destination_requested(destination_id)
