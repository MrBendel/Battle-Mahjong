extends RefCounted

const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const BoardOpportunityAnalysisScript := preload("res://scripts/simulation/board_opportunity_analysis.gd")
const GameChangeScript := preload("res://scripts/simulation/game_change.gd")
const GameCommandScript := preload("res://scripts/simulation/game_command.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const GameTransactionScript := preload("res://scripts/simulation/game_transaction.gd")
const ComboRulesScript := preload("res://scripts/simulation/combo_rules.gd")
const MomentumRulesScript := preload("res://scripts/simulation/momentum_rules.gd")
const PairDifficultyRewardsScript := preload("res://scripts/simulation/pair_difficulty_rewards.gd")
const ModifierLoadoutScript := preload("res://scripts/simulation/modifier_loadout.gd")
const ModifierRulesScript := preload("res://scripts/simulation/modifier_rules.gd")
const ConsumableInventoryScript := preload("res://scripts/simulation/consumable_inventory.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")
const TrayAwareShufflePlannerScript := preload("res://scripts/simulation/tray_aware_shuffle_planner.gd")

const SELECTED := "selected"
const PAIR_RESOLVED := "pair_resolved"
const TILE_REVEALED := "tile_revealed"
const FLIPPED_PAIR_RESOLVED := "flipped_pair_resolved"
const INVALID_SELECTION := "invalid_selection"
const GAME_OVER := "game_over"
const EXTRA_LIFE_USED := "extra_life_used"
const UNDONE := "undone"
const NOTHING_TO_UNDO := "nothing_to_undo"
const HINTED := "hinted"
const NO_HINT_AVAILABLE := "no_hint_available"
const PAIR_DELETED := "pair_deleted"
const NO_DELETABLE_PAIR := "no_deletable_pair"
const SHUFFLED := "shuffled"
const CONSUMABLE_UNAVAILABLE := "consumable_unavailable"
const COMBO_BROKEN := "combo_broken"
const STALE_COMMAND := "stale_command"
const STALE_TIME := "stale_time"
const UNKNOWN_COMMAND := "unknown_command"


func build_transaction(command: Variant, definition: Variant, state: Variant, timeline: Array) -> Dictionary:
	if command.expected_revision != state.revision:
		return {"result": STALE_COMMAND}
	if command.playback_time_ms < state.elapsed_time_ms:
		return {"result": STALE_TIME}

	match command.type:
		GameCommandScript.SELECT_TILE:
			return _build_select(command, definition, state, timeline)
		GameCommandScript.REVEAL_TILE:
			return _build_reveal(command, definition, state)
		GameCommandScript.UNDO:
			return _build_undo(command, definition, state, timeline)
		GameCommandScript.HINT:
			return _build_hint(command, definition, state)
		GameCommandScript.DELETE_PAIR:
			return _build_delete_pair(command, definition, state)
		GameCommandScript.SHUFFLE:
			return _build_shuffle(command, definition, state)
		GameCommandScript.BREAK_COMBO:
			return _build_break_combo(command, definition, state)
		_:
			return {"result": UNKNOWN_COMMAND}


func can_undo(state: Variant, timeline: Array) -> bool:
	if state.status != GameStateDataScript.PLAYING \
			or state.tray_tile_ids.is_empty() \
			or _consumable_count(state, ConsumableInventoryScript.UNDO) <= 0:
		return false
	return _find_selection_transaction(timeline, state.tray_tile_ids[-1]) != null


func _build_select(command: Variant, definition: Variant, state: Variant, timeline: Array) -> Dictionary:
	if state.status != GameStateDataScript.PLAYING:
		return {"result": GAME_OVER}

	var tile_id: String = str(command.payload.get("tile_id", ""))
	var board := BoardStateScript.new(definition, state)
	if not board.call("is_tile_selectable", tile_id):
		return {"result": INVALID_SELECTION}
	var opportunity_analyzer := BoardOpportunityAnalysisScript.new()
	var opportunity_analysis: Dictionary = opportunity_analyzer.call("analyze", definition, state)
	var selected_tile_opportunity: Dictionary = opportunity_analyzer.call(
		"tile_entry",
		opportunity_analysis,
		tile_id
	)
	var selected_pair_options: Array = opportunity_analyzer.call(
		"pair_entries_for_tile",
		opportunity_analysis,
		tile_id
	)

	var changes: Array = []
	var momentum_after_decay := _append_clock_changes(command, definition, state, changes)
	var momentum_after_selection := momentum_after_decay
	if definition.rules_version >= 7:
		momentum_after_selection = MomentumRulesScript.add_selection_gain(
			momentum_after_decay,
			definition.configuration
		)
	_append_counter_change(
		changes,
		"momentum_units",
		momentum_after_decay,
		momentum_after_selection
	)
	_append_clear_hint(changes, state)
	var combo_before: int = ComboRulesScript.count_at(state, command.playback_time_ms)
	var combo_after := combo_before
	var combo_expires_after: int = state.combo_expires_at_ms if combo_before > 0 else 0
	var max_combo_after: int = state.max_combo
	var telemetry := {
		"selection_interval_ms": command.playback_time_ms - state.last_selection_time_ms,
		"momentum_before": state.momentum_units,
		"momentum_after_decay": momentum_after_decay,
		"momentum_after_selection": momentum_after_selection,
		"momentum_selection_gain": momentum_after_selection - momentum_after_decay,
		"opportunity": {
			"board_revision": state.revision,
			"active_tile_count": opportunity_analysis.active_tile_count,
			"selectable_tile_count": opportunity_analysis.selectable_tile_count,
			"available_pair_count": opportunity_analysis.available_pair_count,
			"selected_tile": selected_tile_opportunity,
			"selected_pair_options": selected_pair_options,
		},
	}
	if state.combo_count > 0 and combo_before == 0:
		telemetry["combo_break_reason"] = "timeout"
	if command.playback_time_ms != state.last_selection_time_ms:
		changes.append(GameChangeScript.new(
			GameChangeScript.COUNTER,
			"last_selection_time_ms",
			state.last_selection_time_ms,
			command.playback_time_ms
		))
	var tray_before: Array[String] = []
	tray_before.assign(state.tray_tile_ids)
	var tray_after: Array[String] = []
	tray_after.assign(tray_before)
	var revealed_flipped_mate_id := _matching_revealed_flipped_tile_id(definition, state, tile_id)
	var matching_flipped_tile_id := revealed_flipped_mate_id if definition.rules_version < 11 else ""
	var matching_tile_id := matching_flipped_tile_id
	if matching_tile_id.is_empty():
		matching_tile_id = _matching_tray_tile_id(definition, state, tile_id)
	if revealed_flipped_mate_id.is_empty():
		_append_hide_active_flipped_reveals(changes, state)
	var result := SELECTED
	var selection_count_after: int = state.selection_count + 1
	var extra_life_charges_after: int = state.extra_life_charges
	var cold_snap_until_ms_after: int = state.cold_snap_until_ms
	var score_multiplier_until_ms_after: int = state.score_multiplier_until_ms
	var score_multiplier_basis_points_after: int = state.score_multiplier_basis_points
	var tray_bonus_capacity_after: int = state.tray_bonus_capacity
	var tray_bonus_pairs_remaining_after: int = state.tray_bonus_pairs_remaining
	var modifier_activation_count_after: int = state.modifier_activation_count
	var momentum_after_command := momentum_after_selection
	var triggered_modifiers: Array = []

	if matching_tile_id.is_empty():
		tray_after.append(tile_id)
		var active_capacity: int = ModifierRulesScript.effective_tray_capacity(definition, state)
		if tray_after.size() == active_capacity and state.extra_life_charges > 0:
			for held_tile_id in tray_before:
				changes.append(GameChangeScript.new(
					GameChangeScript.TILE_ZONE,
					held_tile_id,
					GameStateDataScript.ZONE_TRAY,
					GameStateDataScript.ZONE_BOARD
				))
			tray_after.clear()
			extra_life_charges_after -= 1
			selection_count_after = state.selection_count - tray_before.size()
			result = EXTRA_LIFE_USED
			telemetry["extra_life_consumed"] = true
			telemetry["recovered_tile_ids"] = tray_before.duplicate()
		else:
			changes.append(GameChangeScript.new(GameChangeScript.TILE_ZONE, tile_id, GameStateDataScript.ZONE_BOARD, GameStateDataScript.ZONE_TRAY))
	else:
		var matching_zone := GameStateDataScript.ZONE_BOARD
		if matching_flipped_tile_id.is_empty():
			matching_zone = GameStateDataScript.ZONE_TRAY
			tray_after.erase(matching_tile_id)
		else:
			selection_count_after = state.selection_count + 2
		changes.append(GameChangeScript.new(GameChangeScript.TILE_ZONE, tile_id, GameStateDataScript.ZONE_BOARD, GameStateDataScript.ZONE_RESOLVED))
		changes.append(GameChangeScript.new(GameChangeScript.TILE_ZONE, matching_tile_id, matching_zone, GameStateDataScript.ZONE_RESOLVED))
		changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "resolved_pair_count", state.resolved_pair_count, state.resolved_pair_count + 1))
		var score_multiplier: int = MomentumRulesScript.multiplier_for(momentum_after_decay, definition.configuration)
		var momentum_after_gain: int = MomentumRulesScript.add_pair_gain(momentum_after_selection, definition.configuration)
		changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "momentum_units", momentum_after_selection, momentum_after_gain))
		momentum_after_command = momentum_after_gain
		var resulting_multiplier: int = MomentumRulesScript.multiplier_for(momentum_after_gain, definition.configuration)
		var score_modifier_basis_points := ModifierRulesScript.active_score_basis_points(state, command.playback_time_ms)
		var resolved_pair_opportunity := {}
		if not matching_flipped_tile_id.is_empty():
			resolved_pair_opportunity = {
				"source": "flipped_pair",
				"observed_revision": state.revision,
				"revealed_tile_id": matching_flipped_tile_id,
				"selected_tile_id": tile_id,
			}
		else:
			resolved_pair_opportunity = _find_recorded_pair_opportunity(
				timeline,
				matching_tile_id,
				tile_id
			)
		if resolved_pair_opportunity.is_empty():
			resolved_pair_opportunity = {
				"source": "tray_completion",
				"observed_revision": state.revision,
				"held_tile_id": matching_tile_id,
				"selected_tile": selected_tile_opportunity,
			}
		var difficulty_reward: Dictionary = PairDifficultyRewardsScript.evaluate(
			resolved_pair_opportunity,
			definition.configuration
		)
		var score_gain_before_difficulty := int(
			int(definition.configuration.pair_base_score) * score_multiplier * score_modifier_basis_points \
			/ ModifierRulesScript.BASIS_POINTS_ONE
		)
		var difficulty_bonus_score := PairDifficultyRewardsScript.bonus_for(
			score_gain_before_difficulty,
			difficulty_reward
		)
		var score_gain: int = score_gain_before_difficulty + difficulty_bonus_score
		changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "score", state.score, state.score + score_gain))
		combo_after = combo_before + 1
		combo_expires_after = 0
		if definition.rules_version < 8:
			combo_expires_after = ComboRulesScript.expiry_after_pair(
				command.playback_time_ms,
				definition.configuration
			)
		max_combo_after = maxi(state.max_combo, combo_after)
		if command.playback_time_ms != state.last_pair_time_ms:
			changes.append(GameChangeScript.new(
				GameChangeScript.COUNTER,
				"last_pair_time_ms",
				state.last_pair_time_ms,
				command.playback_time_ms
			))
		telemetry.merge({
			"pair_interval_ms": command.playback_time_ms - state.last_pair_time_ms,
			"momentum_after_gain": momentum_after_gain,
			"score_multiplier": score_multiplier,
			"score_modifier_basis_points": score_modifier_basis_points,
			"resulting_multiplier": resulting_multiplier,
			"score_gain": score_gain,
			"score_gain_before_difficulty": score_gain_before_difficulty,
			"difficulty_bonus_score": difficulty_bonus_score,
			"combo_before": combo_before,
			"combo_after": combo_after,
			"combo_expires_at_ms": combo_expires_after,
		})
		telemetry["resolved_pair_opportunity"] = resolved_pair_opportunity
		if not matching_flipped_tile_id.is_empty():
			telemetry["flipped_pair"] = true
			telemetry["resolved_tile_ids"] = [matching_flipped_tile_id, tile_id]
		if not difficulty_reward.is_empty():
			difficulty_reward["bonus_score"] = difficulty_bonus_score
			telemetry["difficulty_reward"] = difficulty_reward
		if tray_bonus_pairs_remaining_after > 0:
			tray_bonus_pairs_remaining_after -= 1
			if tray_bonus_pairs_remaining_after == 0:
				tray_bonus_capacity_after = 0

		var resolved_tile_ids := [tile_id, matching_tile_id]
		resolved_tile_ids.sort()
		for resolved_tile_id in resolved_tile_ids:
			var modifier: Dictionary = definition.modifier_for_tile(resolved_tile_id)
			if modifier.is_empty():
				continue
			var effect: Dictionary = ModifierRulesScript.effect_for(modifier, definition.configuration)
			var trigger := modifier.duplicate(true)
			trigger["tile_id"] = resolved_tile_id
			trigger["effect"] = effect.duplicate(true)
			triggered_modifiers.append(trigger)
			match str(modifier.type):
				ModifierLoadoutScript.EXTRA_LIFE:
					extra_life_charges_after += int(effect.charges)
				ModifierLoadoutScript.COLD_SNAP:
					cold_snap_until_ms_after = maxi(
						cold_snap_until_ms_after,
						command.playback_time_ms
					) + int(effect.duration_ms)
				ModifierLoadoutScript.SCORE_MULTIPLIER:
					score_multiplier_basis_points_after = int(effect.basis_points)
					score_multiplier_until_ms_after = maxi(
						score_multiplier_until_ms_after,
						command.playback_time_ms
					) + int(effect.duration_ms)
				ModifierLoadoutScript.TRAY_PLUS_ONE:
					tray_bonus_capacity_after = 1
					tray_bonus_pairs_remaining_after = int(effect.pair_duration)
		modifier_activation_count_after += triggered_modifiers.size()
		if not triggered_modifiers.is_empty():
			telemetry["modifiers_triggered"] = triggered_modifiers
		result = FLIPPED_PAIR_RESOLVED if not matching_flipped_tile_id.is_empty() else PAIR_RESOLVED

	changes.append(GameChangeScript.new(GameChangeScript.TRAY, "tray_tile_ids", tray_before, tray_after))
	_append_counter_change(changes, "selection_count", state.selection_count, selection_count_after)
	_append_counter_change(changes, "extra_life_charges", state.extra_life_charges, extra_life_charges_after)
	_append_counter_change(changes, "cold_snap_until_ms", state.cold_snap_until_ms, cold_snap_until_ms_after)
	_append_counter_change(changes, "score_multiplier_until_ms", state.score_multiplier_until_ms, score_multiplier_until_ms_after)
	_append_counter_change(changes, "score_multiplier_basis_points", state.score_multiplier_basis_points, score_multiplier_basis_points_after)
	_append_counter_change(changes, "tray_bonus_capacity", state.tray_bonus_capacity, tray_bonus_capacity_after)
	_append_counter_change(changes, "tray_bonus_pairs_remaining", state.tray_bonus_pairs_remaining, tray_bonus_pairs_remaining_after)
	_append_counter_change(changes, "modifier_activation_count", state.modifier_activation_count, modifier_activation_count_after)
	_append_combo_state(changes, state, combo_after, max_combo_after, combo_expires_after)
	var resulting_momentum_multiplier := MomentumRulesScript.multiplier_for(
		momentum_after_command,
		definition.configuration
	)
	if resulting_momentum_multiplier > state.max_multiplier:
		changes.append(GameChangeScript.new(
			GameChangeScript.COUNTER,
			"max_multiplier",
			state.max_multiplier,
			resulting_momentum_multiplier
		))
	var next_peak := maxi(state.max_tray_occupancy, tray_after.size())
	if next_peak != state.max_tray_occupancy:
		changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "max_tray_occupancy", state.max_tray_occupancy, next_peak))

	var next_status: String = state.status
	var effective_capacity_after: int = definition.tray_capacity() + tray_bonus_capacity_after
	if tray_after.size() == effective_capacity_after:
		next_status = GameStateDataScript.LOST
		result = GAME_OVER
	elif _board_tile_count_after(state, changes) == 0 and tray_after.is_empty():
		next_status = GameStateDataScript.WON
	if next_status != state.status:
		changes.append(GameChangeScript.new(GameChangeScript.STATUS, "status", state.status, next_status))
	_append_newly_uncovered_flipped_reveals(definition, state, changes, telemetry)

	var transaction := GameTransactionScript.new(command, changes, result)
	transaction.definition_hash = definition.definition_hash()
	transaction.telemetry = telemetry
	return {"result": result, "transaction": transaction}


