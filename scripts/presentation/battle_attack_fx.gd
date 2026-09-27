extends Control
## Cosmetic observer only. Committed events own delivery, never animation callbacks.
const Scale := preload("res://scripts/presentation/presentation_scale.gd")
@export var cue_seconds := 0.85
@export var swoosh_volume_db := -25.0
@export var impact_volume_db := -23.0
@export var sound_enabled := true
var gameplay_theme: Resource
var hud: Control
var board: Control
var skin: RefCounted
var packets: Dictionary = {}
var cues: Array = []
var active_ms := 0
var suspended := false
var _swoosh: AudioStreamPlayer
var _impact: AudioStreamPlayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_swoosh = _audio(preload("res://game-assets/audio/tile_swoosh.wav"), swoosh_volume_db)
	_impact = _audio(preload("res://game-assets/audio/tile_collision.wav"), impact_volume_db)

func _audio(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player

func clear() -> void:
	packets.clear()
	cues.clear()
	_swoosh.stop()
	_impact.stop()
	queue_redraw()

func consume(events: Array) -> void:
	var sent := false
	var hit := false
	for event in events:
		match event.type:
			"attack_sent":
				packets[event.attack.id] = event.attack.duplicate(true)
				cue("ATTACK!" if event.attack.source == "player" else "INCOMING!", event.attack.source)
				sent = true
			"attack_cancelled":
				if packets.has(event.attack_id):
					packets[event.attack_id].pair_count -= event.pair_count
					packets[event.attack_id].tile_pairs = packets[event.attack_id].tile_pairs.slice(event.pair_count)
					if packets[event.attack_id].pair_count <= 0:
						packets.erase(event.attack_id)
				cue("CANCEL −%d" % event.pair_count, "center")
				hit = true
			"attack_landed":
				packets.erase(event.attack.id)
			"cpu_pressure_applied":
				cue("+%d PAIRS" % event.pair_count, "cpu")
				hit = true
			"attack_inserted":
				cue("+%d PAIRS" % event.pair_count, "board", event.placements)
				hit = true
			"attack_insertion_deferred":
				cue("INSERTION WAITING", "board")
			"board_overflow":
				cue("BOARD FULL", "board")
	if sound_enabled and not suspended:
		if sent: _swoosh.play()
		if hit: _impact.play()
	queue_redraw()

func cue(text: String, target: String, placements: Array = []) -> void:
	cues = cues.filter(func(item: Dictionary) -> bool: return item.target != target)
	cues.append({"text": text, "target": target, "placements": placements, "age": 0.0})
	# Bound catch-up presentation work without changing authoritative events.
	if cues.size() > 12: cues.pop_front()

func _process(delta: float) -> void:
	if suspended:
		_swoosh.stop()
		_impact.stop()
		return
	var had_cues := not cues.is_empty()
	for item in cues: item.age += delta
	cues = cues.filter(func(item: Dictionary) -> bool: return item.age < cue_seconds)
	if had_cues or not packets.is_empty(): queue_redraw()

func _anchor(target: String) -> Vector2:
	if target == "board" and board != null:
		return board.position + Vector2(board.size.x / 2, board.size.y * 0.18)
	return hud.position + hud.race_anchor(target)

func _draw() -> void:
	if hud == null or gameplay_theme == null: return
	var s: float = hud.ui_scale()
	var font: Font = load(gameplay_theme.bold_font_path)
	for packet in packets.values():
		var incoming: bool = packet.target == "player"
		var start := _anchor("cpu" if incoming else "center")
		var end := _anchor("board" if incoming else "cpu")
		var progress := clampf(float(active_ms - packet.created_at_ms) / maxf(1, packet.lands_at_ms - packet.created_at_ms), 0, 1)
		var point := start.lerp(end, progress)
		var color: Color = gameplay_theme.battle_cpu_color if incoming else gameplay_theme.battle_player_color
		draw_line(start, point, Color(color, 0.4), 3 * s, true)
		for offset in [-7, 7]:
			var rect := Rect2(point + Vector2(offset - 9, -13) * s, Vector2(18, 26) * s)
			draw_rect(rect, gameplay_theme.battle_text_color)
			draw_rect(rect, color, false, 2 * s)
		draw_string(font, point + Vector2(-9, 5) * s, str(packet.pair_count), HORIZONTAL_ALIGNMENT_CENTER, 18 * s, maxi(1, roundi(14 * s)), gameplay_theme.battle_panel_color)
	for item in cues:
		var alpha := 1.0 - float(item.age) / cue_seconds
		var point := _anchor(item.target)
		var color: Color = gameplay_theme.battle_player_color if item.target in ["player", "center"] else gameplay_theme.battle_cpu_color
		color.a = alpha
		if item.target == "cpu":
			draw_line(point - Vector2(8, 9) * s, point + Vector2(8, 9) * s, color, 2 * s, true)
			draw_line(point - Vector2(8, -9) * s, point + Vector2(8, -9) * s, color, 2 * s, true)
		else:
			draw_arc(point, (18 + 12 * (1 - alpha)) * s, 0, TAU, 40, color, 2 * s, true)
		# One readable callout lane; never paint over the live race labels.
		if item == cues.back() and board != null:
			var bs := Scale.limiting_scale(board.size, Vector2(360, 400))
			var width := minf(180 * bs, board.size.x)
			var banner := Rect2(board.position + Vector2((board.size.x - width) / 2, 6 * bs), Vector2(width, 26 * bs))
			draw_rect(banner, Color(gameplay_theme.battle_panel_color, alpha * 0.95))
			draw_string(font, banner.position + Vector2(0, 19 * bs), item.text, HORIZONTAL_ALIGNMENT_CENTER, width, maxi(1, roundi(14 * bs)), color)
		if item.text.begins_with("CANCEL"):
			var separation := maxf(0, 1.0 - float(item.age) / (cue_seconds * 0.4)) * 42 * s
			for direction in [-1, 1]:
				var tint: Color = gameplay_theme.battle_player_color if direction == -1 else gameplay_theme.battle_cpu_color
				tint.a = alpha
				draw_rect(Rect2(point + Vector2(direction * separation - 8 * s, -12 * s), Vector2(16, 24) * s), tint)
		if board != null:
			for placement in item.placements:
				var rect: Rect2 = board.tile_global_rect(placement.tile.tile_id)
				rect.position -= global_position
				var bs := Scale.limiting_scale(rect.size, Vector2(60, 90))
				draw_rect(rect.grow(3 * bs), color, false, 3 * bs)
				if skin != null:
					var ghost := rect
					ghost.position.y -= 45 * bs * alpha
					draw_texture_rect(skin.tile_base_texture(), ghost, false, Color(1, 1, 1, alpha * 0.55))
