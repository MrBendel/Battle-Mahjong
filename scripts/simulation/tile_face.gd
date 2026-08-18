extends RefCounted

const FAMILY_BAMBOO := "bamboo"
const FAMILY_DOTS := "dots"
const FAMILY_CHARACTERS := "characters"
const FAMILY_WIND := "wind"
const FAMILY_DRAGON := "dragon"

const WIND_EAST := "east"
const WIND_SOUTH := "south"
const WIND_WEST := "west"
const WIND_NORTH := "north"

const DRAGON_RED := "red_dragon"
const DRAGON_GREEN := "green_dragon"
const DRAGON_WHITE := "white_dragon"

var family: String
var value: String

func _init(face_family: String, face_value: String) -> void:
	family = face_family
	value = face_value


func logical_id() -> String:
	return "%s_%s" % [family, value]


func equals(other: Variant) -> bool:
	return other != null and family == other.family and value == other.value
