extends RefCounted

const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const ReferenceGameFactoryScript := preload("res://scripts/simulation/reference_game_factory.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")

const PAIR_AWARE := "pair_aware"
const BOUNDED_ATTENTION := "bounded_attention"
const RANDOM := "random"

const DEFAULT_ATTENTION_LIMIT := 10
const DEFAULT_SELECTION_INTERVALS := {
	PAIR_AWARE: 450,
	BOUNDED_ATTENTION: 800,
	RANDOM: 1100,
}

func run(seed: int, policy: String = PAIR_AWARE, policy_config: Dictionary = {}) -> Dictionary:
	var factory := ReferenceGameFactoryScript.new()
	var flipped_tile_count := maxi(0, int(policy_config.get("flipped_tile_count", 0)))
	var generated: Dictionary = factory.call(
		"create_generated",
		seed,
		4,
		{"flipped_tile_count": flipped_tile_count}
	)
	var definition: Variant = generated.definition
	var game = GameStateScript.new(definition)
	var perfect_solution: Array[String] = []
	var solution_index := 0
	var analyzed_pair_count := 0
	var total_pair_difficulty := 0
	var hardest_pair_difficulty := 0
	var difficulty_reward_count := 0
	var difficulty_bonus_score := 0
	var difficulty_reward_tiers := {"notable": 0, "exceptional": 0}
	if policy == PAIR_AWARE:
		perfect_solution.assign(generated.solution)
	var policy_rng = DeterministicRngScript.new(seed + 104729)
	var effective_policy_config := policy_config.duplicate()
	var attention_limit := maxi(1, int(policy_config.get("attention_limit", DEFAULT_ATTENTION_LIMIT)))
	var selection_interval_ms := maxi(0, int(policy_config.get(
		"selection_interval_ms",
		DEFAULT_SELECTION_INTERVALS.get(policy, 800)
	)))
	effective_policy_config["selection_interval_ms"] = selection_interval_ms
	if policy == BOUNDED_ATTENTION:
		effective_policy_config["attention_limit"] = attention_limit

	while game.status == GameStateScript.PLAYING:
		var tile: Variant = _revealed_flipped_tray_match_tile(game)
		if tile == null:
			match policy:
				RANDOM:
					tile = _choose_random_tile(game, policy_rng)
				BOUNDED_ATTENTION:
					tile = _choose_bounded_attention_tile(game, policy_rng, attention_limit)
				_:
					if solution_index < perfect_solution.size():
						tile = game.board.call("get_tile", perfect_solution[solution_index])
						solution_index += 1

		if tile == null:
			break

		var next_time: int = game.elapsed_time_ms + selection_interval_ms
		var selection_result: String = game.call("tap_tile", tile.id, next_time)
		if selection_result in [GameStateScript.PAIR_RESOLVED, GameStateScript.FLIPPED_PAIR_RESOLVED]:
			var transaction: Variant = game.call("last_transaction")
			var pair_opportunity: Dictionary = transaction.telemetry.get("resolved_pair_opportunity", {})
			if pair_opportunity.has("score"):
				var difficulty: int = int(pair_opportunity.score)
				analyzed_pair_count += 1
				total_pair_difficulty += difficulty
				hardest_pair_difficulty = maxi(hardest_pair_difficulty, difficulty)
			var difficulty_reward: Dictionary = transaction.telemetry.get("difficulty_reward", {})
			if not difficulty_reward.is_empty():
				difficulty_reward_count += 1
				difficulty_bonus_score += int(difficulty_reward.get("bonus_score", 0))
				var tier := str(difficulty_reward.get("tier", ""))
				if difficulty_reward_tiers.has(tier):
					difficulty_reward_tiers[tier] += 1

	return {
		"seed": seed,
		"policy": policy,
		"policy_config": effective_policy_config,
		"status": game.status,
		"selections": game.selection_count,
		"pairs": game.tray.resolved_pair_count,
		"max_tray": game.max_tray_occupancy,
		"board_remaining": game.board.call("active_tiles").size(),
		"tray_remaining": game.tray.tiles.size(),
		"score": game.score,
		"momentum": game.call("momentum_at", game.elapsed_time_ms),
		"multiplier": game.call("multiplier_at", game.elapsed_time_ms),
		"max_multiplier": game.max_multiplier,
		"max_combo": game.max_combo,
		"analyzed_pair_count": analyzed_pair_count,
		"average_pair_difficulty": 0 if analyzed_pair_count == 0 else int(total_pair_difficulty / analyzed_pair_count),
		"hardest_pair_difficulty": hardest_pair_difficulty,
		"difficulty_reward_count": difficulty_reward_count,
		"difficulty_bonus_score": difficulty_bonus_score,
		"difficulty_reward_tiers": difficulty_reward_tiers,
		"elapsed_time_ms": game.elapsed_time_ms,
	}


