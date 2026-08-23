extends RefCounted

const PLAYING := "playing"
const WON := "won"
const LOST := "lost"

const ZONE_BOARD := "board"
const ZONE_TRAY := "tray"
const ZONE_RESOLVED := "resolved"

var revision := 0
var rules_version := 9
var status := PLAYING
var tile_zones: Dictionary = {}
var tile_slot_ids: Dictionary = {}
var tray_tile_ids: Array[String] = []
var consumable_counts: Dictionary = {}
var hinted_tile_ids: Array[String] = []
var revealed_flipped_tile_ids: Array[String] = []
var selection_count := 0
var resolved_pair_count := 0
var max_tray_occupancy := 0
var rng_state := 0
var momentum_units := 0
var score := 0
var elapsed_time_ms := 0
var last_selection_time_ms := 0
var last_pair_time_ms := 0
var max_multiplier := 1
var combo_count := 0
var max_combo := 0
var combo_expires_at_ms := 0
var modifier_activation_count := 0
var extra_life_charges := 0
var cold_snap_until_ms := 0
var score_multiplier_until_ms := 0
var score_multiplier_basis_points := 1000
var tray_bonus_capacity := 0
var tray_bonus_pairs_remaining := 0


func _init(definition: Variant = null) -> void:
	if definition == null:
		return

	rng_state = definition.seed
	rules_version = definition.rules_version
	for tile in definition.tiles:
		tile_zones[tile.id] = ZONE_BOARD
		tile_slot_ids[tile.id] = tile.id
	consumable_counts = definition.consumable_inventory.duplicate(true)


func duplicate_data() -> RefCounted:
	var copy: Variant = get_script().new()
	copy.revision = revision
	copy.rules_version = rules_version
	copy.status = status
	copy.tile_zones = tile_zones.duplicate(true)
	copy.tile_slot_ids = tile_slot_ids.duplicate(true)
	copy.tray_tile_ids.assign(tray_tile_ids)
	copy.consumable_counts = consumable_counts.duplicate(true)
	copy.hinted_tile_ids.assign(hinted_tile_ids)
	copy.revealed_flipped_tile_ids.assign(revealed_flipped_tile_ids)
	copy.selection_count = selection_count
	copy.resolved_pair_count = resolved_pair_count
	copy.max_tray_occupancy = max_tray_occupancy
	copy.rng_state = rng_state
	copy.momentum_units = momentum_units
	copy.score = score
	copy.elapsed_time_ms = elapsed_time_ms
	copy.last_selection_time_ms = last_selection_time_ms
	copy.last_pair_time_ms = last_pair_time_ms
	copy.max_multiplier = max_multiplier
	copy.combo_count = combo_count
	copy.max_combo = max_combo
	copy.combo_expires_at_ms = combo_expires_at_ms
	copy.modifier_activation_count = modifier_activation_count
	copy.extra_life_charges = extra_life_charges
	copy.cold_snap_until_ms = cold_snap_until_ms
	copy.score_multiplier_until_ms = score_multiplier_until_ms
	copy.score_multiplier_basis_points = score_multiplier_basis_points
	copy.tray_bonus_capacity = tray_bonus_capacity
	copy.tray_bonus_pairs_remaining = tray_bonus_pairs_remaining
	return copy


func assign_from(other: Variant) -> void:
	revision = other.revision
	rules_version = other.rules_version
	status = other.status
	tile_zones = other.tile_zones.duplicate(true)
	tile_slot_ids = other.tile_slot_ids.duplicate(true)
	tray_tile_ids.assign(other.tray_tile_ids)
	consumable_counts = other.consumable_counts.duplicate(true)
	hinted_tile_ids.assign(other.hinted_tile_ids)
	revealed_flipped_tile_ids.assign(other.revealed_flipped_tile_ids)
	selection_count = other.selection_count
	resolved_pair_count = other.resolved_pair_count
	max_tray_occupancy = other.max_tray_occupancy
	rng_state = other.rng_state
	momentum_units = other.momentum_units
	score = other.score
	elapsed_time_ms = other.elapsed_time_ms
	last_selection_time_ms = other.last_selection_time_ms
	last_pair_time_ms = other.last_pair_time_ms
	max_multiplier = other.max_multiplier
	combo_count = other.combo_count
	max_combo = other.max_combo
	combo_expires_at_ms = other.combo_expires_at_ms
	modifier_activation_count = other.modifier_activation_count
	extra_life_charges = other.extra_life_charges
	cold_snap_until_ms = other.cold_snap_until_ms
	score_multiplier_until_ms = other.score_multiplier_until_ms
	score_multiplier_basis_points = other.score_multiplier_basis_points
	tray_bonus_capacity = other.tray_bonus_capacity
	tray_bonus_pairs_remaining = other.tray_bonus_pairs_remaining