func _build_reveal(command: Variant, definition: Variant, state: Variant) -> Dictionary:
	if state.status != GameStateDataScript.PLAYING:
		return {"result": GAME_OVER}

	var tile_id: String = str(command.payload.get("tile_id", ""))
	var board := BoardStateScript.new(definition, state)
	var matching_tray_tile_id := _matching_tray_tile_id(definition, state, tile_id)
	var resolving_revealed_tile: bool = definition.rules_version >= 11 \
		and board.call("is_tile_revealed_flipped", tile_id) \
		and not matching_tray_tile_id.is_empty()
	if not board.call("is_tile_revealable", tile_id) and not resolving_revealed_tile:
		return {"result": INVALID_SELECTION}

	var changes: Array = []
	var momentum_after_decay := _append_clock_changes(command, definition, state, changes)
	_append_clear_hint(changes, state)
	var matching_tile_id := matching_tray_tile_id
	var matching_zone := GameStateDataScript.ZONE_TRAY
	if matching_tile_id.is_empty() and definition.rules_version < 10:
		matching_tile_id = _matching_revealed_flipped_tile_id(definition, state, tile_id)
		matching_zone = GameStateDataScript.ZONE_BOARD
	var revealed_after: Array[String] = []
	if matching_zone == GameStateDataScript.ZONE_BOARD and not matching_tile_id.is_empty():
		revealed_after.assign(state.revealed_flipped_tile_ids)
	else:
		revealed_after = _reveals_without_active_tiles(state)
	revealed_after.append(tile_id)
	revealed_after.sort()
	changes.append(GameChangeScript.new(
		GameChangeScript.FLIPPED_REVEALS,
		"revealed_flipped_tile_ids",
		state.revealed_flipped_tile_ids,
		revealed_after
	))
	if matching_tile_id.is_empty():
		var reveal_transaction := GameTransactionScript.new(command, changes, TILE_REVEALED)
		reveal_transaction.definition_hash = definition.definition_hash()
		reveal_transaction.telemetry = {
			"revealed_tile_id": tile_id,
			"face_id": definition.get_tile(tile_id).face.logical_id(),
		}
		return {"result": TILE_REVEALED, "transaction": reveal_transaction}

	var tray_before: Array[String] = []
	tray_before.assign(state.tray_tile_ids)
	var tray_after: Array[String] = []
	tray_after.assign(tray_before)
	var selection_increment := 2
	if matching_zone == GameStateDataScript.ZONE_TRAY:
		tray_after.erase(matching_tile_id)
		selection_increment = 1
	changes.append(GameChangeScript.new(
		GameChangeScript.TILE_ZONE,
		tile_id,
		GameStateDataScript.ZONE_BOARD,
		GameStateDataScript.ZONE_RESOLVED
	))
	changes.append(GameChangeScript.new(
		GameChangeScript.TILE_ZONE,
		matching_tile_id,
		matching_zone,
		GameStateDataScript.ZONE_RESOLVED
	))
	if tray_before != tray_after:
		changes.append(GameChangeScript.new(GameChangeScript.TRAY, "tray_tile_ids", tray_before, tray_after))
	changes.append(GameChangeScript.new(
		GameChangeScript.COUNTER,
		"resolved_pair_count",
		state.resolved_pair_count,
		state.resolved_pair_count + 1
	))
	changes.append(GameChangeScript.new(
		GameChangeScript.COUNTER,
		"selection_count",
		state.selection_count,
		state.selection_count + selection_increment
	))

	var momentum_after_gain: int = MomentumRulesScript.add_pair_gain(momentum_after_decay, definition.configuration)
	_append_counter_change(changes, "momentum_units", momentum_after_decay, momentum_after_gain)
	var score_multiplier: int = MomentumRulesScript.multiplier_for(momentum_after_decay, definition.configuration)
	var score_modifier_basis_points: int = ModifierRulesScript.active_score_basis_points(state, command.playback_time_ms)
	var score_gain: int = int(
		int(definition.configuration.pair_base_score) * score_multiplier * score_modifier_basis_points \
		/ ModifierRulesScript.BASIS_POINTS_ONE
	)
	_append_counter_change(changes, "score", state.score, state.score + score_gain)
	var combo_before: int = ComboRulesScript.count_at(state, command.playback_time_ms)
	var combo_after := combo_before + 1
	var combo_expires_after := 0
	if definition.rules_version < 8:
		combo_expires_after = ComboRulesScript.expiry_after_pair(command.playback_time_ms, definition.configuration)
	_append_combo_state(changes, state, combo_after, maxi(state.max_combo, combo_after), combo_expires_after)
	_append_counter_change(changes, "last_pair_time_ms", state.last_pair_time_ms, command.playback_time_ms)
	var resulting_multiplier: int = MomentumRulesScript.multiplier_for(momentum_after_gain, definition.configuration)
	_append_counter_change(changes, "max_multiplier", state.max_multiplier, maxi(state.max_multiplier, resulting_multiplier))

	var pair_ids := [tile_id, matching_tile_id]
	var modifier_values := _modifier_values_after_pair(definition, state, pair_ids, command.playback_time_ms)
	var tray_bonus_pairs_after: int = int(modifier_values.tray_bonus_pairs_remaining)
	var tray_bonus_capacity_after: int = int(modifier_values.tray_bonus_capacity)
	if tray_bonus_pairs_after > 0 and not bool(modifier_values.tray_bonus_triggered):
		tray_bonus_pairs_after -= 1
		if tray_bonus_pairs_after == 0:
			tray_bonus_capacity_after = 0
	_append_counter_change(changes, "extra_life_charges", state.extra_life_charges, int(modifier_values.extra_life_charges))
	_append_counter_change(changes, "cold_snap_until_ms", state.cold_snap_until_ms, int(modifier_values.cold_snap_until_ms))
	_append_counter_change(changes, "score_multiplier_until_ms", state.score_multiplier_until_ms, int(modifier_values.score_multiplier_until_ms))
	_append_counter_change(changes, "score_multiplier_basis_points", state.score_multiplier_basis_points, int(modifier_values.score_multiplier_basis_points))
	_append_counter_change(changes, "tray_bonus_capacity", state.tray_bonus_capacity, tray_bonus_capacity_after)
	_append_counter_change(changes, "tray_bonus_pairs_remaining", state.tray_bonus_pairs_remaining, tray_bonus_pairs_after)
	_append_counter_change(changes, "modifier_activation_count", state.modifier_activation_count, int(modifier_values.modifier_activation_count))

	var next_status: String = state.status
	if _board_tile_count_after(state, changes) == 0 and tray_after.is_empty():
		next_status = GameStateDataScript.WON
	if next_status != state.status:
		changes.append(GameChangeScript.new(GameChangeScript.STATUS, "status", state.status, next_status))

	var telemetry := {
		"flipped_pair": true,
		"revealed_tile_id": tile_id,
		"resolved_tile_ids": pair_ids,
		"matching_source": matching_zone,
		"pair_interval_ms": command.playback_time_ms - state.last_pair_time_ms,
		"momentum_before": state.momentum_units,
		"momentum_after_decay": momentum_after_decay,
		"momentum_after_gain": momentum_after_gain,
		"score_multiplier": score_multiplier,
		"score_modifier_basis_points": score_modifier_basis_points,
		"resulting_multiplier": resulting_multiplier,
		"score_gain": score_gain,
		"score_gain_before_difficulty": score_gain,
		"difficulty_bonus_score": 0,
		"combo_before": combo_before,
		"combo_after": combo_after,
		"combo_expires_at_ms": combo_expires_after,
		"resolved_pair_opportunity": {
			"source": "flipped_pair",
			"observed_revision": state.revision,
			"revealed_tile_id": tile_id,
			"matching_tile_id": matching_tile_id,
		},
		"modifiers_triggered": modifier_values.triggered_modifiers,
	}
	_append_newly_uncovered_flipped_reveals(definition, state, changes, telemetry)
	var transaction := GameTransactionScript.new(command, changes, FLIPPED_PAIR_RESOLVED)
	transaction.definition_hash = definition.definition_hash()
	transaction.telemetry = telemetry
	return {"result": FLIPPED_PAIR_RESOLVED, "transaction": transaction}


