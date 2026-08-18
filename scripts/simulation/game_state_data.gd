extends RefCounted

const PLAYING := "playing"
const WON := "won"
const LOST := "lost"

const ZONE_BOARD := "board"
const ZONE_TRAY := "tray"
const ZONE_RESOLVED := "resolved"

var revision := 0
var status := PLAYING
var tile_zones: Dictionary = {}
var tray_tile_ids: Array[String] = []
var selection_count := 0
var resolved_pair_count := 0
var max_tray_occupancy := 0
var rng_state := 0


func _init(definition: Variant = null) -> void:
	if definition == null:
		return

	rng_state = definition.seed
	for tile in definition.tiles:
		tile_zones[tile.id] = ZONE_BOARD


func duplicate_data() -> RefCounted:
	var copy: Variant = get_script().new()
	copy.revision = revision
	copy.status = status
	copy.tile_zones = tile_zones.duplicate(true)
	copy.tray_tile_ids.assign(tray_tile_ids)
	copy.selection_count = selection_count
	copy.resolved_pair_count = resolved_pair_count
	copy.max_tray_occupancy = max_tray_occupancy
	copy.rng_state = rng_state
	return copy


func assign_from(other: Variant) -> void:
	revision = other.revision
	status = other.status
	tile_zones = other.tile_zones.duplicate(true)
	tray_tile_ids.assign(other.tray_tile_ids)
	selection_count = other.selection_count
	resolved_pair_count = other.resolved_pair_count
	max_tray_occupancy = other.max_tray_occupancy
	rng_state = other.rng_state


func state_hash() -> String:
	var tile_ids: Array = tile_zones.keys()
	tile_ids.sort()
	var zone_parts: Array[String] = []
	for tile_id in tile_ids:
		zone_parts.append("%s=%s" % [tile_id, tile_zones[tile_id]])

	var canonical := "%d|%s|%s|%s|%d|%d|%d|%d" % [
		revision,
		status,
		",".join(zone_parts),
		",".join(tray_tile_ids),
		selection_count,
		resolved_pair_count,
		max_tray_occupancy,
		rng_state,
	]
	return canonical.sha256_text()


func to_dict() -> Dictionary:
	return {
		"revision": revision,
		"status": status,
		"tile_zones": tile_zones.duplicate(true),
		"tray_tile_ids": tray_tile_ids.duplicate(),
		"selection_count": selection_count,
		"resolved_pair_count": resolved_pair_count,
		"max_tray_occupancy": max_tray_occupancy,
		"rng_state": rng_state,
	}
