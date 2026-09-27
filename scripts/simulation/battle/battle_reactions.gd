extends RefCounted
## Read-only semantic projection of committed transactions. No RNG or state writes.
## Thresholds describe presentation opportunities, not gameplay rules.
static func project(transaction: Dictionary, tuning: Dictionary) -> Array:
	var result: Array = []
	var before: Dictionary = transaction.before
	var after: Dictionary = transaction.after
	if transaction.command.type == "bind_board":
		result.append("battle_started")
	for event in transaction.get("events", []):
		match event.type:
			"attack_sent":
				if event.attack.pair_count >= tuning.big_attack_pairs:
					result.append(event.attack.source + "_big_attack")
				elif event.attack.source == "cpu":
					result.append("cpu_attack")
			"attack_cancelled":
				# The event side is the defender; name the cancelled attack's owner.
				result.append(("cpu" if event.side == "player" else "player") + "_attack_cancelled")
			"cpu_pressure_applied", "attack_inserted":
				if event.pair_count >= tuning.hard_hit_pairs:
					result.append(("cpu" if event.type == "cpu_pressure_applied" else "player") + "_hit_hard")
	for side in ["player", "cpu"]:
		var previous: Dictionary = before.sides[side]
		var current: Dictionary = after.sides[side]
		if previous.streak < tuning.long_streak and current.streak >= tuning.long_streak:
			result.append(side + "_long_streak")
		if previous.remaining_pairs > tuning.near_win_pairs and current.remaining_pairs > 0 and current.remaining_pairs <= tuning.near_win_pairs:
			result.append(side + "_near_win")
		var opponent := "cpu" if side == "player" else "player"
		# A comeback means overtaking after trailing, not simply gaining progress.
		if _progress(before, side) < _progress(before, opponent) and _progress(after, side) > _progress(after, opponent):
			result.append(side + "_comeback")
	if before.status == "playing" and after.status != "playing" and not after.winner.is_empty():
		result.append(after.winner + "_win")
	return result

static func _progress(state: Dictionary, side: String) -> float:
	var work: Dictionary = state.sides[side]
	return float(work.cleared_pairs) / maxi(1, work.cleared_pairs + work.remaining_pairs)