func _build_undo(command: Variant, definition: Variant, state: Variant, timeline: Array) -> Dictionary:
	if _consumable_count(state, ConsumableInventoryScript.UNDO) <= 0:
		return {"result": CONSUMABLE_UNAVAILABLE}
	if state.status != GameStateDataScript.PLAYING or state.tray_tile_ids.is_empty():
		return {"result": NOTHING_TO_UNDO}

	var tile_id: String = state.tray_tile_ids[-1]
	var target_transaction: Variant = _find_selection_transaction(timeline, tile_id)
	if target_transaction == null:
		return {"result": NOTHING_TO_UNDO}

	var tray_before: Array[String] = []
	tray_before.assign(state.tray_tile_ids)
	var tray_after: Array[String] = []
	tray_after.assign(tray_before)
	tray_after.pop_back()
	var changes: Array = []
	var momentum_after_decay := _append_clock_changes(command, definition, state, changes)
	_append_clear_hint(changes, state)
	_append_consumable_use(changes, state, ConsumableInventoryScript.UNDO)
	var combo_telemetry := _append_combo_reset(changes, state, command.playback_time_ms, "undo")
	var selection_gain := int(target_transaction.telemetry.get("momentum_selection_gain", 0))
	var momentum_after_undo := MomentumRulesScript.remove_selection_gain(momentum_after_decay, selection_gain)
	_append_counter_change(changes, "momentum_units", momentum_after_decay, momentum_after_undo)
	combo_telemetry["momentum_selection_gain_reverted"] = momentum_after_decay - momentum_after_undo
	changes.append_array([
		GameChangeScript.new(GameChangeScript.TILE_ZONE, tile_id, GameStateDataScript.ZONE_TRAY, GameStateDataScript.ZONE_BOARD),
		GameChangeScript.new(GameChangeScript.TRAY, "tray_tile_ids", tray_before, tray_after),
		GameChangeScript.new(GameChangeScript.COUNTER, "selection_count", state.selection_count, state.selection_count - 1),
	])
	for target_change in target_transaction.changes:
		if target_change.type == GameChangeScript.FLIPPED_REVEALS \
				and state.revealed_flipped_tile_ids == target_change.after:
			changes.append(GameChangeScript.new(
				GameChangeScript.FLIPPED_REVEALS,
				"revealed_flipped_tile_ids",
				state.revealed_flipped_tile_ids,
				target_change.before
			))
			combo_telemetry["restored_flipped_reveals"] = target_change.before.duplicate()
			break
	var transaction := GameTransactionScript.new(command, changes, UNDONE, target_transaction.transaction_id)
	transaction.definition_hash = target_transaction.definition_hash
	transaction.telemetry = combo_telemetry
	return {"result": UNDONE, "transaction": transaction}


