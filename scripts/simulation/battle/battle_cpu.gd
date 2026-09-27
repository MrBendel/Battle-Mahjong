extends RefCounted

const Rng := preload("res://scripts/simulation/deterministic_rng.gd")
const BASIS := 10000
const MAX_TIME_MS := 2147483647
const RANGES := {
	"base_interval_ms": [100, 60000],
	"variance_ms": [0, 30000],
	"streak_chance_bp": [0, BASIS],
	"streak_pairs": [1, 100],
	"streak_speed_bp": [BASIS, 40000],
	"pause_chance_bp": [0, BASIS],
	"pause_ms": [100, 60000],
	"recovery_rate_bp": [1000, 40000],
	"difficulty_bp": [1000, 40000],
}


static func validation_errors(tuning: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in RANGES:
		if not tuning.get(key) is int or tuning[key] < RANGES[key][0] or tuning[key] > RANGES[key][1]:
			errors.append("Invalid CPU tuning: %s" % key)
	for key in tuning:
		if not RANGES.has(key):
			errors.append("Unknown CPU tuning: %s" % key)
	if errors.is_empty() and tuning.variance_ms >= tuning.base_interval_ms:
		errors.append("CPU variance must be smaller than base interval.")
	return errors


static func initial(definition: Dictionary) -> Dictionary:
	var rng := Rng.new(definition.seed)
	var schedule := {"rng_state": rng.get_state(), "last_event_ms": 0, "next_event_ms": 0,
		"next_kind": "", "burst_remaining": 0, "event_count": 0, "mode": "normal"}
	_plan(schedule, definition.cpu, rng)
	return schedule


## Called only after the store has validated the exact scheduled timestamp.
static func step(state: Dictionary, tuning: Dictionary) -> void:
	var schedule: Dictionary = state.cpu_schedule
	var cpu: Dictionary = state.sides.cpu
	var rng := Rng.new(schedule.rng_state)
	schedule.last_event_ms = schedule.next_event_ms
	schedule.event_count += 1
	if schedule.next_kind == "pause":
		cpu.streak = 0
		cpu.momentum_units = 0
		schedule.burst_remaining = 0
		schedule.mode = "recovering"
		schedule.next_kind = "solve"
		# A pause always ends in a solve, even at 100% pause probability.
		schedule.next_event_ms += _scaled(_scaled(tuning.pause_ms, tuning.recovery_rate_bp), tuning.difficulty_bp)
	else:
		cpu.remaining_pairs -= 1
		cpu.cleared_pairs += 1
		cpu.streak += 1
		schedule.burst_remaining = maxi(0, schedule.burst_remaining - 1)
		if cpu.remaining_pairs == 0:
			state.status = "cpu_won"
			state.winner = "cpu"
			schedule.next_event_ms = -1
			schedule.next_kind = ""
			schedule.mode = "finished"
		else:
			_plan(schedule, tuning, rng)
	# CPU momentum is a provisional 0..10000 burst indicator, not player score Momentum.
	cpu.momentum_units = BASIS if schedule.mode == "streak" else 0
	schedule.rng_state = rng.get_state()


static func _plan(schedule: Dictionary, tuning: Dictionary, rng: RefCounted) -> void:
	var delay: int = tuning.base_interval_ms + rng.range_int(-tuning.variance_ms, tuning.variance_ms)
	if rng.range_int(0, BASIS - 1) < tuning.pause_chance_bp:
		schedule.next_kind = "pause"
		schedule.mode = "normal"
	else:
		if schedule.burst_remaining == 0 and rng.range_int(0, BASIS - 1) < tuning.streak_chance_bp:
			schedule.burst_remaining = tuning.streak_pairs
		schedule.next_kind = "solve"
		schedule.mode = "streak" if schedule.burst_remaining > 0 else "normal"
		if schedule.burst_remaining > 0:
			delay = _scaled(delay, tuning.streak_speed_bp)
	schedule.next_event_ms = schedule.last_event_ms + _scaled(delay, tuning.difficulty_bp)
	schedule.rng_state = rng.get_state()


static func _scaled(milliseconds: int, speed_bp: int) -> int:
	@warning_ignore("integer_division")
	var scaled := milliseconds * BASIS / speed_bp
	return maxi(1, scaled)
