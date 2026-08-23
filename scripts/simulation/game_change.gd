extends RefCounted

const TILE_ZONE := "tile_zone"
const TRAY := "tray"
const COUNTER := "counter"
const STATUS := "status"
const RNG_STATE := "rng_state"
const TILE_SLOT := "tile_slot"
const CONSUMABLES := "consumables"
const HINT := "hint"
const FLIPPED_REVEALS := "flipped_reveals"

var type: String
var target: String
var before: Variant
var after: Variant


func _init(change_type: String, change_target: String, before_value: Variant, after_value: Variant) -> void:
	type = change_type
	target = change_target
	before = _copy_value(before_value)
	after = _copy_value(after_value)


func to_dict() -> Dictionary:
	return {
		"type": type,
		"target": target,
		"before": _copy_value(before),
		"after": _copy_value(after),
	}


func duplicate_change() -> RefCounted:
	return get_script().new(type, target, before, after)


static func from_dict(data: Dictionary) -> RefCounted:
	var script: Script = load("res://scripts/simulation/game_change.gd")
	return script.new(
		str(data.get("type", "")),
		str(data.get("target", "")),
		data.get("before"),
		data.get("after")
	)


func _copy_value(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value
