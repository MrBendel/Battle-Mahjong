extends RefCounted
## Perfect-information, fixed-cadence player over the actual bound Battle host.
## This measures mechanical pressure, not human skill or recognition time.
const Host := preload("res://scripts/simulation/battle/battle_host.gd")
const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")

static func tuning_for(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides:
		if overrides[key] is Dictionary and result.get(key) is Dictionary:
			for field in overrides[key]:
				result[key][field] = int(overrides[key][field])
		else:
			result[key] = int(overrides[key])
	return result

static func run(tuning: Dictionary, generated: Dictionary, tap_ms: int, horizon_ms: int) -> Dictionary:
	var errors := Definition.validation_errors(tuning)
	if not errors.is_empty() or tap_ms < 1 or horizon_ms < 1:
		return {"error": "invalid_probe_configuration", "details": errors}
	var host := Host.new(tuning, generated.definition, generated.solution)
	if host.store == null: return {"error": "board_binding_failed"}
	var route: Array = generated.solution.duplicate()
	var result := {"seed": tuning.seed, "tap_interval_ms": tap_ms, "winner": "", "duration_ms": 0,
		"sent_pairs": {"player": 0, "cpu": 0}, "cancelled_pairs": {"player": 0, "cpu": 0},
		"applied_pairs": {"player": 0, "cpu": 0}, "first_attack_ms": {"player": -1, "cpu": -1},
		"placements": {"top": 0, "under": 0}, "max_layer": 0, "deferred_attacks": [],
		"overflow": false, "player_pairs_cleared_after_first_hit": 0, "player_cleared_pairs": 0,
		"cpu_cleared_pairs": 0, "peak_unresolved_tiles": generated.definition.tiles.size()}
	var first_hit_cleared := -1
	var next_tap := tap_ms
	var now := 0
	var state: Dictionary = host.store.snapshot()
	while state.status == "playing" and now < horizon_ms:
		var deadline := host.next_event_ms()
		now = mini(next_tap, deadline) if deadline >= 0 else next_tap
		now = mini(now, horizon_ms)
		var advanced := host.advance_to(now)
		if not advanced.accepted: return {"error": advanced, "at_ms": now}
		var events: Array = advanced.events
		state = host.store.snapshot()
		if not state.player_board.route.is_empty(): route = state.player_board.route.duplicate()
		if now == next_tap and state.status == "playing":
			while not route.is_empty() and state.player_board.state.tile_zones.get(route[0]) != "board":
				route.pop_front()
			if route.is_empty(): return {"error": "route_exhausted", "at_ms": now}
			var tapped := host.tap(route[0], now)
			if not tapped.accepted: return {"error": tapped, "at_ms": now}
			events.append_array(tapped.events)
			state = host.store.snapshot()
			next_tap += tap_ms
		for event in events:
			match event.type:
				"attack_sent":
					var side: String = event.attack.source
					result.sent_pairs[side] += event.attack.pair_count
					if result.first_attack_ms[side] < 0: result.first_attack_ms[side] = event.at_ms
				"attack_cancelled":
					result.cancelled_pairs[event.side] += event.pair_count
				"cpu_pressure_applied":
					result.applied_pairs.cpu += event.pair_count
				"attack_inserted":
					result.applied_pairs.player += event.pair_count
					if first_hit_cleared < 0: first_hit_cleared = state.sides.player.cleared_pairs
					for placement in event.placements: result.placements[placement.kind] += 1
				"attack_insertion_deferred":
					if event.attack_id not in result.deferred_attacks: result.deferred_attacks.append(event.attack_id)
				"board_overflow": result.overflow = true
		result.peak_unresolved_tiles = maxi(result.peak_unresolved_tiles, state.sides.player.remaining_pairs * 2)
		for tile in state.player_board.definition.tiles:
			if state.player_board.state.tile_zones[tile.tile_id] == "board":
				result.max_layer = maxi(result.max_layer, tile.position.z)
	result.winner = state.winner if state.status != "playing" else "timeout"
	result.duration_ms = now
	result.player_cleared_pairs = state.sides.player.cleared_pairs
	result.cpu_cleared_pairs = state.sides.cpu.cleared_pairs
	if first_hit_cleared >= 0: result.player_pairs_cleared_after_first_hit = state.sides.player.cleared_pairs - first_hit_cleared
	return result
