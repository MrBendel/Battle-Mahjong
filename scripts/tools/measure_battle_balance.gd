extends SceneTree
const Probe := preload("res://scripts/tools/battle_balance_probe.gd")
const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const Factory := preload("res://scripts/simulation/reference_game_factory.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://configuration/battle/balance_scenarios.json"
	var output := args[1] if args.size() > 1 else "res://build/battle-balance.json"
	var scenarios: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not scenarios is Dictionary or not scenarios.has_all(["seeds", "horizon_ms", "tap_intervals_ms", "variants"]):
		push_error("Invalid balance scenario file")
		quit(1)
		return
	var report := {"model": "perfect-information fixed-cadence ordinary taps; not human win rates", "variants": scenarios.variants, "base_definition": Definition.defaults(), "runs": []}
	for seed_value in scenarios.seeds:
		var generated: Dictionary = Factory.new().create_generated(int(seed_value))
		for variant in scenarios.variants:
			var tuning := Probe.tuning_for(report.base_definition, variant.overrides)
			tuning.seed = int(seed_value)
			for cadence in scenarios.tap_intervals_ms:
				var result := Probe.run(tuning, generated, int(cadence), int(scenarios.horizon_ms))
				result["variant"] = variant.id
				report.runs.append(result)
				var file := FileAccess.open(output, FileAccess.WRITE)
				if file == null:
					push_error("Cannot write report: " + output)
					quit(1)
					return
				file.store_string(JSON.stringify(report, "\t") + "\n")
				file.close()
				if result.has("error"):
					push_error(str(result))
					quit(1)
					return
				print("%s seed=%d tap=%dms winner=%s time=%.1fs sent=%s cancelled=%s applied=%s" % [variant.id, seed_value, cadence, result.winner, result.duration_ms / 1000.0, str(result.sent_pairs), str(result.cancelled_pairs), str(result.applied_pairs)])
	quit()
