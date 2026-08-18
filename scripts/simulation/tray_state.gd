extends RefCounted

const TileMatcherScript := preload("res://scripts/simulation/tile_matcher.gd")

const STORED := "stored"
const MATCHED := "matched"
const FAILED := "failed"
const REJECTED := "rejected"

var capacity: int
var tiles: Array = []
var resolved_pair_count := 0
var failed := false

var _matcher := TileMatcherScript.new()

func _init(tray_capacity: int = 4) -> void:
	capacity = tray_capacity


func add_tile(tile: Variant) -> String:
	if tile == null or failed or tiles.size() >= capacity:
		return REJECTED

	for index in range(tiles.size()):
		if _matcher.call("tiles_match", tiles[index], tile):
			tiles.remove_at(index)
			resolved_pair_count += 1
			return MATCHED

	tiles.append(tile)
	if tiles.size() == capacity:
		failed = true
		return FAILED

	return STORED
