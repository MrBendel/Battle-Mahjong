extends SceneTree

const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const GameSimulatorScript := preload("res://scripts/simulation/game_simulator.gd")

const RUN_COUNT := 100
const BOUNDED_ATTENTION_CONFIG := {"attention_limit": 10}

func _init() -> void:
	var simulator = GameSimulatorScript.new()
	_run_policy(simulator, GameSimulatorScript.PAIR_AWARE)
	_run_policy(simulator, GameSimulatorScript.BOUNDED_ATTENTION, BOUNDED_ATTENTION_CONFIG)
	_run_policy(simulator, GameSimulatorScript.RANDOM)
	quit()


func _run_policy(simulator: Variant, policy: String, policy_config: Dictionary = {}) -> void:
	var wins := 0
	var losses := 0
	var stalled := 0
	var total_pairs := 0
	var total_selections := 0
	var peak_tray := 0
	var tray_peaks := {1: 0, 2: 0, 3: 0, 4: 0}

	for seed in range(1, RUN_COUNT + 1):
		var result: Dictionary = simulator.call("run", seed, policy, policy_config)
		if result.status == GameStateScript.WON:
			wins += 1
		elif result.status == GameStateScript.LOST:
			losses += 1
		else:
			stalled += 1
		total_pairs += result.pairs
		total_selections += result.selections
		peak_tray = maxi(peak_tray, result.max_tray)
		tray_peaks[result.max_tray] = tray_peaks.get(result.max_tray, 0) + 1

	printerr("%s config=%s: runs=%d wins=%d losses=%d stalled=%d avg_pairs=%.2f avg_selections=%.2f peak_tray=%d tray_peaks=%s" % [
		policy,
		str(policy_config),
		RUN_COUNT,
		wins,
		losses,
		stalled,
		float(total_pairs) / RUN_COUNT,
		float(total_selections) / RUN_COUNT,
		peak_tray,
		str(tray_peaks),
	])
