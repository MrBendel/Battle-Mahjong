extends SceneTree
const Fx := preload("res://scripts/presentation/battle_attack_fx.gd")
const Hud := preload("res://scripts/presentation/battle_hud.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var hud := Hud.new()
	hud.gameplay_theme = preload("res://configuration/default_gameplay_theme.tres")
	root.add_child(hud)
	hud.size = Vector2(360, 128)
	var fx := Fx.new()
	fx.gameplay_theme = hud.gameplay_theme
	fx.hud = hud
	fx.sound_enabled = false
	root.add_child(fx)
	var attack := {"id": "attack_1", "source": "cpu", "target": "player", "pair_count": 3,
		"created_at_ms": 0, "lands_at_ms": 1000, "tile_pairs": [{"id": "a"}, {"id": "b"}, {"id": "c"}]}
	var events := [{"type": "attack_sent", "attack": attack}]
	var original := events.duplicate(true)
	fx.consume(events)
	check(fx.packets.size() == 1, "send creates visible packet")
	fx.consume([{"type": "attack_cancelled", "attack_id": "attack_1", "pair_count": 2}])
	check(fx.packets.attack_1.pair_count == 1 and fx.packets.attack_1.tile_pairs == [{"id": "c"}], "partial cancellation preserves exact survivors")
	check(events == original, "presentation never mutates committed event")
	fx.suspended = true
	fx._process(1.0)
	check(fx.cues[0].age == 0, "pause freezes feedback")
	fx.suspended = false
	fx.consume([{"type": "attack_landed", "attack": attack}, {"type": "cpu_pressure_applied", "pair_count": 1}])
	check(fx.packets.is_empty(), "landing removes travel marker")
	fx._process(2.0)
	check(fx.cues.is_empty(), "feedback expires")
	fx.consume(events)
	fx.consume([{"type": "attack_cancelled", "attack_id": "attack_1", "pair_count": 3}])
	check(fx.packets.is_empty(), "full cancellation removes packet")
	fx.clear()
	check(fx.cues.is_empty(), "restart clears effects")
	fx.queue_free()
	hud.queue_free()
	await process_frame
	print("Battle FX failures: %d" % failures)
	quit(failures)
