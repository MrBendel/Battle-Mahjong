extends RefCounted

const FOOTPRINT_SIZE := 2

var x: int:
	get:
		return _x

var y: int:
	get:
		return _y

var z: int:
	get:
		return _z

var _x: int
var _y: int
var _z: int

func _init(position_x: int, position_y: int, position_z: int) -> void:
	_x = position_x
	_y = position_y
	_z = position_z


func equals(other: Variant) -> bool:
	return other != null and x == other.x and y == other.y and z == other.z


func overlaps_footprint(other: Variant) -> bool:
	if other == null:
		return false

	var x_overlaps: bool = x < other.x + FOOTPRINT_SIZE and x + FOOTPRINT_SIZE > other.x
	var y_overlaps: bool = y < other.y + FOOTPRINT_SIZE and y + FOOTPRINT_SIZE > other.y
	return x_overlaps and y_overlaps


func overlaps_y(other: Variant) -> bool:
	if other == null:
		return false

	return y < other.y + FOOTPRINT_SIZE and y + FOOTPRINT_SIZE > other.y


func is_immediately_left_of(other: Variant) -> bool:
	return other != null and z == other.z and x + FOOTPRINT_SIZE == other.x and overlaps_y(other)


func is_immediately_right_of(other: Variant) -> bool:
	return other != null and z == other.z and x == other.x + FOOTPRINT_SIZE and overlaps_y(other)


func to_key() -> String:
	return "%d,%d,%d" % [x, y, z]
