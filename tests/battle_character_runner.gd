extends SceneTree
const View := preload("res://scripts/presentation/battle_character_view.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var view := View.new()
	view.character = preload("res://configuration/battle/rivet.tres")
	view.gameplay_theme = preload("res://configuration/default_gameplay_theme.tres")
	root.add_child(view)
	view.size = Vector2(280, 80)
	check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE, "character never captures gameplay taps")
	check(view.reaction_texture() != null, "portrait loads")
	check(view.reaction_texture().get_image().detect_alpha() != Image.ALPHA_NONE, "sprite retains genuine alpha")
	view.consume([{"type": "character_reaction", "cue": "battle_started", "revision": 1}])
	check(view.active_cue == "battle_started", "start reaction shown")
	view.consume([{"type": "character_reaction", "cue": "cpu_big_attack", "revision": 2}])
	check(view.active_cue == "cpu_big_attack", "higher priority interrupts")
	view.consume([{"type": "character_reaction", "cue": "player_long_streak", "revision": 3}])
	check(view.active_cue == "cpu_big_attack", "cooldown drops low urgency")
	view.suspended = true
	view._process(3)
	check(view.age == 0, "pause freezes reaction")
	view.suspended = false
	view._process(3)
	check(view.active_cue.is_empty(), "reaction disappears without gameplay callback")
	view.consume([{"type": "character_reaction", "cue": "cpu_big_attack", "revision": 4}])
	check(view.active_cue.is_empty(), "cooldown remains after disappearance")
	view.consume([{"type": "character_reaction", "cue": "player_win", "revision": 5}])
	check(view.active_cue == "player_win", "result overrides cooldown")
	check(view.reaction_texture() != view._portrait, "loss uses frustrated expression")
	view._process(1)
	view.consume([{"type": "character_reaction", "cue": "player_win", "revision": 5}])
	check(view.age == 1, "same committed revision not repeated")
	view.reset()
	check(view.active_cue.is_empty() and view.cooldown == 0, "restart clears cooldown and cue")
	view.consume([{"type": "character_reaction", "cue": "unknown", "revision": 1}])
	check(view.active_cue.is_empty(), "unsupported cue ignored")
	view._frustrated = null
	view.consume([{"type": "character_reaction", "cue": "player_win", "revision": 2}])
	check(view.reaction_texture() == view._portrait, "missing expression falls back per piece")
	view.queue_free()
	await process_frame
	print("Battle character failures: %d" % failures)
	quit(failures)
