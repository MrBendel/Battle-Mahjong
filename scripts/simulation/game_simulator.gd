extends RefCounted

const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const ReferenceGameFactoryScript := preload("res://scripts/simulation/reference_game_factory.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")

const PAIR_AWARE := "pair_aware"
const RANDOM := "random"

func run(seed: int, policy: String = PAIR_AWARE) -> Dictionary:
	var game = GameStateScript.new(ReferenceGameFactoryScript.new().call("create_board", seed))
	var policy_rng = DeterministicRngScript.new(seed + 104729)

	while game.status == GameStateScript.PLAYING:
		var tile: Variant
		if policy == RANDOM:
			tile = _choose_random_tile(game, policy_rng)
		else:
			tile = _choose_pair_aware_tile(game)

		if tile == null:
			break

		game.call("select_tile", tile.id)

	return {
		"seed": seed,
		"policy": policy,
		"status": game.status,
		"selections": game.selection_count,
		"pairs": game.tray.resolved_pair_count,
		"max_tray": game.max_tray_occupancy,
		"board_remaining": game.board.call("active_tiles").size(),
		"tray_remaining": game.tray.tiles.size(),
	}


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