func _build_hint(command: Variant, definition: Variant, state: Variant) -> Dictionary:
	if state.status != GameStateDataScript.PLAYING:
		return {"result": GAME_OVER}
	if _consumable_count(state, ConsumableInventoryScript.HINT) <= 0:
		return {"result": CONSUMABLE_UNAVAILABLE}
	var board := BoardStateScript.new(definition, state)
	var selectable: Array = board.call("selectable_tiles")
	selectable.sort_custom(func(first: Variant, second: Variant) -> bool: return first.id < second.id)
	var hinted: Array[String] = []
	var revealed_ids: Array[String] = []
	for revealed_id in state.revealed_flipped_tile_ids:
		if state.tile_zones.get(revealed_id) == GameStateDataScript.ZONE_BOARD:
			revealed_ids.append(revealed_id)
	revealed_ids.sort()
	for revealed_id in revealed_ids:
		var revealed_tile: Variant = definition.get_tile(revealed_id)
		for tile in selectable:
			if tile.face.equals(revealed_tile.face):
				hinted.assign([revealed_id, tile.id])
				break
		if not hinted.is_empty():
			break
	for held_tile_id in state.tray_tile_ids:
		if not hinted.is_empty():
			break
		var held_tile: Variant = definition.get_tile(held_tile_id)
		for tile in selectable:
			if tile.face.equals(held_tile.face):
				hinted.assign([held_tile_id, tile.id])
				break
		if not hinted.is_empty():
			break
	if hinted.is_empty():
		for first_index in range(selectable.size()):
			for second_index in range(first_index + 1, selectable.size()):
				if selectable[first_index].face.equals(selectable[second_index].face):
					hinted.assign([selectable[first_index].id, selectable[second_index].id])
					break
			if not hinted.is_empty():
				break
	if hinted.is_empty():
		return {"result": NO_HINT_AVAILABLE}
	var changes: Array = []
	_append_clock_changes(command, definition, state, changes)
	_append_consumable_use(changes, state, ConsumableInventoryScript.HINT)
	var combo_telemetry := _append_combo_reset(changes, state, command.playback_time_ms, "hint")
	changes.append(GameChangeScript.new(GameChangeScript.HINT, "hinted_tile_ids", state.hinted_tile_ids, hinted))
	var transaction := GameTransactionScript.new(command, changes, HINTED)
	transaction.definition_hash = definition.definition_hash()
	transaction.telemetry = {"hinted_tile_ids": hinted.duplicate()}
	transaction.telemetry.merge(combo_telemetry)
	return {"result": HINTED, "transaction": transaction}


