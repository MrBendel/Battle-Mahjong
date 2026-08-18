extends RefCounted

var id: String
var face: Variant
var position: Variant
var removed := false

func _init(tile_id: String, tile_face: Variant, board_position: Variant) -> void:
	id = tile_id
	face = tile_face
	position = board_position
