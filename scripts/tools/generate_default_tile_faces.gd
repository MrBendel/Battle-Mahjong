extends SceneTree

const OUTPUT_DIRECTORY := "res://art-source/tiles/default/faces"
const INK := "#163f4a"
const GREEN := "#168a67"
const LIME := "#8dd05c"
const RED := "#dc3855"
const PINK := "#ef5b77"
const BLUE := "#1676a8"
const GOLD := "#e9ae32"
const IVORY := "#fff7df"


func _init() -> void:
	var failures := 0
	for value in range(1, 10):
		failures += int(not _write_face("bamboo_%d" % value, _bamboo(value)))
		failures += int(not _write_face("dots_%d" % value, _dots(value)))
		failures += int(not _write_face("characters_%d" % value, _character(value)))
	for wind in ["east", "south", "west", "north"]:
		failures += int(not _write_face(wind, _wind(wind)))
	failures += int(not _write_face("red_dragon", _dragon("red")))
	failures += int(not _write_face("green_dragon", _dragon("green")))
	failures += int(not _write_face("white_dragon", _dragon("white")))
	printerr("Generated 34 Default tile-face SVG masters." if failures == 0 else "Failed to generate %d tile face(s)." % failures)
	quit(1 if failures > 0 else 0)


func _write_face(face_id: String, body: String) -> bool:
	var path := OUTPUT_DIRECTORY.path_join(face_id + ".svg")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(_svg(body))
	return true


func _svg(body: String) -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="328" height="400" viewBox="0 0 328 400">
  <g stroke-linecap="round" stroke-linejoin="round">
%s
  </g>
</svg>
""" % body


func _bamboo(value: int) -> String:
	if value == 1:
		return """    <g transform="rotate(7 164 200)">
      <rect x="138" y="48" width="52" height="304" rx="22" fill="%s" stroke="%s" stroke-width="10"/>
      <path d="M143 126 H185 M143 210 H185 M143 292 H185" stroke="%s" stroke-width="13"/>
      <path d="M145 112 C92 104 71 74 78 44 C124 49 151 73 156 107" fill="%s" stroke="%s" stroke-width="8"/>
      <path d="M185 225 C235 218 258 242 254 274 C211 274 184 255 175 232" fill="%s" stroke="%s" stroke-width="8"/>
    </g>""" % [GREEN, INK, LIME, LIME, INK, LIME, INK]
	var marks := ""
	var positions := _pip_positions(value)
	for index in positions.size():
		var point: Vector2i = positions[index]
		var fill := GREEN if index % 3 != 1 else BLUE
		var angle := -7 if index % 2 == 0 else 7
		marks += """
    <g transform="translate(%d %d) rotate(%d)">
      <rect x="-15" y="-31" width="30" height="62" rx="11" fill="%s" stroke="%s" stroke-width="6"/>
      <path d="M-12 -7 H12 M-12 14 H12" stroke="%s" stroke-width="7"/>
    </g>""" % [point.x, point.y, angle, fill, INK, LIME]
	return marks + _brush_accents(GREEN)


func _dots(value: int) -> String:
	var marks := ""
	var positions := _pip_positions(value)
	for index in positions.size():
		var point: Vector2i = positions[index]
		var radius := 50 if value == 1 else 29
		var colors := [RED, GREEN, BLUE, GOLD]
		var fill: String = colors[index % colors.size()]
		marks += """
    <g transform="rotate(%d %d %d)">
      <circle cx="%d" cy="%d" r="%d" fill="%s" stroke="%s" stroke-width="8"/>
      <circle cx="%d" cy="%d" r="%d" fill="none" stroke="%s" stroke-width="7" opacity="0.9"/>
    </g>""" % [(-5 if index % 2 == 0 else 5), point.x, point.y, point.x, point.y, radius, fill, INK, point.x, point.y, int(radius * 0.42), IVORY]
	return marks + _brush_accents(RED if value % 2 == 1 else BLUE)


func _character(value: int) -> String:
	var active_segments: Dictionary = {
		1: ["b", "c"],
		2: ["a", "b", "g", "e", "d"],
		3: ["a", "b", "g", "c", "d"],
		4: ["f", "g", "b", "c"],
		5: ["a", "f", "g", "c", "d"],
		6: ["a", "f", "g", "e", "c", "d"],
		7: ["a", "b", "c"],
		8: ["a", "b", "c", "d", "e", "f", "g"],
		9: ["a", "b", "c", "d", "f", "g"],
	}
	var segments := {
		"a": "M104 64 L220 58",
		"b": "M226 72 L214 170",
		"c": "M210 192 L198 290",
		"d": "M88 304 L196 296",
		"e": "M82 194 L74 292",
		"f": "M96 72 L86 170",
		"g": "M92 182 L212 176",
	}
	var paths := ""
	for segment in active_segments[value]:
		paths += "\n    <path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"24\"/>" % [segments[segment], RED]
	return """    <path d="M68 342 C112 324 212 326 262 338" fill="none" stroke="%s" stroke-width="12" opacity="0.75"/>
