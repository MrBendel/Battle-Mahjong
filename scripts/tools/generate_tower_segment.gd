extends SceneTree

const TowerGenerationProfileScript := preload("res://scripts/simulation/tower_generation_profile.gd")
const TowerSegmentGeneratorScript := preload("res://scripts/simulation/tower_segment_generator.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage: -- <tower-profile.json> <segment-seed> [output.json]")
		quit(2)
		return

	var profile: Variant = TowerGenerationProfileScript.load_file(args[0])
	if profile == null or not profile.call("validation_errors").is_empty():
		printerr("Invalid Tower generation profile: %s" % args[0])
		quit(2)
		return

	var segment: Dictionary = TowerSegmentGeneratorScript.new().call("generate", profile, int(args[1]))
	if not bool(segment.get("valid", false)):
		printerr("Could not generate Tower segment: %s" % segment.get("reason", "unknown error"))
		quit(1)
		return

	var serialized := JSON.stringify(segment, "  ")
	if args.size() >= 3:
		var file := FileAccess.open(args[2], FileAccess.WRITE)
		if file == null:
			printerr("Could not write Tower segment: %s" % args[2])
			quit(1)
			return
		file.store_string(serialized + "\n")
		printerr("Wrote %s" % args[2])
	else:
		print(serialized)

	var floors: Array = segment.floors
	printerr("segment=%s seed=%d floors=%d difficulty=%d..%d" % [
		segment.segment_id,
		segment.segment_seed,
		floors.size(),
		floors[0].difficulty.difficulty_score,
		floors[-1].difficulty.difficulty_score,
	])
	quit()
