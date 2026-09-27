extends Control
const Scale := preload("res://scripts/presentation/presentation_scale.gd")
var character: Resource
var gameplay_theme: Resource
var suspended := false
var active_cue := ""
var age := 0.0
var cooldown := 0.0
var _priority := -1
var _last_revision := -1
var _portrait: Texture2D
var _frustrated: Texture2D
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	z_index = 90
	_portrait = _texture(character.portrait_path)
	_frustrated = _texture(character.frustrated_path)
	_font = load(gameplay_theme.bold_font_path)
	resized.connect(queue_redraw)

func _texture(path: String) -> Texture2D:
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null

func reset() -> void:
	active_cue = ""
	age = 0
	cooldown = 0
	_priority = -1
	_last_revision = -1
	queue_redraw()

func consume(events: Array) -> void:
	var chosen := ""
	var priority := -1
	var latest := _last_revision
	for event in events:
		if event.type != "character_reaction" or event.revision <= _last_revision:
			continue
		latest = maxi(latest, event.revision)
		var reaction: Dictionary = character.reactions.get(event.cue, {})
		if not reaction.is_empty() and int(reaction.priority) >= priority:
			chosen = event.cue
			priority = reaction.priority
	_last_revision = latest
	if chosen.is_empty(): return
	# Higher urgency can interrupt; equal/lower cues are dropped, never queued stale.
	if cooldown > 0 and priority <= _priority: return
	active_cue = chosen
	_priority = priority
	age = 0
	cooldown = character.cooldown_seconds
	queue_redraw()

func _process(delta: float) -> void:
	if suspended: return
	cooldown = maxf(0, cooldown - delta)
	if active_cue.is_empty(): return
	age += delta
	if age >= character.duration_seconds:
		active_cue = ""
	queue_redraw()

func reaction_text() -> String:
	return str(character.reactions.get(active_cue, {}).get("text", ""))

func reaction_texture() -> Texture2D:
	if character.reactions.get(active_cue, {}).get("expression", "") == "frustrated" and _frustrated != null:
		return _frustrated
	return _portrait

func _draw() -> void:
	if active_cue.is_empty() or character == null or _font == null: return
	var s := Scale.limiting_scale(size, Vector2(330, 88))
	var entrance := 1.0 - pow(1.0 - clampf(age / character.entrance_seconds, 0, 1), 3)
	var fade := clampf((character.duration_seconds - age) / character.entrance_seconds, 0, 1)
	var offset := (1 - entrance) * 90 * s
	var ink: Color = gameplay_theme.battle_panel_color
	var paper: Color = gameplay_theme.battle_text_color
	ink.a = fade
	paper.a = fade
	# A large cropped bust leans in from the opponent edge; clipping protects
	# live tray/Board pixels while preserving the larger character scale.
	var extent := 182 * s
	var rect := Rect2(Vector2(size.x - extent + offset, -24 * s), Vector2(extent, extent))
	var texture := reaction_texture()
	if texture != null:
		rect.size.y = extent / texture.get_size().aspect()
		draw_texture_rect(texture, rect, false, Color(1, 1, 1, fade))
	var right := rect.position.x + 30 * s
	var bubble := Rect2(Vector2(4 * s + offset, 13 * s), Vector2(maxf(1, right - 8 * s - offset), 59 * s))
	var points := PackedVector2Array([bubble.position + Vector2(3, 0) * s, Vector2(bubble.end.x - 4 * s, bubble.position.y + 3 * s), bubble.end - Vector2(0, 13 * s), bubble.end + Vector2(12, 2) * s, bubble.end - Vector2(18, 0) * s, Vector2(bubble.position.x, bubble.end.y - 2 * s), bubble.position + Vector2(3, 0) * s])
	draw_colored_polygon(points, paper)
	draw_polyline(points, ink, 2 * s, true)
	var text := reaction_text()
	var available := bubble.size.x - 14 * s
	var font_size := maxi(1, roundi(18 * s))
	while font_size > 1 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 1
	draw_string(_font, bubble.position + Vector2(7 * s, (bubble.size.y + _font.get_ascent(font_size) - _font.get_descent(font_size)) / 2), text, HORIZONTAL_ALIGNMENT_CENTER, available, font_size, ink)