func _build_delete_pair(command: Variant, definition: Variant, state: Variant) -> Dictionary:
	if state.status != GameStateDataScript.PLAYING:
		return {"result": GAME_OVER}
	if _consumable_count(state, ConsumableInventoryScript.DELETE_PAIR) <= 0:
		return {"result": CONSUMABLE_UNAVAILABLE}
	var tile_id: String = str(command.payload.get("tile_id", ""))
	var board := BoardStateScript.new(definition, state)
	if not board.call("is_tile_visible", tile_id) or board.call("is_tile_face_down", tile_id):
		return {"result": NO_DELETABLE_PAIR}
	var tile: Variant = board.call("get_tile", tile_id)
	var visible: Array = board.call("visible_tiles")
	visible.sort_custom(func(first: Variant, second: Variant) -> bool: return first.id < second.id)
	var partner_id := ""
	for candidate in visible:
		if candidate.id != tile_id and not board.call("is_tile_face_down", candidate.id) \
				and candidate.face.equals(tile.face):
			partner_id = candidate.id
			break
	if partner_id.is_empty():
		return {"result": NO_DELETABLE_PAIR}

	var changes: Array = []
	_append_clock_changes(command, definition, state, changes)
	_append_clear_hint(changes, state)
	_append_consumable_use(changes, state, ConsumableInventoryScript.DELETE_PAIR)
	var combo_telemetry := _append_combo_reset(changes, state, command.playback_time_ms, "delete_pair")
	changes.append(GameChangeScript.new(GameChangeScript.TILE_ZONE, tile_id, GameStateDataScript.ZONE_BOARD, GameStateDataScript.ZONE_RESOLVED))
	changes.append(GameChangeScript.new(GameChangeScript.TILE_ZONE, partner_id, GameStateDataScript.ZONE_BOARD, GameStateDataScript.ZONE_RESOLVED))
	changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "resolved_pair_count", state.resolved_pair_count, state.resolved_pair_count + 1))
	changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "selection_count", state.selection_count, state.selection_count + 2))
	var modifier_values := _modifier_values_after_pair(definition, state, [tile_id, partner_id], command.playback_time_ms)
	var tray_bonus_pairs_after: int = int(modifier_values.tray_bonus_pairs_remaining)
	var tray_bonus_capacity_after: int = int(modifier_values.tray_bonus_capacity)
	if tray_bonus_pairs_after > 0 and not bool(modifier_values.tray_bonus_triggered):
		tray_bonus_pairs_after -= 1
		if tray_bonus_pairs_after == 0:
			tray_bonus_capacity_after = 0
	_append_counter_change(changes, "extra_life_charges", state.extra_life_charges, int(modifier_values.extra_life_charges))
	_append_counter_change(changes, "cold_snap_until_ms", state.cold_snap_until_ms, int(modifier_values.cold_snap_until_ms))
	_append_counter_change(changes, "score_multiplier_until_ms", state.score_multiplier_until_ms, int(modifier_values.score_multiplier_until_ms))
	_append_counter_change(changes, "score_multiplier_basis_points", state.score_multiplier_basis_points, int(modifier_values.score_multiplier_basis_points))
	_append_counter_change(changes, "tray_bonus_capacity", state.tray_bonus_capacity, tray_bonus_capacity_after)
	_append_counter_change(changes, "tray_bonus_pairs_remaining", state.tray_bonus_pairs_remaining, tray_bonus_pairs_after)
	_append_counter_change(changes, "modifier_activation_count", state.modifier_activation_count, int(modifier_values.modifier_activation_count))
	if _board_tile_count_after(state, changes) == 0 and state.tray_tile_ids.is_empty():
		changes.append(GameChangeScript.new(GameChangeScript.STATUS, "status", state.status, GameStateDataScript.WON))
	var telemetry := {
		"assisted_pair": true,
		"deleted_tile_ids": [tile_id, partner_id],
		"modifiers_triggered": modifier_values.triggered_modifiers,
	}
	telemetry.merge(combo_telemetry)
	_append_newly_uncovered_flipped_reveals(definition, state, changes, telemetry)
	var transaction := GameTransactionScript.new(command, changes, PAIR_DELETED)
	transaction.definition_hash = definition.definition_hash()
	transaction.telemetry = telemetry
	return {"result": PAIR_DELETED, "transaction": transaction}