func state_hash() -> String:
	var tile_ids: Array = tile_zones.keys()
	tile_ids.sort()
	var zone_parts: Array[String] = []
	var slot_parts: Array[String] = []
	for tile_id in tile_ids:
		zone_parts.append("%s=%s" % [tile_id, tile_zones[tile_id]])
		slot_parts.append("%s=%s" % [tile_id, tile_slot_ids[tile_id]])
	var consumable_keys: Array = consumable_counts.keys()
	consumable_keys.sort()
	var consumable_parts: Array[String] = []
	for consumable_type in consumable_keys:
		consumable_parts.append("%s=%d" % [consumable_type, int(consumable_counts[consumable_type])])

	var canonical_values: Array = [
		revision,
		status,
		",".join(zone_parts),
		",".join(slot_parts),
		",".join(tray_tile_ids),
		",".join(consumable_parts),
		",".join(hinted_tile_ids),
		selection_count,
		resolved_pair_count,
		max_tray_occupancy,
		rng_state,
		momentum_units,
		score,
		elapsed_time_ms,
		last_selection_time_ms,
		last_pair_time_ms,
		max_multiplier,
		combo_count,
		max_combo,
		combo_expires_at_ms,
		modifier_activation_count,
		extra_life_charges,
		cold_snap_until_ms,
		score_multiplier_until_ms,
		score_multiplier_basis_points,
		tray_bonus_capacity,
		tray_bonus_pairs_remaining,
	]
	var format := "%d|%s|%s|%s|%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d"
	if rules_version >= 9:
		canonical_values.insert(7, ",".join(revealed_flipped_tile_ids))
		format = "%d|%s|%s|%s|%s|%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d"
	var canonical: String = format % canonical_values
	return canonical.sha256_text()


func to_dict() -> Dictionary:
	return {
		"revision": revision,
		"rules_version": rules_version,
		"status": status,
		"tile_zones": tile_zones.duplicate(true),
		"tile_slot_ids": tile_slot_ids.duplicate(true),
		"tray_tile_ids": tray_tile_ids.duplicate(),
		"consumable_counts": consumable_counts.duplicate(true),
		"hinted_tile_ids": hinted_tile_ids.duplicate(),
		"revealed_flipped_tile_ids": revealed_flipped_tile_ids.duplicate(),
		"selection_count": selection_count,
		"resolved_pair_count": resolved_pair_count,
		"max_tray_occupancy": max_tray_occupancy,
		"rng_state": rng_state,
		"momentum_units": momentum_units,
		"score": score,
		"elapsed_time_ms": elapsed_time_ms,
		"last_selection_time_ms": last_selection_time_ms,
		"last_pair_time_ms": last_pair_time_ms,
		"max_multiplier": max_multiplier,
		"combo_count": combo_count,
		"max_combo": max_combo,
		"combo_expires_at_ms": combo_expires_at_ms,
		"modifier_activation_count": modifier_activation_count,
		"extra_life_charges": extra_life_charges,
		"cold_snap_until_ms": cold_snap_until_ms,
		"score_multiplier_until_ms": score_multiplier_until_ms,
		"score_multiplier_basis_points": score_multiplier_basis_points,
		"tray_bonus_capacity": tray_bonus_capacity,
		"tray_bonus_pairs_remaining": tray_bonus_pairs_remaining,
	}