func _revealed_flipped_tray_match_tile(game: Variant) -> Variant:
	for tile_id in game.definition.flipped_tile_ids:
		if (game.board.call("is_tile_revealable", tile_id) \
				or game.board.call("is_tile_revealed_flipped", tile_id)) \
				and not game.call("flipped_match_candidate", tile_id).is_empty():
			return game.board.call("get_tile", tile_id)
	return null


func _choose_bounded_attention_tile(game: Variant, rng: Variant, attention_limit: int) -> Variant:
	var selectable: Array = game.board.call("selectable_tiles")
	var revealable: Array = game.board.call("revealable_tiles")
	if not revealable.is_empty():
		return revealable[rng.call("range_int", 0, revealable.size() - 1)]
	var observed := _sample_tiles(selectable, attention_limit, rng)

	for held_tile in game.tray.tiles:
		for tile in observed:
			if tile.face.equals(held_tile.face):
				return tile

	for first_index in range(observed.size()):
		for second_index in range(first_index + 1, observed.size()):
			if observed[first_index].face.equals(observed[second_index].face):
				return observed[first_index]

	var best_tile: Variant = null
	var best_score := -1
	var selectable_ids := {}
	for tile in selectable:
		selectable_ids[tile.id] = true
	for tile in observed:
		var score := _reveal_score(game, tile, selectable_ids)
		if score > best_score:
			best_score = score
			best_tile = tile

	return best_tile


func _choose_pair_aware_tile(game: Variant) -> Variant:
	var selectable: Array = game.board.call("selectable_tiles")

	for held_tile in game.tray.tiles:
		for tile in selectable:
			if tile.position.y == held_tile.position.y \
					and tile.position.z == held_tile.position.z \
					and tile.face.equals(held_tile.face):
				return tile

	for held_tile in game.tray.tiles:
		for tile in selectable:
			if tile.face.equals(held_tile.face):
				return tile

	for first_index in range(selectable.size()):
		for second_index in range(first_index + 1, selectable.size()):
			var first: Variant = selectable[first_index]
			var second: Variant = selectable[second_index]
			if first.position.y == second.position.y \
					and first.position.z == second.position.z \
					and first.face.equals(second.face):
				return first

	for first_index in range(selectable.size()):
		for second_index in range(first_index + 1, selectable.size()):
			if selectable[first_index].face.equals(selectable[second_index].face):
				return selectable[first_index]

	if not selectable.is_empty() and game.tray.tiles.size() < game.tray.capacity - 1:
		return selectable[0]

	return null


func _choose_random_tile(game: Variant, rng: Variant) -> Variant:
	var selectable: Array = game.board.call("selectable_tiles")
	var interactive: Array = selectable.duplicate()
	interactive.append_array(game.board.call("revealable_tiles"))
	if interactive.is_empty():
		return null

	return interactive[rng.call("range_int", 0, interactive.size() - 1)]


func _sample_tiles(tiles: Array, limit: int, rng: Variant) -> Array:
	var pool := tiles.duplicate()
	var sample: Array = []
	while not pool.is_empty() and sample.size() < limit:
		var index: int = rng.call("range_int", 0, pool.size() - 1)
		sample.append(pool.pop_at(index))
	return sample


func _reveal_score(game: Variant, candidate: Variant, selectable_ids: Dictionary) -> int:
	var after: Array = game.board.call("selectable_tiles_without", candidate.id)

	var score := 0
	for revealed in after:
		if selectable_ids.has(revealed.id):
			continue

		score += 10
		if revealed.face.equals(candidate.face):
			score += 40
		for held_tile in game.tray.tiles:
			if revealed.face.equals(held_tile.face):
				score += 60

	return score