func _modifier_values_after_pair(definition: Variant, state: Variant, tile_ids: Array, playback_time_ms: int) -> Dictionary:
	var values := {
		"extra_life_charges": state.extra_life_charges,
		"cold_snap_until_ms": state.cold_snap_until_ms,
		"score_multiplier_until_ms": state.score_multiplier_until_ms,
		"score_multiplier_basis_points": state.score_multiplier_basis_points,
		"tray_bonus_capacity": state.tray_bonus_capacity,
		"tray_bonus_pairs_remaining": state.tray_bonus_pairs_remaining,
		"tray_bonus_triggered": false,
		"modifier_activation_count": state.modifier_activation_count,
		"triggered_modifiers": [],
	}
	tile_ids.sort()
	for resolved_tile_id in tile_ids:
		var modifier: Dictionary = definition.modifier_for_tile(resolved_tile_id)
		if modifier.is_empty():
			continue
		var effect: Dictionary = ModifierRulesScript.effect_for(modifier, definition.configuration)
		var trigger := modifier.duplicate(true)
		trigger["tile_id"] = resolved_tile_id
		trigger["effect"] = effect.duplicate(true)
		values.triggered_modifiers.append(trigger)
		match str(modifier.type):
			ModifierLoadoutScript.EXTRA_LIFE:
				values.extra_life_charges = int(values.extra_life_charges) + int(effect.charges)
			ModifierLoadoutScript.COLD_SNAP:
				values.cold_snap_until_ms = maxi(int(values.cold_snap_until_ms), playback_time_ms) + int(effect.duration_ms)
			ModifierLoadoutScript.SCORE_MULTIPLIER:
				values.score_multiplier_basis_points = int(effect.basis_points)
				values.score_multiplier_until_ms = maxi(int(values.score_multiplier_until_ms), playback_time_ms) + int(effect.duration_ms)
			ModifierLoadoutScript.TRAY_PLUS_ONE:
				values.tray_bonus_capacity = 1
				values.tray_bonus_pairs_remaining = int(effect.pair_duration)
				values.tray_bonus_triggered = true
	values.modifier_activation_count = state.modifier_activation_count + values.triggered_modifiers.size()
	return values


