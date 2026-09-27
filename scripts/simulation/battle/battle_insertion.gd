extends RefCounted

const Definition := preload("res://scripts/simulation/game_definition.gd")
const Data := preload("res://scripts/simulation/game_state_data.gd")
const Board := preload("res://scripts/simulation/board_state.gd")
const Selectability := preload("res://scripts/simulation/board_selectability.gd")
const Solver := preload("res://scripts/simulation/game_solver.gd")
const Rng := preload("res://scripts/simulation/deterministic_rng.gd")
const RANGES := {"top_chance_bp": [0, 10000], "max_layer": [0, 16], "max_tiles": [2, 512],
	"attempts": [1, 64], "solver_nodes": [1, 100000]}
var _nodes := 0
var _limit := 0
var _seen := {}
var _blockers := {}

static func validation_errors(tuning: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in RANGES:
		if not tuning.get(key) is int or tuning[key] < RANGES[key][0] or tuning[key] > RANGES[key][1]:
			errors.append("Invalid insertion tuning: %s" % key)
	for key in tuning:
		if not RANGES.has(key):
			errors.append("Unknown insertion tuning: %s" % key)
	return errors

static func restore(data: Dictionary) -> RefCounted:
	var state := Data.new()
	for key in state.to_dict():
		if state.get(key) is Array:
			state.get(key).assign(data[key])
		else:
			state.set(key, data[key].duplicate(true) if data[key] is Dictionary else data[key])
	return state

static func overlaps(a: Dictionary, b: Dictionary) -> bool:
	return abs(int(a.x) - int(b.x)) < 2 and abs(int(a.y) - int(b.y)) < 2

static func active_slots(definition: Dictionary, state: Dictionary) -> Array:
	var occupied := {}
	for id in state.tile_zones:
		if state.tile_zones[id] == "board":
			occupied[state.tile_slot_ids[id]] = true
	var slots: Array = []
	for tile in definition.tiles:
		if occupied.has(tile.tile_id):
			slots.append(tile)
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.tile_id < b.tile_id)
	return slots

## Existing floating tiles are legal after Mahjong removals. New and lifted
## tiles must have direct support; all active same-layer footprints stay disjoint.
static func geometry_valid(slots: Array, changed: Array, max_layer: int) -> bool:
	for i in slots.size():
		var tile: Dictionary = slots[i]
		var p: Dictionary = tile.position
		if p.z < 0 or p.z > max_layer:
			return false
		var supported: bool = p.z == 0
		for j in slots.size():
			if i == j:
				continue
			var other: Dictionary = slots[j].position
			if overlaps(p, other):
				if p.z == other.z:
					return false
				if other.z == p.z - 1:
					supported = true
		if tile.tile_id in changed and not supported:
			return false
	return true

func plan(board: Dictionary, attack: Dictionary, tuning: Dictionary) -> Dictionary:
	var initial_slots := active_slots(board.definition, board.state)
	if initial_slots.size() + board.state.tray_tile_ids.size() + attack.pair_count * 2 > tuning.max_tiles:
		return {"status": "overflow", "reason": "tile_limit"}
	var rng := Rng.new(board.rng_state)
	for attempt in tuning.attempts:
		var definition: Dictionary = board.definition.duplicate(true)
		var state: Dictionary = board.state.duplicate(true)
		var placements: Array = []
		var used := {}
		var failed := false
		for pair in attack.tile_pairs:
			for tile in pair.tiles:
				if state.tile_zones.has(tile.id):
					return {"status": "invalid", "reason": "duplicate_attack_tile"}
				var slots := active_slots(definition, state)
				var preferred := "top" if rng.range_int(0, 9999) < tuning.top_chance_bp else "under"
				var options := _options(slots, tile, preferred, tuning.max_layer)
				if options.is_empty():
					options = _options(slots, tile, "under" if preferred == "top" else "top", tuning.max_layer)
				if options.is_empty():
					# Only an empty initial candidate set proves geometric overflow.
					if placements.is_empty():
						return {"status": "overflow", "reason": "no_supported_position"}
					failed = true
					break
				var fresh: Array = options.filter(func(option: Dictionary) -> bool: return not used.has(option.column))
				if not fresh.is_empty():
					options = fresh
				var chosen: Dictionary = options[rng.range_int(0, options.size() - 1)]
				used[chosen.column] = true
				for existing in definition.tiles:
					if chosen.shifted.has(existing.tile_id):
						existing.position.z += 1
				definition.tiles.append(chosen.tile)
				state.tile_zones[tile.id] = "board"
				state.tile_slot_ids[tile.id] = tile.id
				placements.append(chosen)
			if failed:
				break
		if failed:
			continue
		var candidate := Definition.from_dict(definition)
		var data := restore(state)
		var route := find_route(candidate, data, tuning.solver_nodes)
		if route.is_empty() or not Solver.new().verify_state_route(candidate, data, route).valid:
			continue
		state.revision += 1
		state.hinted_tile_ids = []
		return {"status": "inserted", "definition": definition, "state": state,
			"rng_state": rng.get_state(), "placements": placements, "route": route}
	return {"status": "unverified", "reason": "search_budget"}

