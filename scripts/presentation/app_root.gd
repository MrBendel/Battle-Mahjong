extends Control
class_name AppRoot

const TownHubViewScript := preload("res://scripts/presentation/town_hub_view.gd")
const GAME_SHELL_SCENE := preload("res://scenes/game_shell.tscn")
const TowerRunScript := preload("res://scripts/simulation/tower_run.gd")
const BoardLayoutRequirementsScript := preload("res://scripts/simulation/board_layout_requirements.gd")
const ProceduralLayoutGeneratorScript := preload("res://scripts/simulation/procedural_layout_generator.gd")
const TOWER_RUNTIME_CONFIGURATION := "res://configuration/tower/tower_runtime.json"

@export var town_theme: Resource

var _active_screen: Control
var _hub: Control
var _game_shell: Control
var _tower_run: RefCounted


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("android_screenshots"):
		_show_quick_play(false)
	else:
		_show_hub()


func _show_hub() -> void:
	_replace_active_screen(null)
	_tower_run = null
	_hub = TownHubViewScript.new(town_theme)
	_hub.name = "TownHub"
	_hub.destination_requested.connect(_on_destination_requested)
	_replace_active_screen(_hub)
	_game_shell = null


func _show_quick_play(show_layout_generator: bool = true) -> void:
	_replace_active_screen(null)
	_game_shell = GAME_SHELL_SCENE.instantiate()
	_game_shell.name = "GameShell"
	_game_shell.call("configure_launch", {
		"mode": "quick_play",
		"seed": _new_run_seed(),
		"show_layout_generator": show_layout_generator,
		"show_modifier_picker": show_layout_generator,
	})
	_game_shell.return_to_town_requested.connect(_show_hub)
	_replace_active_screen(_game_shell)
	_hub = null


func _start_tower() -> void:
	var configuration := TowerRunScript.load_configuration(TOWER_RUNTIME_CONFIGURATION)
	if configuration.is_empty():
		return
	_tower_run = TowerRunScript.new(_new_run_seed(), configuration)
	var errors: Array[String] = _tower_run.call("validation_errors")
	if not errors.is_empty():
		push_error("Invalid Tower runtime configuration: %s" % "; ".join(errors))
		_tower_run = null
		return
	_show_tower_floor()


func _show_tower_floor() -> void:
	var spec: Dictionary = _tower_run.call("floor_spec")
	var requirements: Variant = BoardLayoutRequirementsScript.load_file(spec.requirements_path)
	var layout: Variant = ProceduralLayoutGeneratorScript.new().call(
		"generate",
		requirements,
		int(spec.layout_seed),
		"tower_%010d_floor_%06d" % [_tower_run.run_seed, int(spec.floor_number)]
	)
	if layout == null:
		push_error("Tower floor generation failed for floor %d." % int(spec.floor_number))
		_show_hub()
		return
	_replace_active_screen(null)
	_game_shell = GAME_SHELL_SCENE.instantiate()
	_game_shell.name = "GameShell"
	_game_shell.call("configure_launch", {
		"mode": "tower",
		"floor_number": spec.floor_number,
		"seed": spec.deal_seed,
		"layout": layout,
		"deal_options": spec.deal_options,
		"tray_capacity": spec.tray_capacity,
		"show_layout_generator": false,
	})
	_game_shell.return_to_town_requested.connect(_show_hub)
	_game_shell.next_tower_floor_requested.connect(_on_next_tower_floor_requested)
	_replace_active_screen(_game_shell)
	_hub = null


func _on_next_tower_floor_requested() -> void:
	_tower_run.call("advance")
	_show_tower_floor()


func _new_run_seed() -> int:
	return maxi(1, int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec())


func _replace_active_screen(next_screen: Control) -> void:
	if _active_screen != null:
		remove_child(_active_screen)
		_active_screen.queue_free()
	_active_screen = next_screen
	if _active_screen != null:
		add_child(_active_screen)


func _on_destination_requested(destination_id: String) -> void:
	match destination_id:
		"home":
			_show_quick_play()
		"tower":
			_start_tower()


func open_destination_for_testing(destination_id: String) -> void:
	_on_destination_requested(destination_id)