func _build_shuffle(command: Variant, definition: Variant, state: Variant) -> Dictionary:
	if state.status != GameStateDataScript.PLAYING:
		return {"result": GAME_OVER}
	if _consumable_count(state, ConsumableInventoryScript.SHUFFLE) <= 0:
		return {"result": CONSUMABLE_UNAVAILABLE}
	if state.tray_tile_ids.size() >= ModifierRulesScript.effective_tray_capacity(definition, state):
		return {"result": GAME_OVER}
	var plan: Dictionary = TrayAwareShufflePlannerScript.new().call("build_slot_plan", definition, state)
	if plan.is_empty():
		return {"result": NO_HINT_AVAILABLE}
	var available_by_face: Dictionary = {}
	for physical_tile in definition.tiles:
		if state.tile_zones[physical_tile.id] != GameStateDataScript.ZONE_BOARD:
			continue
		var key := _face_key(physical_tile)
		if not available_by_face.has(key):
			available_by_face[key] = []
		available_by_face[key].append(physical_tile.id)
	for key in available_by_face:
		available_by_face[key].sort()

	var mapping_after: Dictionary = state.tile_slot_ids.duplicate(true)
	var route: Array[String] = []
	var tray_slots: Array = plan.tray_slots
	for index in state.tray_tile_ids.size():
		var held_tile: Variant = definition.get_tile(state.tray_tile_ids[index])
		var key := _face_key(held_tile)
		var matching_ids: Array = available_by_face.get(key, [])
		if matching_ids.is_empty():
			return {"result": NO_HINT_AVAILABLE}
		var physical_id: String = str(matching_ids.pop_front())
		mapping_after[physical_id] = str(tray_slots[index])
		route.append(physical_id)

	var groups: Array = []
	for key in available_by_face:
		var ids: Array = available_by_face[key]
		if ids.size() % 2 != 0:
			return {"result": NO_HINT_AVAILABLE}
		for index in range(0, ids.size(), 2):
			groups.append([ids[index], ids[index + 1]])
	var pair_slots: Array = plan.pair_slots
	if groups.size() != pair_slots.size():
		return {"result": NO_HINT_AVAILABLE}
	var rng := DeterministicRngScript.new(state.rng_state)
	rng.call("next_int")
	for index in range(groups.size() - 1, 0, -1):
		var swap_index: int = rng.call("range_int", 0, index)
		var temporary: Variant = groups[index]
		groups[index] = groups[swap_index]
		groups[swap_index] = temporary
	for index in groups.size():
		var group: Array = groups[index]
		var slots: Array = pair_slots[index]
		mapping_after[str(group[0])] = str(slots[0])
		mapping_after[str(group[1])] = str(slots[1])
		route.append(str(group[0]))
		route.append(str(group[1]))

	var candidate: Variant = state.duplicate_data()
	candidate.tile_slot_ids = mapping_after.duplicate(true)
	var solver_script: Script = load("res://scripts/simulation/game_solver.gd")
	var verification: Dictionary = solver_script.new().call("verify_state_route", definition, candidate, route)
	if not bool(verification.get("valid", false)):
		return {"result": NO_HINT_AVAILABLE}
	var changes: Array = []
	_append_clock_changes(command, definition, state, changes)
	_append_clear_hint(changes, state)
	_append_consumable_use(changes, state, ConsumableInventoryScript.SHUFFLE)
	var combo_telemetry := _append_combo_reset(changes, state, command.playback_time_ms, "shuffle")
	for tile_id in mapping_after:
		if state.tile_slot_ids[tile_id] != mapping_after[tile_id]:
			changes.append(GameChangeScript.new(GameChangeScript.TILE_SLOT, tile_id, state.tile_slot_ids[tile_id], mapping_after[tile_id]))
	if rng.call("get_state") != state.rng_state:
		changes.append(GameChangeScript.new(GameChangeScript.RNG_STATE, "rng_state", state.rng_state, rng.call("get_state")))
	var transaction := GameTransactionScript.new(command, changes, SHUFFLED)
	transaction.definition_hash = definition.definition_hash()
	transaction.telemetry = {"tray_tile_count": state.tray_tile_ids.size(), "verified_route_length": route.size()}
	transaction.telemetry.merge(combo_telemetry)
	return {"result": SHUFFLED, "transaction": transaction}


func _build_break_combo(command: Variant, definition: Variant, state: Variant) -> Dictionary:
	if state.status != GameStateDataScript.PLAYING:
		return {"result": GAME_OVER}
	var tile_id: String = str(command.payload.get("tile_id", ""))
	var board := BoardStateScript.new(definition, state)
	if not board.call("is_tile_active", tile_id) or board.call("is_tile_selectable", tile_id):
		return {"result": INVALID_SELECTION}
	var combo_before: int = ComboRulesScript.count_at(state, command.playback_time_ms)
	if combo_before <= 0:
		return {"result": INVALID_SELECTION}

	var changes: Array = []
	_append_clock_changes(command, definition, state, changes)
	_append_combo_state(changes, state, 0, state.max_combo, 0)
	var transaction := GameTransactionScript.new(command, changes, COMBO_BROKEN)
	transaction.definition_hash = definition.definition_hash()
	transaction.telemetry = {
		"combo_before": combo_before,
		"combo_after": 0,
		"combo_break_reason": "locked_tile_tap",
		"tile_id": tile_id,
	}
	return {"result": COMBO_BROKEN, "transaction": transaction}


func _face_key(tile: Variant) -> String:
	return "%s\u001f%s" % [tile.face.family, tile.face.value]


func _append_clear_hint(changes: Array, state: Variant) -> void:
	if not state.hinted_tile_ids.is_empty():
		changes.append(GameChangeScript.new(GameChangeScript.HINT, "hinted_tile_ids", state.hinted_tile_ids, []))


func _consumable_count(state: Variant, consumable_type: String) -> int:
	return int(state.consumable_counts.get(consumable_type, 0))


func _append_consumable_use(changes: Array, state: Variant, consumable_type: String) -> void:
	var after: Dictionary = state.consumable_counts.duplicate(true)
	after[consumable_type] = int(after[consumable_type]) - 1
	changes.append(GameChangeScript.new(GameChangeScript.CONSUMABLES, "consumable_counts", state.consumable_counts, after))


func _append_combo_reset(changes: Array, state: Variant, playback_time_ms: int, reason: String) -> Dictionary:
	var combo_before: int = ComboRulesScript.count_at(state, playback_time_ms)
	_append_combo_state(changes, state, 0, state.max_combo, 0)
	return {
		"combo_before": combo_before,
		"combo_after": 0,
		"combo_break_reason": reason,
	}


func _append_clock_changes(command: Variant, definition: Variant, state: Variant, changes: Array) -> int:
	var elapsed_ms: int = ModifierRulesScript.momentum_decay_elapsed_ms(state, command.playback_time_ms)
	var momentum_after_decay: int = MomentumRulesScript.decay(
		state.momentum_units,
		elapsed_ms,
		definition.configuration
	)
	if momentum_after_decay != state.momentum_units:
		changes.append(GameChangeScript.new(
			GameChangeScript.COUNTER,
			"momentum_units",
			state.momentum_units,
			momentum_after_decay
		))
	if command.playback_time_ms != state.elapsed_time_ms:
		changes.append(GameChangeScript.new(
			GameChangeScript.COUNTER,
			"elapsed_time_ms",
			state.elapsed_time_ms,
			command.playback_time_ms
		))
	return momentum_after_decay


func _matching_tray_tile_id(definition: Variant, state: Variant, tile_id: String) -> String:
	var tile: Variant = definition.get_tile(tile_id)
	if tile == null:
		return ""
	for held_tile_id in state.tray_tile_ids:
		if definition.get_tile(held_tile_id).face.equals(tile.face):
			return held_tile_id
	return ""