func _options(slots: Array, tile: Dictionary, kind: String, max_layer: int) -> Array:
	var options: Array = []
	for anchor in slots:
		var position: Dictionary = anchor.position.duplicate()
		var shifted: Array = []
		if kind == "top":
			position.z += 1
		else:
			shifted.append(anchor.tile_id)
			# Lift the complete overlapping upper closure, not just one column.
			var expanded := true
			while expanded:
				expanded = false
				for lower in slots:
					if lower.tile_id not in shifted:
						continue
					for upper in slots:
						if upper.tile_id not in shifted and upper.position.z > lower.position.z and overlaps(upper.position, lower.position):
							shifted.append(upper.tile_id)
							expanded = true
		var added := {"tile_id": tile.id, "face_family": tile.face_family, "face_value": tile.face_value, "position": position}
		var projected: Array = slots.duplicate(true)
		for existing in projected:
			if existing.tile_id in shifted:
				existing.position.z += 1
		projected.append(added)
		if geometry_valid(projected, shifted + [tile.id], max_layer):
			options.append({"kind": kind, "tile": added, "shifted": shifted,
				"column": "%d,%d" % [position.x, position.y]})
	return options

func find_route(definition: RefCounted, state: RefCounted, node_limit: int) -> Array[String]:
	_nodes = 0
	_limit = node_limit
	_seen.clear()
	var board := Board.new(definition, state)
	var active: Array = board.active_tiles()
	_blockers.clear()
	for tile in active:
		var blockers := {"above": [], "left": [], "right": []}
		for other in active:
			if other == tile:
				continue
			if other.position.z > tile.position.z and other.position.overlaps_footprint(tile.position):
				blockers.above.append(other.id)
			if other.position.is_immediately_left_of(tile.position):
				blockers.left.append(other.id)
			if other.position.is_immediately_right_of(tile.position):
				blockers.right.append(other.id)
		_blockers[tile.id] = blockers
	var held: Array = []
	for id in state.tray_tile_ids:
		held.append(definition.get_tile(id))
	var route: Array[String] = []
	_search(active, held, route)
	return route

func _search(active: Array, held: Array, route: Array[String]) -> bool:
	_nodes += 1
	if _nodes > _limit:
		return false
	if active.is_empty():
		return held.is_empty()
	var key: String = str(active.map(func(t: Variant) -> String: return t.id)) + str(held.map(func(t: Variant) -> String: return t.id))
	if _seen.has(key):
		return false
	_seen[key] = true
	var ids := {}
	for tile in active:
		ids[tile.id] = true
	var available: Array = active.filter(func(t: Variant) -> bool:
		var b: Dictionary = _blockers[t.id]
		return not b.above.any(func(id: String) -> bool: return ids.has(id)) and not (
			b.left.any(func(id: String) -> bool: return ids.has(id)) and b.right.any(func(id: String) -> bool: return ids.has(id))))
	for tile in available:
		for mate in held:
			if tile.face.equals(mate.face):
				var rest := active.duplicate()
				rest.erase(tile)
				var tray := held.duplicate()
				tray.erase(mate)
				route.append(tile.id)
				if _search(rest, tray, route):
					return true
				route.pop_back()
	for i in available.size():
		for j in range(i + 1, available.size()):
			if not available[i].face.equals(available[j].face):
				continue
			var rest := active.duplicate()
			rest.erase(available[i])
			rest.erase(available[j])
			route.append(available[i].id)
			route.append(available[j].id)
			if _search(rest, held, route):
				return true
			route.resize(route.size() - 2)
	return false
