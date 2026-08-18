extends RefCounted

const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const ReferenceGameFactoryScript := preload("res://scripts/simulation/reference_game_factory.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")

const PAIR_AWARE := "pair_aware"
const BOUNDED_ATTENTION := "bounded_attention"
const RANDOM := "random"

const DEFAULT_ATTENTION_LIMIT := 10

func run(seed: int, policy: String = PAIR_AWARE, policy_config: Dictionary = {}) -> Dictionary:
	var game = GameStateScript.new(ReferenceGameFactoryScript.new().call("create_board", seed))
	var policy_rng = DeterministicRngScript.new(seed + 104729)
	var effective_policy_config := policy_config.duplicate()
	var attention_limit := maxi(1, int(policy_config.get("attention_limit", DEFAULT_ATTENTION_LIMIT)))
	if policy == BOUNDED_ATTENTION:
		effective_policy_config["attention_limit"] = attention_limit

	while game.status == GameStateScript.PLAYING:
		var tile: Variant
		match policy:
			RANDOM:
				tile = _choose_random_tile(game, policy_rng)
			BOUNDED_ATTENTION:
				tile = _choose_bounded_attention_tile(game, policy_rng, attention_limit)
			_:
				tile = _choose_pair_aware_tile(game)

		if tile == null:
			break

		game.call("select_tile", tile.id)

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
	}


func _choose_bounded_attention_tile(game: Variant, rng: Variant, attention_limit: int) -> Variant:
	var selectable: Array = game.board.call("selectable_tiles")
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
	if selectable.is_empty():
		return null

	return selectable[rng.call("range_int", 0, selectable.size() - 1)]


func _sample_tiles(tiles: Array, limit: int, rng: Variant) -> Array:
	var pool := tiles.duplicate()
	var sample: Array = []
	while not pool.is_empty() and sample.size() < limit:
		var index: int = rng.call("range_int", 0, pool.size() - 1)
		sample.append(pool.pop_at(index))
	return sample


func _reveal_score(game: Variant, candidate: Variant, selectable_ids: Dictionary) -> int:
	candidate.removed = true
	var after: Array = game.board.call("selectable_tiles")
	candidate.removed = false

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
