extends RefCounted

const Cpu := preload("res://scripts/simulation/battle/battle_cpu.gd")

const Charge := preload("res://scripts/simulation/battle/battle_charge.gd")

const Rng := preload("res://scripts/simulation/deterministic_rng.gd")

const PLAYER := "player"
const CPU := "cpu"
const PLAYING := "playing"
const RESOLVING_ATTACK := "resolving_attack"
const PLAYER_WON := "player_won"
const CPU_WON := "cpu_won"


static func initial(definition: Dictionary) -> Dictionary:
	var state := {
		"revision": 0,
		"status": PLAYING,
		"winner": "",
		"sides": {
			PLAYER: _side(definition.player_starting_pairs),
			CPU: _side(definition.cpu_starting_pairs),
		},
	}
	if definition.rules_version >= 2:
		state["cpu_schedule"] = Cpu.initial(definition)
	if definition.rules_version >= 3:
		state["player_charge"] = Charge.initial()
	if definition.rules_version >= 4:
		state.merge({"attack_time_ms": 0, "attack_sequence": 0, "landed_attacks": []})
	if definition.rules_version >= 5:
		state["payload_rng_state"] = Rng.new(definition.seed).get_state()
	if definition.rules_version >= 6:
		state["player_board"] = {}
	if definition.rules_version >= 7:
		state["cpu_applied_attacks"] = []
	return state


static func _side(pairs: int) -> Dictionary:
	return {
		"cleared_pairs": 0,
		"remaining_pairs": pairs,
		"score": 0,
		"streak": 0,
		"momentum_units": 0,
		"attack_charge_units": 0,
		"pending_attacks": [],
	}


static func progress(state: Dictionary, side: String) -> float:
	var work: Dictionary = state.sides[side]
	return float(work.cleared_pairs) / float(work.cleared_pairs + work.remaining_pairs)


static func race_position(state: Dictionary, side: String) -> float:
	var distance := progress(state, side) * 0.5
	return distance if side == PLAYER else 1.0 - distance