func _matching_revealed_flipped_tile_id(definition: Variant, state: Variant, tile_id: String) -> String:
	var tile: Variant = definition.get_tile(tile_id)
	if tile == null:
		return ""
	var candidate_ids: Array[String] = []
	for candidate_id in state.revealed_flipped_tile_ids:
		if candidate_id != tile_id \
				and state.tile_zones.get(candidate_id) == GameStateDataScript.ZONE_BOARD:
			candidate_ids.append(candidate_id)
	candidate_ids.sort()
	for candidate_id in candidate_ids:
		var candidate: Variant = definition.get_tile(candidate_id)
		if candidate != null and candidate.face.equals(tile.face):
			return candidate_id
	return ""


func _append_hide_active_flipped_reveals(changes: Array, state: Variant) -> void:
	var revealed_after := _reveals_without_active_tiles(state)
	if revealed_after != state.revealed_flipped_tile_ids:
		changes.append(GameChangeScript.new(
			GameChangeScript.FLIPPED_REVEALS,
			"revealed_flipped_tile_ids",
			state.revealed_flipped_tile_ids,
			revealed_after
		))


func _reveals_without_active_tiles(state: Variant) -> Array[String]:
	var revealed_after: Array[String] = []
	for revealed_id in state.revealed_flipped_tile_ids:
		if state.tile_zones.get(revealed_id) != GameStateDataScript.ZONE_BOARD:
			revealed_after.append(revealed_id)
	return revealed_after


func _append_newly_uncovered_flipped_reveals(
	definition: Variant,
	state: Variant,
	changes: Array,
	telemetry: Dictionary
) -> void:
	if definition.rules_version < 10 or definition.flipped_tile_ids.is_empty():
		return
	var projected: Variant = state.duplicate_data()
	for change in changes:
		match change.type:
			GameChangeScript.TILE_ZONE:
				projected.tile_zones[change.target] = change.after
			GameChangeScript.TILE_SLOT:
				projected.tile_slot_ids[change.target] = change.after
			GameChangeScript.FLIPPED_REVEALS:
				projected.revealed_flipped_tile_ids.assign(change.after)
	var board_before := BoardStateScript.new(definition, state)
	var board_after := BoardStateScript.new(definition, projected)
	var auto_revealed_ids: Array[String] = []
	for revealed_id in projected.revealed_flipped_tile_ids:
		if projected.tile_zones.get(revealed_id) == GameStateDataScript.ZONE_BOARD:
			return
	var flipped_ids: Array[String] = []
	flipped_ids.assign(definition.flipped_tile_ids)
	flipped_ids.sort()
	for flipped_id in flipped_ids:
		if board_before.call("is_tile_accessible", flipped_id) \
				or not board_after.call("is_tile_revealable", flipped_id):
			continue
		auto_revealed_ids.append(flipped_id)
		break
	if auto_revealed_ids.is_empty():
		return
	var reveals_before: Array[String] = []
	reveals_before.assign(projected.revealed_flipped_tile_ids)
	var reveals_after: Array[String] = []
	reveals_after.assign(reveals_before)
	for flipped_id in auto_revealed_ids:
		if flipped_id not in reveals_after:
			reveals_after.append(flipped_id)
	reveals_after.sort()
	changes.append(GameChangeScript.new(
		GameChangeScript.FLIPPED_REVEALS,
		"revealed_flipped_tile_ids",
		reveals_before,
		reveals_after
	))
	telemetry["auto_revealed_tile_ids"] = auto_revealed_ids


func _board_tile_count_after(state: Variant, changes: Array) -> int:
	var count := 0
	for zone in state.tile_zones.values():
		if zone == GameStateDataScript.ZONE_BOARD:
			count += 1
	for change in changes:
		if change.type != GameChangeScript.TILE_ZONE:
			continue
		if change.before == GameStateDataScript.ZONE_BOARD and change.after != GameStateDataScript.ZONE_BOARD:
			count -= 1
		elif change.before != GameStateDataScript.ZONE_BOARD and change.after == GameStateDataScript.ZONE_BOARD:
			count += 1
	return count


func _append_counter_change(changes: Array, target: String, before: int, after: int) -> void:
	if before != after:
		changes.append(GameChangeScript.new(GameChangeScript.COUNTER, target, before, after))


func _append_combo_state(
		changes: Array,
		state: Variant,
		combo_after: int,
		max_combo_after: int,
		combo_expires_after: int
) -> void:
	_append_counter_change(changes, "combo_count", state.combo_count, combo_after)
	_append_counter_change(changes, "max_combo", state.max_combo, max_combo_after)
	_append_counter_change(changes, "combo_expires_at_ms", state.combo_expires_at_ms, combo_expires_after)


func _find_selection_transaction(timeline: Array, tile_id: String) -> Variant:
	for index in range(timeline.size() - 1, -1, -1):
		var transaction: Variant = timeline[index]
		if _resolves_pair(transaction):
			return null
		if transaction.command_type != GameCommandScript.SELECT_TILE:
			continue
		for change in transaction.changes:
			if change.type == GameChangeScript.TILE_ZONE \
					and change.target == tile_id \
					and change.after == GameStateDataScript.ZONE_TRAY:
				return transaction
	return null


func _find_recorded_pair_opportunity(timeline: Array, first_tile_id: String, second_tile_id: String) -> Dictionary:
	var ids: Array[String] = [first_tile_id, second_tile_id]
	ids.sort()
	var pair_id := "%s|%s" % ids
	for index in range(timeline.size() - 1, -1, -1):
		var transaction: Variant = timeline[index]
		var opportunity: Dictionary = transaction.telemetry.get("opportunity", {})
		var selected_tile: Dictionary = opportunity.get("selected_tile", {})
		if str(selected_tile.get("tile_id", "")) != first_tile_id:
			continue
		for pair_entry in opportunity.get("selected_pair_options", []):
			if str(pair_entry.get("id", "")) != pair_id:
				continue
			var resolved: Dictionary = pair_entry.duplicate(true)
			resolved["source"] = "board_pair"
			resolved["observed_revision"] = int(opportunity.get("board_revision", transaction.revision - 1))
			return resolved
	return {}


func _resolves_pair(transaction: Variant) -> bool:
	for change in transaction.changes:
		if change.type == GameChangeScript.COUNTER \
				and change.target == "resolved_pair_count" \
				and int(change.after) > int(change.before):
			return true
	return false
