extends RefCounted

const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")

var id: String:
	get:
		return _id

var position: Variant:
	get:
		return _position

var _id: String
var _position: Variant


func _init(slot_id: String, slot_position: Variant) -> void:
	_id = slot_id
	_position = BoardPositionScript.new(slot_position.x, slot_position.y, slot_position.z)


func to_dict() -> Dictionary:
	return {
		"slot_id": id,
		"x": position.x,
		"y": position.y,
		"z": position.z,
	}


static func coordinate_id(position: Variant) -> String:
	return "z%d_x%d_y%d" % [position.z, position.x, position.y]
