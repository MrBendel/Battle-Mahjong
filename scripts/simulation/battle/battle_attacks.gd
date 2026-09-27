extends RefCounted

const Payload := preload("res://scripts/simulation/battle/battle_payload.gd")
const MAX_TIME_MS := 2147483647

static func validation_errors(tuning: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if tuning.size() != 1 or not tuning.get("delay_ms") is int or tuning.delay_ms < 1 or tuning.delay_ms > 60000:
		errors.append("Attack delay_ms must be an integer from 1 to 60000.")
	return errors

## Due attacks land before actions at the same timestamp. Landing is a handoff
## record only until board insertion and CPU pressure are implemented.
static func advance(state: Dictionary, at_ms: Variant, events: Array) -> String:
	if not at_ms is int or at_ms < state.attack_time_ms or at_ms > MAX_TIME_MS:
		return "invalid_attack_time"
	var due: Array = []
	for side in ["player", "cpu"]:
		var pending: Array = state.sides[side].pending_attacks
		for index in range(pending.size() - 1, -1, -1):
			if pending[index].lands_at_ms <= at_ms:
				due.append(pending[index])
				pending.remove_at(index)
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.lands_at_ms < b.lands_at_ms if a.lands_at_ms != b.lands_at_ms else a.sequence < b.sequence)
	for attack in due:
		state.landed_attacks.append(attack.duplicate(true))
		events.append({"type": "attack_landed", "at_ms": attack.lands_at_ms, "attack": attack.duplicate(true)})
	state.attack_time_ms = at_ms
	return ""

static func send(state: Dictionary, source: String, pairs: int, tuning: Dictionary, events: Array, payload_tuning: Dictionary = {}) -> String:
	if state.attack_time_ms > MAX_TIME_MS - int(tuning.delay_ms):
		return "attack_time_limit"
	var incoming: Array = state.sides[source].pending_attacks
	var remaining := pairs
	while remaining > 0 and not incoming.is_empty():
		var attack: Dictionary = incoming[0]
		var cancelled := mini(remaining, int(attack.pair_count))
		attack.pair_count -= cancelled
		remaining -= cancelled
		var cancellation := {"type": "attack_cancelled", "at_ms": state.attack_time_ms,
			"attack_id": attack.id, "side": source, "pair_count": cancelled}
		if attack.has("tile_pairs"):
			cancellation["tile_pairs"] = attack.tile_pairs.slice(0, cancelled).duplicate(true)
			attack.tile_pairs = attack.tile_pairs.slice(cancelled)
		events.append(cancellation)
		if attack.pair_count == 0:
			incoming.pop_front()
	if remaining > 0:
		if not payload_tuning.is_empty() and remaining > payload_tuning.max_pairs:
			return "payload_limit"
		state.attack_sequence += 1
		var target := "cpu" if source == "player" else "player"
		var attack := {"id": "attack_%d" % state.attack_sequence, "sequence": state.attack_sequence,
			"source": source, "target": target, "pair_count": remaining, "attack_type": "pairs",
			"created_at_ms": state.attack_time_ms, "lands_at_ms": state.attack_time_ms + int(tuning.delay_ms)}
		if not payload_tuning.is_empty():
			attack["tile_pairs"] = Payload.generate(state, attack.id, remaining, payload_tuning)
		state.sides[target].pending_attacks.append(attack)
		events.append({"type": "attack_sent", "at_ms": state.attack_time_ms, "attack": attack.duplicate(true)})
	return ""

static func pending_pairs(state: Dictionary, side: String) -> int:
	var total := 0
	for attack in state.sides[side].pending_attacks:
		total += int(attack.pair_count)
	return total
