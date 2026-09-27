extends SceneTree
const Reactions := preload("res://scripts/simulation/battle/battle_reactions.gd")
const State := preload("res://scripts/simulation/battle/battle_state.gd")
const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _init() -> void:
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://configuration/battle/reaction_cues.json"))
	var before := State.initial(Definition.defaults())
	var after := before.duplicate(true)
	var transaction := {"before": before, "after": after, "command": {"type": "bind_board"}, "events": []}
	check(Reactions.project(transaction, tuning) == ["battle_started"], "start cue")
	transaction.command.type = "cpu_step"
	check(Reactions.project(transaction, tuning).is_empty(), "idle snapshot emits nothing")
	for side in ["player", "cpu"]:
		transaction.events = [{"type": "attack_sent", "attack": {"source": side, "pair_count": 3}}]
		check(Reactions.project(transaction, tuning) == [side + "_big_attack"], "big attack ownership")
		transaction.events = [{"type": "attack_cancelled", "side": side}]
		check(Reactions.project(transaction, tuning) == [("cpu" if side == "player" else "player") + "_attack_cancelled"], "cancellation names attack owner")
	transaction.events = [{"type": "cpu_pressure_applied", "pair_count": 3}, {"type": "attack_inserted", "pair_count": 3}]
	check(Reactions.project(transaction, tuning) == ["cpu_hit_hard", "player_hit_hard"], "hit hooks require applied workload")
	transaction.events = []
	after.sides.player.streak = 8
	after.sides.player.remaining_pairs = 4
	check(Reactions.project(transaction, tuning).has("player_long_streak"), "streak crossing")
	check(Reactions.project(transaction, tuning).has("player_near_win"), "near win crossing")
	before.sides.player = after.sides.player.duplicate(true)
	check(Reactions.project(transaction, tuning).is_empty(), "standing thresholds do not retrigger")
	before.sides.cpu.cleared_pairs = 12
	after.sides.cpu.cleared_pairs = 12
	after.sides.player.cleared_pairs = 20
	check(Reactions.project(transaction, tuning).has("player_comeback"), "comeback overtakes from behind")
	after.status = "player_won"
	after.winner = "player"
	var original := transaction.duplicate(true)
	check(Reactions.project(transaction, tuning).has("player_win"), "terminal reaction")
	check(transaction == original, "reaction projection leaves replay data untouched")
	print("Battle reaction failures: %d" % failures)
	quit(failures)
