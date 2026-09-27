extends Control
const Scale := preload("res://scripts/presentation/presentation_scale.gd")
const State := preload("res://scripts/simulation/battle/battle_state.gd")
const Attacks := preload("res://scripts/simulation/battle/battle_attacks.gd")
var gameplay_theme: Resource
var snapshot: Dictionary = {}
var threshold := 4000
var opponent_name := "CPU"
var _font: Font

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 _font = load(gameplay_theme.bold_font_path)
 resized.connect(queue_redraw)

func refresh(state: Dictionary, charge_threshold: int) -> void:
 snapshot = state
 threshold = charge_threshold
 queue_redraw()

func ui_scale() -> float:
 return Scale.limiting_scale(size, Vector2(360, 88))

func race_anchor(side: String) -> Vector2:
 var s := ui_scale()
 var center := Vector2(size.x / 2, 37 * s)
 if side not in ["player", "cpu"]: return center
 var direction := 1 if side == "player" else -1
 var start := Vector2(16 * s if side == "player" else size.x - 16 * s, center.y)
 var finish := center - Vector2(direction * 24 * s, 0)
 return start.lerp(finish, State.progress(snapshot, side) if not snapshot.is_empty() else 0.0)

func _text(text: String, rect: Rect2, font_size: float, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
 var pixels := maxi(1, roundi(font_size))
 while pixels > 1 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > rect.size.x:
  pixels -= 1
 draw_string(_font, rect.position + Vector2(0, _font.get_ascent(pixels)), text, alignment, rect.size.x, pixels, color)

func _draw() -> void:
 if gameplay_theme == null or _font == null: return
 var s := ui_scale()
 var ink: Color = gameplay_theme.battle_panel_color
 var paper: Color = gameplay_theme.battle_text_color
 # Uneven double ink edge, rather than a polished rounded dashboard card.
 var edge := PackedVector2Array([Vector2(2, 3) * s, Vector2(size.x - 5 * s, 0), Vector2(size.x, size.y - 3 * s), Vector2(0, size.y), Vector2(2, 3) * s])
 draw_colored_polygon(edge, ink)
 draw_polyline(edge, paper.darkened(0.45), 2 * s, true)
 draw_line(Vector2(7, 5) * s, Vector2(size.x - 8 * s, 4 * s), Color(paper, 0.25), s, true)
 var center := race_anchor("center")
 var left_width := size.x / 2 - 37 * s
 _text("YOU", Rect2(Vector2(12, 4) * s, Vector2(left_width, 19 * s)), 15 * s, paper)
 _text(opponent_name.to_upper(), Rect2(Vector2(size.x / 2 + 37 * s, 4 * s), Vector2(left_width - 12 * s, 19 * s)), 15 * s, paper, HORIZONTAL_ALIGNMENT_RIGHT)
 _text("FINISH", Rect2(Vector2(center.x - 31 * s, 0), Vector2(62, 15) * s), 10 * s, paper, HORIZONTAL_ALIGNMENT_CENTER)
 for side in ["player", "cpu"]:
  var direction := 1 if side == "player" else -1
  var color: Color = gameplay_theme.battle_player_color if side == "player" else gameplay_theme.battle_cpu_color
  var start := Vector2(16 * s if side == "player" else size.x - 16 * s, center.y)
  var finish := center - Vector2(direction * 24 * s, 0)
  var marker := race_anchor(side)
  draw_line(start, finish, paper.darkened(0.65), 4 * s, true)
  draw_line(start, marker, color, 4 * s, true)
  draw_circle(start, 2 * s, paper)
  draw_circle(marker, 5 * s, color)
  draw_circle(marker, 2 * s, ink)
  var tip := finish + Vector2(direction * 2 * s, 0)
  draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-direction * 6, -4) * s, tip + Vector2(-direction * 6, 4) * s]), color)
 draw_circle(center, 18 * s, ink)
 draw_arc(center, 18 * s, 0, TAU, 48, paper.darkened(0.6), 3 * s, true)
 var charge := 0.0 if snapshot.is_empty() else clampf(float(snapshot.sides.player.attack_charge_units) / maxi(1, threshold), 0, 1)
 if charge > 0: draw_arc(center, 18 * s, -PI / 2, -PI / 2 + TAU * charge, 48, gameplay_theme.battle_player_color, 3 * s, true)
 _text("%d%%" % roundi(charge * 100), Rect2(center - Vector2(18, 8) * s, Vector2(36, 17) * s), 13 * s, paper, HORIZONTAL_ALIGNMENT_CENTER)
 _text("ATTACK", Rect2(Vector2(center.x - 30 * s, 57 * s), Vector2(60, 14) * s), 9 * s, paper, HORIZONTAL_ALIGNMENT_CENTER)
 if snapshot.is_empty(): return
 var player: Dictionary = snapshot.sides.player
 var cpu: Dictionary = snapshot.sides.cpu
 _text("SCORE %s" % _number(player.score), Rect2(Vector2(12, 57) * s, Vector2(left_width, 14 * s)), 10 * s, paper.darkened(0.12))
 _text("STREAK ×%d" % player.streak, Rect2(Vector2(12, 71) * s, Vector2(left_width, 17 * s)), 13 * s, gameplay_theme.battle_player_color)
 var right_rect := Rect2(Vector2(center.x + 36 * s, 57 * s), Vector2(left_width - 12 * s, 15 * s))
 _text("CPU %d LEFT" % cpu.remaining_pairs, right_rect, 11 * s, paper, HORIZONTAL_ALIGNMENT_RIGHT)
 var incoming := Attacks.pending_pairs(snapshot, "player")
 for attack in snapshot.landed_attacks:
  if attack.target == "player" and attack.id not in snapshot.player_board.get("applied_attacks", []): incoming += int(attack.pair_count)
 right_rect.position.y = 73 * s
 _text("INCOMING %d" % incoming if incoming > 0 else "", right_rect, 10 * s, gameplay_theme.battle_cpu_color, HORIZONTAL_ALIGNMENT_RIGHT)

func _number(value: int) -> String:
 var source := str(value)
 var result := ""
 for i in source.length():
  if i > 0 and (source.length() - i) % 3 == 0: result += ","
  result += source[i]
 return result
