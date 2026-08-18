extends SceneTree

const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const GameSimulatorScript := preload("res://scripts/simulation/game_simulator.gd")

const RUN_COUNT := 100

func _init() -> void:
	var simulator = GameSimulatorScript.new()
	_run_policy(simulator, GameSimulatorScript.PAIR_AWARE)
	_run_policy(simulator, GameSimulatorScript.RANDOM)
	quit()


func _run_policy(simulator: Variant, policy: String) -> void:
	var wins := 0
	var losses := 0
	var stalled := 0
	var total_pairs := 0
	var peak_tray := 0

	for seed in range(1, RUN_COUNT + 1):
		var result: Dictionary = simulator.call("run", seed, policy)
		if result.status == GameStateScript.WON:
			wins += 1
		elif result.status == GameStateScript.LOST:
			losses += 1
		else:
			stalled += 1
		total_pairs += result.pairs
		peak_tray = maxi(peak_tray, result.max_tray)

	printerr("%s: runs=%d wins=%d losses=%d stalled=%d avg_pairs=%.2f peak_tray=%d" % [
		policy,
		RUN_COUNT,
		wins,
		losses,
		stalled,
		float(total_pairs) / RUN_COUNT,
		peak_tray,
	])
