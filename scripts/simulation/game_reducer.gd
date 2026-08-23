extends RefCounted

const GameChangeScript := preload("res://scripts/simulation/game_change.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const ModifierRulesScript := preload("res://scripts/simulation/modifier_rules.gd")
const ConsumableInventoryScript := preload("res://scripts/simulation/consumable_inventory.gd")
const COUNTERS := [
	"selection_count",
	"resolved_pair_count",
	"max_tray_occupancy",
	"momentum_units",
	"score",
	"elapsed_time_ms",
	"last_selection_time_ms",
	"last_pair_time_ms",
	"max_multiplier",
	"combo_count",
	"max_combo",
	"combo_expires_at_ms",
	"modifier_activation_count",
	"extra_life_charges",
	"cold_snap_until_ms",
	"score_multiplier_until_ms",
	"score_multiplier_basis_points",
	"tray_bonus_capacity",
	"tray_bonus_pairs_remaining",
]


func apply_forward(definition: Variant, state: Variant, transaction: Variant) -> Variant:
	if transaction.definition_hash != definition.definition_hash():
		return null
	if transaction.revision != state.revision + 1:
		return null
	if not transaction.previous_state_hash.is_empty() and transaction.previous_state_hash != state.state_hash():
		return null

	var candidate: Variant = state.duplicate_data()
	for change in transaction.changes:
		if not _apply_change(candidate, change, false):
			return null

	candidate.revision = transaction.revision
	if not _is_valid(definition, candidate):
		return null
	if not transaction.next_state_hash.is_empty() and transaction.next_state_hash != candidate.state_hash():
		return null
	return candidate


func apply_reverse(definition: Variant, state: Variant, transaction: Variant) -> Variant:
	if transaction.definition_hash != definition.definition_hash():
		return null
	if state.revision != transaction.revision:
		return null
	if not transaction.next_state_hash.is_empty() and transaction.next_state_hash != state.state_hash():
		return null

	var candidate: Variant = state.duplicate_data()
	for index in range(transaction.changes.size() - 1, -1, -1):
		if not _apply_change(candidate, transaction.changes[index], true):
			return null

	candidate.revision = transaction.revision - 1
	if not _is_valid(definition, candidate):
		return null
	if not transaction.previous_state_hash.is_empty() and transaction.previous_state_hash != candidate.state_hash():
		return null
	return candidate


func _apply_change(state: Variant, change: Variant, reverse: bool) -> bool:
	var expected: Variant = change.after if reverse else change.before
	var replacement: Variant = change.before if reverse else change.after
	match change.type:
		GameChangeScript.TILE_ZONE:
			if state.tile_zones.get(change.target) != expected:
				return false
			state.tile_zones[change.target] = replacement
		GameChangeScript.TRAY:
			if state.tray_tile_ids != expected:
				return false
			state.tray_tile_ids.assign(replacement)
		GameChangeScript.COUNTER:
			if change.target not in COUNTERS:
				return false
			if state.get(change.target) != expected:
				return false
			state.set(change.target, replacement)
		GameChangeScript.STATUS:
			if state.status != expected:
				return false
			state.status = replacement
		GameChangeScript.RNG_STATE:
			if state.rng_state != expected:
				return false
			state.rng_state = replacement
		GameChangeScript.TILE_SLOT:
			if state.tile_slot_ids.get(change.target) != expected:
				return false
			state.tile_slot_ids[change.target] = replacement
		GameChangeScript.CONSUMABLES:
			if state.consumable_counts != expected:
				return false
			state.consumable_counts = replacement.duplicate(true)
		GameChangeScript.HINT:
			if state.hinted_tile_ids != expected:
				return false
			state.hinted_tile_ids.assign(replacement)
		GameChangeScript.FLIPPED_REVEALS:
			if state.revealed_flipped_tile_ids != expected:
				return false
			state.revealed_flipped_tile_ids.assign(replacement)
		_:
			return false
	return true


func _is_valid(definition: Variant, state: Variant) -> bool:
	if state.rules_version != definition.rules_version:
		return false
	if state.status not in [GameStateDataScript.PLAYING, GameStateDataScript.WON, GameStateDataScript.LOST]:
		return false
	if state.selection_count < 0 or state.resolved_pair_count < 0 or state.max_tray_occupancy < 0:
		return false
	if state.momentum_units < 0 or state.momentum_units > int(definition.configuration.momentum_max):
		return false
	if state.score < 0 or state.elapsed_time_ms < 0 or state.max_multiplier < 1:
		return false
	if state.combo_count < 0 or state.max_combo < state.combo_count or state.combo_expires_at_ms < 0:
		return false
	if state.combo_count == 0 and state.combo_expires_at_ms != 0:
		return false
	if state.modifier_activation_count < 0 or state.extra_life_charges < 0:
		return false
	if state.cold_snap_until_ms < 0 or state.score_multiplier_until_ms < 0:
		return false
	if state.score_multiplier_basis_points < ModifierRulesScript.BASIS_POINTS_ONE:
		return false
	if state.tray_bonus_capacity < 0 or state.tray_bonus_pairs_remaining < 0:
		return false
	if (state.tray_bonus_capacity == 0) != (state.tray_bonus_pairs_remaining == 0):
		return false
	if state.max_multiplier > definition.configuration.momentum_thresholds.size():
		return false
	if state.last_selection_time_ms > state.elapsed_time_ms or state.last_pair_time_ms > state.elapsed_time_ms:
		return false
	if state.consumable_counts.keys().size() != ConsumableInventoryScript.TYPES.size():
		return false
	for consumable_type in ConsumableInventoryScript.TYPES:
		if not state.consumable_counts.has(consumable_type) or int(state.consumable_counts[consumable_type]) < 0:
			return false
	var effective_tray_capacity: int = ModifierRulesScript.effective_tray_capacity(definition, state)
	if state.tray_tile_ids.size() > effective_tray_capacity:
		return false
	if state.max_tray_occupancy < state.tray_tile_ids.size():
		return false

	var tray_ids := {}
	for tile_id in state.tray_tile_ids:
		if tray_ids.has(tile_id) or state.tile_zones.get(tile_id) != GameStateDataScript.ZONE_TRAY:
			return false
		tray_ids[tile_id] = true

	var board_count := 0
	var resolved_count := 0
	var slot_ids := {}
	for tile in definition.tiles:
		var zone: Variant = state.tile_zones.get(tile.id)
		if zone not in [GameStateDataScript.ZONE_BOARD, GameStateDataScript.ZONE_TRAY, GameStateDataScript.ZONE_RESOLVED]:
			return false
		if (zone == GameStateDataScript.ZONE_TRAY) != tray_ids.has(tile.id):
			return false
		if zone == GameStateDataScript.ZONE_BOARD:
			board_count += 1
		elif zone == GameStateDataScript.ZONE_RESOLVED:
			resolved_count += 1
		var slot_id: String = str(state.tile_slot_ids.get(tile.id, ""))
		if definition.get_tile(slot_id) == null or slot_ids.has(slot_id):
			return false
		slot_ids[slot_id] = true

	if state.tile_zones.size() != definition.tiles.size() or state.tile_slot_ids.size() != definition.tiles.size():
		return false
	for hinted_tile_id in state.hinted_tile_ids:
		if definition.get_tile(hinted_tile_id) == null:
			return false
	var revealed_ids := {}
	for tile_id in state.revealed_flipped_tile_ids:
		if tile_id not in definition.flipped_tile_ids or revealed_ids.has(tile_id):
			return false
		revealed_ids[tile_id] = true
	if resolved_count != state.resolved_pair_count * 2:
		return false
	if state.selection_count != resolved_count + state.tray_tile_ids.size():
		return false
	if state.status == GameStateDataScript.WON and (board_count != 0 or not state.tray_tile_ids.is_empty()):
		return false
	if state.status == GameStateDataScript.LOST and state.tray_tile_ids.size() != effective_tray_capacity:
		return false
	return true
