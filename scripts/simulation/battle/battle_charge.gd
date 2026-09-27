extends RefCounted

const Attacks := preload("res://scripts/simulation/battle/battle_attacks.gd")
const MAX_COUNTER := 1000000000
const RANGES := {
	"normal_pair_units": [0, 1000000],
	"fast_pair_bonus_units": [0, 1000000],
	"fast_pair_window_ms": [0, 60000],
	"layer_clear_bonus_units": [0, 1000000],
	"momentum_bonus_units": [0, 1000000],
	"momentum_bonus_tier": [2, 8],
	"attack_threshold_units": [1, 1000000],
}


static func validation_errors(tuning: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in RANGES:
		if not tuning.get(key) is int or tuning[key] < RANGES[key][0] or tuning[key] > RANGES[key][1]:
			errors.append("Invalid charge tuning: %s" % key)
	for key in tuning:
		if not RANGES.has(key):
			errors.append("Unknown charge tuning: %s" % key)
	return errors


static func initial() -> Dictionary:
	return {"source_hash": "", "source_revision": 0, "last_event_ms": 0,
		"last_match_ms": -1, "cleared_layers": [], "highest_momentum_tier": 1}


static func event_error(event: Dictionary, state: Dictionary) -> String:
	var required := ["source_hash", "source_revision", "at_ms", "pair_count", "natural_pairs",
		"score", "streak", "momentum_units", "momentum_tier", "cleared_layers"]
	if event.size() != required.size():
		return "invalid_player_event"
	for key in required:
		if not event.has(key):
			return "invalid_player_event"
	for key in ["source_revision", "at_ms", "pair_count", "natural_pairs", "score", "streak", "momentum_units", "momentum_tier"]:
		if not event[key] is int or event[key] < 0 or event[key] > MAX_COUNTER:
			return "invalid_player_event"
	if not event.source_hash is String or event.source_hash.is_empty():
		return "invalid_source"
	var tracker: Dictionary = state.player_charge
	if not tracker.source_hash.is_empty() and event.source_hash != tracker.source_hash:
		return "wrong_source"
	if event.source_revision != tracker.source_revision + 1 or event.at_ms < tracker.last_event_ms:
		return "stale_player_event"
	if event.natural_pairs > 1 or event.natural_pairs > event.pair_count or event.pair_count > state.sides.player.remaining_pairs:
		return "invalid_pair_count"
	if event.momentum_tier < 1 or event.momentum_tier > 8:
		return "invalid_momentum_tier"
	if not event.cleared_layers is Array or event.cleared_layers.size() > 1024:
		return "invalid_layers"
	var unique := {}
	for layer in event.cleared_layers:
		if not layer is int or layer < 0 or layer > MAX_COUNTER or unique.has(layer):
			return "invalid_layers"
		unique[layer] = true
	if event.pair_count == 0 and not event.cleared_layers.is_empty():
		return "invalid_layers"
	return ""


## Mutates only the store's uncommitted candidate. Empty error means success.
static func apply(state: Dictionary, event: Dictionary, tuning: Dictionary, attack_tuning: Dictionary = {}, events: Array = [], payload_tuning: Dictionary = {}) -> String:
	var tracker: Dictionary = state.player_charge
	var player: Dictionary = state.sides.player
	var gain := 0
	var new_layers := 0
	for layer in event.cleared_layers:
		if not tracker.cleared_layers.has(layer):
			tracker.cleared_layers.append(layer)
			new_layers += 1
	tracker.cleared_layers.sort()
	if event.natural_pairs == 1:
		gain += int(tuning.normal_pair_units)
		if tracker.last_match_ms >= 0 and event.streak >= 2 \
				and event.at_ms - tracker.last_match_ms <= tuning.fast_pair_window_ms:
			gain += int(tuning.fast_pair_bonus_units)
		gain += new_layers * int(tuning.layer_clear_bonus_units)
		if tracker.highest_momentum_tier < tuning.momentum_bonus_tier and event.momentum_tier >= tuning.momentum_bonus_tier:
			gain += int(tuning.momentum_bonus_units)
		tracker.last_match_ms = event.at_ms
	elif event.streak == 0 or event.pair_count > 0:
		tracker.last_match_ms = -1
	var total: int = player.attack_charge_units + gain
	if total > MAX_COUNTER:
		return "charge_limit"
	@warning_ignore("integer_division")
	var attack_pairs: int = total / int(tuning.attack_threshold_units)
	player.attack_charge_units = total % int(tuning.attack_threshold_units)
	if attack_pairs > 0 and not attack_tuning.is_empty():
		var error := Attacks.send(state, "player", attack_pairs, attack_tuning, events, payload_tuning)
		if not error.is_empty():
			return error
	elif attack_pairs > 0:
		state.sides.cpu.pending_attacks.append({
			"id": "player_attack_%d" % event.source_revision,
			"source": "player", "target": "cpu", "pair_count": attack_pairs,
			"created_at_ms": event.at_ms, "attack_type": "pairs",
		})
	player.remaining_pairs -= event.pair_count
	player.cleared_pairs += event.pair_count
	player.score = event.score
	player.streak = event.streak
	player.momentum_units = event.momentum_units
	tracker.source_hash = event.source_hash
	tracker.source_revision = event.source_revision
	tracker.last_event_ms = event.at_ms
	tracker.highest_momentum_tier = maxi(tracker.highest_momentum_tier, event.momentum_tier)
	if player.remaining_pairs == 0:
		state.status = "player_won"
		state.winner = "player"
	return ""


static func normalized(state: Dictionary, tuning: Dictionary) -> float:
	return float(state.sides.player.attack_charge_units) / float(tuning.attack_threshold_units)
