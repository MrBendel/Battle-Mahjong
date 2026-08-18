extends SceneTree

const RequirementsScript := preload("res://scripts/simulation/board_layout_requirements.gd")
const ProceduralLayoutGeneratorScript := preload("res://scripts/simulation/procedural_layout_generator.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage: -- <requirements.json> <seed> [output.json]")
		quit(2)
		return

	var requirements: Variant = RequirementsScript.load_file(args[0])
	if requirements == null or not requirements.call("validation_errors").is_empty():
		printerr("Invalid layout requirements: %s" % args[0])
		quit(2)
		return

	var seed := int(args[1])
	var layout: Variant = ProceduralLayoutGeneratorScript.new().call("generate", requirements, seed)
	if layout == null:
		printerr("Could not generate a solvable layout")
		quit(1)
		return

	var serialized := JSON.stringify(layout.to_dict(), "  ")
	if args.size() >= 3:
		var file := FileAccess.open(args[2], FileAccess.WRITE)
		if file == null:
			printerr("Could not write layout: %s" % args[2])
			quit(1)
			return
		file.store_string(serialized + "\n")
		printerr("Wrote %s" % args[2])
	else:
		print(serialized)

	printerr("layout=%s revision=%d slots=%d hash=%s" % [
		layout.id,
		layout.revision,
		layout.slots.size(),
		layout.content_hash(),
	])
	quit()