%s
    <g transform="translate(220 316) rotate(-5)">
      <rect x="0" y="0" width="62" height="54" rx="8" fill="none" stroke="%s" stroke-width="8"/>
      <path d="M14 15 H48 M12 31 H50 M22 10 V43 M40 10 V43" stroke="%s" stroke-width="7"/>
    </g>
%s""" % [INK, paths, BLUE, BLUE, _brush_accents(PINK)]


func _wind(direction: String) -> String:
	var paths := {
		"east": "M98 76 V310 M98 78 H238 M98 190 H214 M98 308 H238",
		"south": "M230 92 C202 58 106 64 92 126 C76 196 226 164 224 246 C222 318 104 330 78 278",
		"west": "M70 84 L112 308 L164 158 L216 308 L258 84",
		"north": "M82 310 V82 L246 310 V82",
	}
	var accent_colors := {"east": RED, "south": GOLD, "west": PINK, "north": GREEN}
	return """    <path d="%s" fill="none" stroke="%s" stroke-width="30"/>
    <path d="M74 350 C128 334 212 334 258 346" fill="none" stroke="%s" stroke-width="14"/>
%s""" % [paths[direction], BLUE, accent_colors[direction], _brush_accents(str(accent_colors[direction]))]


func _dragon(kind: String) -> String:
	if kind == "red":
		return """    <path d="M76 76 H252 V136 H190 V264 H252 V324 H76 V264 H138 V136 H76 Z" fill="%s" stroke="%s" stroke-width="12"/>
    <path d="M96 178 H232" stroke="%s" stroke-width="18"/>
    <circle cx="164" cy="200" r="18" fill="%s"/>
%s""" % [RED, "#7c1c35", IVORY, GOLD, _brush_accents(RED)]
	if kind == "green":
		return """    <path d="M164 50 L226 112 L204 166 L254 216 L214 320 L164 292 L112 320 L74 216 L124 166 L102 112 Z" fill="none" stroke="%s" stroke-width="22"/>
    <path d="M112 136 H218 M104 222 H226 M164 84 V286" stroke="%s" stroke-width="18"/>
    <circle cx="164" cy="202" r="22" fill="%s"/>
%s""" % [GREEN, GREEN, GOLD, _brush_accents(GREEN)]
	return """    <rect x="62" y="54" width="204" height="286" rx="22" fill="none" stroke="%s" stroke-width="18"/>
    <rect x="86" y="82" width="156" height="230" rx="14" fill="none" stroke="%s" stroke-width="8" opacity="0.65"/>
    <path d="M86 82 L62 54 M242 82 L266 54 M86 312 L62 340 M242 312 L266 340" stroke="%s" stroke-width="10"/>
%s""" % [BLUE, GOLD, RED, _brush_accents(BLUE)]


func _brush_accents(color: String) -> String:
	return """
    <path d="M36 34 L72 26 M270 366 L298 354 M36 362 L58 350" stroke="%s" stroke-width="9" opacity="0.7"/>""" % color


func _pip_positions(value: int) -> Array[Vector2i]:
	var positions: Dictionary = {
		1: [Vector2i(164, 198)],
		2: [Vector2i(96, 104), Vector2i(232, 296)],
		3: [Vector2i(96, 104), Vector2i(164, 200), Vector2i(232, 296)],
		4: [Vector2i(96, 105), Vector2i(232, 105), Vector2i(96, 295), Vector2i(232, 295)],
		5: [Vector2i(96, 88), Vector2i(232, 88), Vector2i(164, 200), Vector2i(96, 312), Vector2i(232, 312)],
		6: [Vector2i(96, 72), Vector2i(232, 72), Vector2i(96, 200), Vector2i(232, 200), Vector2i(96, 328), Vector2i(232, 328)],
		7: [Vector2i(96, 62), Vector2i(232, 62), Vector2i(96, 166), Vector2i(232, 166), Vector2i(164, 226), Vector2i(96, 334), Vector2i(232, 334)],
		8: [Vector2i(96, 54), Vector2i(232, 54), Vector2i(96, 150), Vector2i(232, 150), Vector2i(96, 250), Vector2i(232, 250), Vector2i(96, 346), Vector2i(232, 346)],
		9: [Vector2i(76, 72), Vector2i(164, 72), Vector2i(252, 72), Vector2i(76, 200), Vector2i(164, 200), Vector2i(252, 200), Vector2i(76, 328), Vector2i(164, 328), Vector2i(252, 328)],
	}
	var result: Array[Vector2i] = []
	result.assign(positions[value])
	return result
