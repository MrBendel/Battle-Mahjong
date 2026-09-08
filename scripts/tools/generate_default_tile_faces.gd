extends SceneTree

const OUTPUT_DIRECTORY := "res://art-source/tiles/default/faces"

# Cohesive Japanese arcade palette matching the inspiration image
const NAVY := "#162f56"
const RED := "#c92424"
const GREEN := "#106f36"
const LIME := "#38a169"
const PINK := "#ee658d"
const GOLD := "#f2a014"
const SKY_BLUE := "#2272c3"
const WHITE := "#ffffff"
const INK := "#121b24"
const BROWNY := "#84532b"


func _init() -> void:
	var failures := 0
	# Canonical 34 Mahjong faces
	for value in range(1, 10):
		failures += int(not _write_face("bamboo_%d" % value, _bamboo(value)))
		failures += int(not _write_face("dots_%d" % value, _dots(value)))
		failures += int(not _write_face("characters_%d" % value, _character(value)))
	for wind in ["east", "south", "west", "north"]:
		failures += int(not _write_face(wind, _wind(wind)))
	failures += int(not _write_face("red_dragon", _dragon("red")))
	failures += int(not _write_face("green_dragon", _dragon("green")))
	failures += int(not _write_face("white_dragon", _dragon("white")))

	# Mascot bonus tiles matching inspiration image
	failures += int(not _write_face("mascot_cat", _mascot_cat()))
	failures += int(not _write_face("mascot_bunny", _mascot_bunny()))
	failures += int(not _write_face("mascot_panda", _mascot_panda()))
	failures += int(not _write_face("mascot_oni", _mascot_oni()))
	failures += int(not _write_face("mascot_fuji", _mascot_fuji()))
	failures += int(not _write_face("mascot_skull", _mascot_skull()))
	failures += int(not _write_face("mascot_star", _mascot_star()))
	failures += int(not _write_face("mascot_flower", _mascot_flower()))
	failures += int(not _write_face("mascot_dragon", _mascot_dragon()))

	printerr("Generated tile-face SVG masters." if failures == 0 else "Failed to generate %d tile face(s)." % failures)
	quit(1 if failures > 0 else 0)


func _write_face(face_id: String, body: String) -> bool:
	var path := OUTPUT_DIRECTORY.path_join(face_id + ".svg")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Could not write %s" % path)
		return false
	file.store_string(_svg(body))
	return true


func _svg(body: String) -> String:
	# Face safe area matching skin.json exactly: 368 x 506
	return """<svg xmlns="http://www.w3.org/2000/svg" width="368" height="506" viewBox="0 0 368 506">
  <g stroke-linecap="round" stroke-linejoin="round">
%s
  </g>
</svg>
""" % body


# -----------------------------------------------------------------------------
# BAMBOO (Songbird for 1, upright segmented bamboo stalks for 2-9)
# -----------------------------------------------------------------------------
func _bamboo(value: int) -> String:
	if value == 1:
		# Blue Songbird perched on a twig (Aoi Tori / Japanese Bluebird)
		return """    <!-- Perch branch -->
    <path d="M40 395 C110 380 230 380 328 402" fill="none" stroke="%s" stroke-width="18"/>
    <path d="M68 395 C88 424 112 436 136 430" fill="none" stroke="%s" stroke-width="11"/>
    <!-- Tiny green sprout on twig -->
    <path d="M80 390 C68 375 60 380 65 390 C70 392 76 392 80 390 Z" fill="%s"/>
    <!-- Feet -->
    <path d="M165 372 L158 390 M178 372 L176 390 M216 372 L214 390 M228 372 L230 390" stroke="%s" stroke-width="8"/>
    <!-- Tail feathers -->
    <path d="M120 305 L60 365 C52 372 64 378 74 370 L132 325 Z" fill="#154d85" stroke="%s" stroke-width="8"/>
    <path d="M130 318 L76 390 C70 396 82 400 90 392 L144 332 Z" fill="%s" stroke="%s" stroke-width="8"/>
    <!-- Chubby Bird Body -->
    <path d="M142 195 C136 125 186 86 244 94 C290 100 316 142 312 190 C308 262 276 360 200 362 C146 362 136 272 142 195 Z" fill="%s" stroke="%s" stroke-width="10"/>
    <!-- White / Cream Breast -->
    <path d="M225 152 C206 174 200 220 206 284 C212 344 252 356 272 320 C296 280 306 224 292 168 C280 144 246 138 225 152 Z" fill="%s" stroke="%s" stroke-width="7"/>
    <!-- Wing -->
    <path d="M154 205 C166 184 216 188 230 240 C242 292 216 338 174 330 C148 325 142 268 154 205 Z" fill="#144f88" stroke="%s" stroke-width="9"/>
    <path d="M174 240 C194 248 212 268 204 306" fill="none" stroke="%s" stroke-width="6"/>
    <path d="M190 218 C210 230 222 255 220 286" fill="none" stroke="%s" stroke-width="6"/>
    <!-- Beak -->
    <path d="M308 145 L354 160 L306 176 Z" fill="%s" stroke="%s" stroke-width="8"/>
    <!-- Eye -->
    <circle cx="272" cy="148" r="14" fill="%s"/>
    <circle cx="277" cy="143" r="5" fill="%s"/>""" % [
			BROWNY, BROWNY, LIME, INK, INK, SKY_BLUE, INK, SKY_BLUE, INK, WHITE, INK, INK, SKY_BLUE, SKY_BLUE, GOLD, INK, INK, WHITE
		]

	var stalk_h := 130.0
	var stalk_w := 42.0
	if value in [2, 3]:
		stalk_h = 260.0
		stalk_w = 48.0
	elif value == 4:
		stalk_h = 145.0
		stalk_w = 44.0

	var stalks := ""
	var coords := _bamboo_coords(value)
	for i in coords.size():
		var pos: Vector2 = coords[i]
		var is_tall := (value in [2, 3])
		stalks += _single_bamboo_stalk(pos.x, pos.y, stalk_w, stalk_h, is_tall)
	return stalks


func _single_bamboo_stalk(cx: float, cy: float, w: float, h: float, tall: bool = false) -> String:
	var half_w := w * 0.5
	var half_h := h * 0.5
	var top_y := cy - half_h
	var bot_y := cy + half_h
	var segments := 3 if tall else 2
	var seg_h := h / float(segments)

	var s := """
    <!-- Stalk %d,%d -->
    <g>
      <rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s" stroke="%s" stroke-width="9"/>""" % [
		int(cx), int(cy), cx - half_w, top_y, w, h, half_w * 0.45, GREEN, INK
	]
	# Center light stripe
	s += """
      <line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f" opacity="0.5"/>""" % [
		cx, top_y + 10.0, cx, bot_y - 10.0, LIME, w * 0.28
	]
	# Nodes / Joints
	for i in range(1, segments):
		var joint_y := top_y + float(i) * seg_h
		s += """
      <path d="M%.1f %.1f H%.1f" stroke="%s" stroke-width="10"/>
      <ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="6" fill="%s" stroke="%s" stroke-width="4"/>""" % [
			cx - half_w - 4.0, joint_y, cx + half_w + 4.0, INK,
			cx, joint_y, half_w * 0.95, LIME, INK
		]
	s += """
    </g>"""
	return s


func _bamboo_coords(value: int) -> Array[Vector2]:
	var list: Array[Vector2] = []
	match value:
		2:
			list.append(Vector2(128, 253))
			list.append(Vector2(240, 253))
		3:
			list.append(Vector2(92, 253))
			list.append(Vector2(184, 253))
			list.append(Vector2(276, 253))
		4:
			list.append(Vector2(120, 160))
			list.append(Vector2(248, 160))
			list.append(Vector2(120, 346))
			list.append(Vector2(248, 346))
		5:
			list.append(Vector2(100, 150))
			list.append(Vector2(268, 150))
			list.append(Vector2(184, 253))
			list.append(Vector2(100, 356))
			list.append(Vector2(268, 356))
		6:
			# 3 on top, 3 on bottom
			list.append(Vector2(95, 160))
			list.append(Vector2(184, 160))
			list.append(Vector2(273, 160))
			list.append(Vector2(95, 346))
			list.append(Vector2(184, 346))
			list.append(Vector2(273, 346))
		7:
			list.append(Vector2(95, 135))
			list.append(Vector2(184, 150))
			list.append(Vector2(273, 165))
			list.append(Vector2(120, 290))
			list.append(Vector2(248, 290))
			list.append(Vector2(120, 410))
			list.append(Vector2(248, 410))
		8:
			list.append(Vector2(85, 160))
			list.append(Vector2(151, 160))
			list.append(Vector2(217, 160))
			list.append(Vector2(283, 160))
			list.append(Vector2(85, 346))
			list.append(Vector2(151, 346))
			list.append(Vector2(217, 346))
			list.append(Vector2(283, 346))
		9:
			list.append(Vector2(95, 135))
			list.append(Vector2(184, 135))
			list.append(Vector2(273, 135))
			list.append(Vector2(95, 253))
			list.append(Vector2(184, 253))
			list.append(Vector2(273, 253))
			list.append(Vector2(95, 371))
			list.append(Vector2(184, 371))
			list.append(Vector2(273, 371))
	return list


# -----------------------------------------------------------------------------
# DOTS (Japanese Pin / Concentric Target Wheels)
# -----------------------------------------------------------------------------
func _dots(value: int) -> String:
	if value == 1:
		return _target_wheel(184, 253, 115.0, true)

	var s := ""
	var coords := _dots_coords(value)
	var radius := 44.0
	if value == 2:
		radius = 64.0
	elif value == 3:
		radius = 54.0
	elif value == 4:
		radius = 50.0
	elif value in [5, 6]:
		radius = 44.0
	else:
		radius = 38.0

	for i in coords.size():
		var pos: Vector2 = coords[i]
		# In inspiration image, wheels have the red center pip!
		s += _target_wheel(pos.x, pos.y, radius, true)
	return s


func _target_wheel(cx: float, cy: float, r: float, red_center: bool = true) -> String:
	var center_color := RED if red_center else NAVY
	var ring_w := r * 0.22
	var inner_r := r * 0.44
	var pip_r := r * 0.25
	var pin_r := r * 0.08
	return """
    <!-- Target Wheel %.0f,%.0f -->
    <g>
      <!-- Outer Navy Ring -->
      <circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>
      <!-- Concentric White Gap -->
      <circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>
      <!-- Inner Ring -->
      <circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>
      <!-- Center Pip -->
      <circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>
      <!-- Pinpoint white sparkle -->
      <circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>
    </g>""" % [
		cx, cy,
		cx, cy, r, NAVY, INK, max(4.5, r * 0.1),
		cx, cy, r - ring_w, WHITE,
		cx, cy, inner_r, NAVY,
		cx, cy, pip_r, center_color, INK, max(2.5, r * 0.06),
		cx, cy, pin_r, WHITE
	]


func _dots_coords(value: int) -> Array[Vector2]:
	var list: Array[Vector2] = []
	match value:
		2:
			list.append(Vector2(184, 150))
			list.append(Vector2(184, 356))
		3:
			list.append(Vector2(105, 140))
			list.append(Vector2(184, 253))
			list.append(Vector2(263, 366))
		4:
			list.append(Vector2(115, 155))
			list.append(Vector2(253, 155))
			list.append(Vector2(115, 351))
			list.append(Vector2(253, 351))
		5:
			list.append(Vector2(100, 145))
			list.append(Vector2(268, 145))
			list.append(Vector2(184, 253))
			list.append(Vector2(100, 361))
			list.append(Vector2(268, 361))
		6:
			list.append(Vector2(115, 140))
			list.append(Vector2(253, 140))
			list.append(Vector2(115, 253))
			list.append(Vector2(253, 253))
			list.append(Vector2(115, 366))
			list.append(Vector2(253, 366))
		7:
			list.append(Vector2(95, 130))
			list.append(Vector2(184, 165))
			list.append(Vector2(273, 200))
			list.append(Vector2(115, 295))
			list.append(Vector2(253, 295))
			list.append(Vector2(115, 410))
			list.append(Vector2(253, 410))
		8:
			list.append(Vector2(120, 115))
			list.append(Vector2(248, 115))
			list.append(Vector2(120, 207))
			list.append(Vector2(248, 207))
			list.append(Vector2(120, 299))
			list.append(Vector2(248, 299))
			list.append(Vector2(120, 391))
			list.append(Vector2(248, 391))
		9:
			list.append(Vector2(100, 135))
			list.append(Vector2(184, 135))
			list.append(Vector2(268, 135))
			list.append(Vector2(100, 253))
			list.append(Vector2(184, 253))
			list.append(Vector2(268, 253))
			list.append(Vector2(100, 371))
			list.append(Vector2(184, 371))
			list.append(Vector2(268, 371))
	return list


# -----------------------------------------------------------------------------
# CHARACTERS (Kanji Numeral 一-九 in navy over 萬 in cinnabar red)
# -----------------------------------------------------------------------------
func _character(value: int) -> String:
	var num_svg := _kanji_numeral(value)
	var wan_svg := _kanji_wan()
	return num_svg + wan_svg


func _kanji_numeral(value: int) -> String:
	var c := NAVY
	var sw := 26
	match value:
		1:
			# 一
			return """
    <!-- Kanji 1 一 -->
    <path d="M65 145 C130 136 238 136 303 145" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw + 2]
		2:
			# 二
			return """
    <!-- Kanji 2 二 -->
    <path d="M95 105 C145 100 223 100 273 105" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M60 165 C135 156 233 156 308 165" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw - 2, c, sw + 2]
		3:
			# 三
			return """
    <!-- Kanji 3 三 -->
    <path d="M95 90 C145 86 223 86 273 90" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M110 130 C150 128 218 128 258 130" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M60 172 C135 164 233 164 308 172" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw - 2, c, sw - 4, c, sw + 2]
		4:
			# 四
			return """
    <!-- Kanji 4 四 -->
    <path d="M82 80 L82 185 M82 80 L286 80 L286 185" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M135 105 C128 135 120 160 108 178" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M195 102 L195 148 C215 148 238 152 248 168" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M72 185 L296 185" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw, c, sw - 4, c, sw - 4, c, sw]
		5:
			# 五
			return """
    <!-- Kanji 5 五 -->
    <path d="M75 80 H293" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M178 84 L138 182" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M135 134 H250 L242 184" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M60 184 H308" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw, c, sw - 4, c, sw - 4, c, sw + 2]
		6:
			# 六
			return """
    <!-- Kanji 6 六 -->
    <path d="M184 70 L184 102" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M65 112 H303" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M142 132 C128 155 110 174 88 190" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M228 132 C242 155 260 174 282 190" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw + 2, c, sw, c, sw - 2, c, sw - 2]
		7:
			# 七
			return """
    <!-- Kanji 7 七 -->
    <path d="M68 132 C135 120 233 120 300 132" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M184 70 L184 148 C184 182 208 186 250 184 L264 160" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw, c, sw + 2]
		8:
			# 八
			return """
    <!-- Kanji 8 八 -->
    <path d="M145 90 C130 125 106 165 74 188" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M222 80 C238 122 264 165 294 188" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw + 2, c, sw + 2]
		9:
			# 九
			return """
    <!-- Kanji 9 九 -->
    <path d="M180 72 C162 118 130 165 75 190" fill="none" stroke="%s" stroke-width="%d"/>
    <path d="M120 115 H228 L218 162 C218 186 244 188 274 185 L286 162" fill="none" stroke="%s" stroke-width="%d"/>""" % [c, sw + 2, c, sw + 2]
	return ""


func _kanji_wan() -> String:
	# Traditional Cinnabar Red 萬 (Wan) matching Mahjong tiles
	var c := RED
	return """
    <!-- Kanji 萬 (Wan) in Cinnabar Red -->
    <g fill="none" stroke="%s" stroke-linecap="round" stroke-linejoin="round">
      <!-- Top grass radical 艹 -->
      <path d="M68 230 C145 220 223 220 300 230" stroke-width="28"/>
      <path d="M130 205 L130 252" stroke-width="22"/>
      <path d="M238 205 L238 252" stroke-width="22"/>
      <!-- Middle 日 (Sun) box with horizontal divider -->
      <path d="M102 272 H266 V345 H102 Z" stroke-width="22"/>
      <path d="M102 308 H266" stroke-width="18"/>
      <!-- Horizontal crossbar under 日 -->
      <path d="M80 370 H288" stroke-width="20"/>
      <!-- Lower calligraphy legs: left sweep, center hook, right sweep -->
      <path d="M125 372 C112 418 85 455 58 474" stroke-width="26"/>
      <path d="M184 350 V472" stroke-width="24"/>
      <path d="M243 372 C256 418 280 455 310 474" stroke-width="26"/>
    </g>""" % c


# -----------------------------------------------------------------------------
# WINDS (東, 南, 西, 北)
# -----------------------------------------------------------------------------
func _wind(wind: String) -> String:
	var c := NAVY
	match wind:
		"east":
			# 東
			return """
    <!-- Wind 東 (East) -->
    <g fill="none" stroke="%s" stroke-linecap="round" stroke-linejoin="round">
      <!-- Top horizontal stroke -->
      <path d="M75 125 H293" stroke-width="32"/>
      <!-- Center box (sun) -->
      <path d="M98 180 H270 V295 H98 Z" stroke-width="28"/>
      <path d="M98 238 H270" stroke-width="24"/>
      <!-- Main vertical spike cutting through -->
      <path d="M184 68 V445" stroke-width="34"/>
      <!-- Diagonal bottom legs -->
      <path d="M140 345 C115 388 82 430 52 452" stroke-width="28"/>
      <path d="M228 345 C253 388 286 430 316 452" stroke-width="28"/>
    </g>""" % c
		"south":
			# 南
			return """
    <!-- Wind 南 (South) -->
    <g fill="none" stroke="%s" stroke-linecap="round" stroke-linejoin="round">
      <path d="M105 85 H263" stroke-width="28"/>
      <path d="M184 65 V125" stroke-width="28"/>
      <!-- Outer enclosure -->
      <path d="M80 135 H288 V435" stroke-width="26"/>
      <path d="M80 135 V435" stroke-width="26"/>
      <!-- Inner cross and box -->
      <path d="M125 195 H243" stroke-width="22"/>
      <path d="M184 145 V345" stroke-width="24"/>
      <path d="M125 250 H243" stroke-width="22"/>
      <path d="M135 300 L115 380 M233 300 L253 380" stroke-width="22"/>
    </g>""" % c
		"west":
			# 西
			return """
    <!-- Wind 西 (West) -->
    <g fill="none" stroke="%s" stroke-linecap="round" stroke-linejoin="round">
      <!-- Top roof stroke -->
      <path d="M68 118 H300" stroke-width="34"/>
      <!-- Outer box with curved shoulders -->
      <path d="M88 175 H280 V415 H88 Z" stroke-width="30"/>
      <!-- Inner curving vertical strokes -->
      <path d="M145 175 C142 260 132 340 115 415" stroke-width="26"/>
      <path d="M223 175 C226 260 236 340 253 415" stroke-width="26"/>
      <path d="M132 290 H236" stroke-width="24"/>
    </g>""" % c
		"north":
			# 北
			return """
    <!-- Wind 北 (North) -->
    <g fill="none" stroke="%s" stroke-linecap="round" stroke-linejoin="round">
      <!-- Left side -->
      <path d="M140 95 V418" stroke-width="32"/>
      <path d="M78 240 H140" stroke-width="28"/>
      <path d="M68 370 L140 320" stroke-width="28"/>
      <!-- Right side -->
      <path d="M210 120 C190 170 175 200 160 225" stroke-width="28"/>
      <path d="M215 95 V340 C215 418 248 432 300 418 L312 380" stroke-width="32"/>
    </g>""" % c
	return ""


# -----------------------------------------------------------------------------
# DRAGONS (中 Red, 發 Green, 白 White)
# -----------------------------------------------------------------------------
func _dragon(color_name: String) -> String:
	match color_name:
		"red":
			# 中 (Chun) in bold cinnabar red
			return """
    <!-- Red Dragon 中 (Chun) -->
    <g fill="none" stroke="%s" stroke-linecap="round" stroke-linejoin="round">
      <!-- Outer box -->
      <path d="M75 180 H293 V335 H75 Z" stroke-width="36"/>
      <!-- Center vertical spear -->
      <path d="M184 70 V445" stroke-width="38"/>
    </g>""" % RED
		"green":
			# 發 (Fa) in rich emerald green
			return """
    <!-- Green Dragon 發 (Fa) -->
    <g fill="none" stroke="%s" stroke-linecap="round" stroke-linejoin="round">
      <!-- Top stepping radical (Bo) -->
      <path d="M155 85 C130 115 100 148 68 170" stroke-width="28"/>
      <path d="M98 135 L175 115" stroke-width="24"/>
      <path d="M215 80 L292 125" stroke-width="28"/>
      <path d="M218 115 C238 135 265 160 300 175" stroke-width="24"/>
      <!-- Bottom Left Bow (Gong) -->
      <path d="M105 215 H165 L135 265 H172 C172 330 155 360 90 385" stroke-width="24"/>
      <path d="M125 385 L180 440" stroke-width="24"/>
      <!-- Bottom Right Weapon (Shu) -->
      <path d="M215 210 H275" stroke-width="24"/>
      <path d="M245 210 V275" stroke-width="24"/>
      <path d="M205 275 H285 L235 345 H290" stroke-width="24"/>
      <path d="M260 345 C242 400 210 435 178 455" stroke-width="28"/>
      <path d="M230 395 C258 415 288 440 320 455" stroke-width="28"/>
    </g>""" % GREEN
		"white":
			# 白 (Haku) - Traditional framed porcelain dragon
			return """
    <!-- White Dragon 白 (Haku) -->
    <rect x="70" y="100" width="228" height="306" rx="22" fill="none" stroke="%s" stroke-width="28"/>
    <rect x="95" y="125" width="178" height="256" rx="12" fill="none" stroke="%s" stroke-width="7" stroke-dasharray="16,12"/>""" % [NAVY, SKY_BLUE]
	return ""


# -----------------------------------------------------------------------------
# MASCOT BONUS TILES (Cat, Bunny, Panda, Oni, Fuji, Skull, Star, Flower, Dragon)
# -----------------------------------------------------------------------------
func _mascot_cat() -> String:
	# Tuxedo Cat head (Black & White with wide circular staring eyes and pink triangular inner ears)
	return """
    <!-- Mascot Tuxedo Cat -->
    <!-- Ears (Triangular, compact & rounded tips matching reference) -->
    <!-- Left Ear outer -->
    <path d="M84 195 L96 86 L154 145 Z" fill="%s" stroke="%s" stroke-width="12"/>
    <!-- Left Ear inner pink -->
    <path d="M98 172 L104 106 L140 146 Z" fill="%s"/>
    <!-- Right Ear outer -->
    <path d="M284 195 L272 86 L214 145 Z" fill="%s" stroke="%s" stroke-width="12"/>
    <!-- Right Ear inner pink -->
    <path d="M270 172 L264 106 L228 146 Z" fill="%s"/>

    <!-- Head Silhouette / Chubby round head -->
    <ellipse cx="184" cy="256" rx="136" ry="122" fill="%s" stroke="%s" stroke-width="10"/>

    <!-- Crisp rim highlight contour along left ear & left cheek -->
    <path d="M96 90 C86 130 74 185 74 245" fill="none" stroke="%s" stroke-width="4.5" opacity="0.6"/>

    <!-- White Mask / Bib / Muzzle -->
    <path d="M184 194 C166 194 154 236 132 245 C108 255 96 282 98 320 C102 364 136 378 184 378 C232 378 266 364 270 320 C272 282 260 255 236 245 C214 236 202 194 184 194 Z" fill="%s" stroke="%s" stroke-width="6"/>

    <!-- Wide open circular staring eyes -->
    <!-- Left Eye -->
    <circle cx="128" cy="226" r="30" fill="%s" stroke="%s" stroke-width="10"/>
    <circle cx="128" cy="226" r="15" fill="%s"/>
    <!-- Right Eye -->
    <circle cx="240" cy="226" r="30" fill="%s" stroke="%s" stroke-width="10"/>
    <circle cx="240" cy="226" r="15" fill="%s"/>

    <!-- Small Red/Coral Nose -->
    <polygon points="184,302 174,290 194,290" fill="%s"/>

    <!-- Tiny Mouth (inverted-w / 人 shape) -->
    <path d="M184 302 L184 308 M174 316 C179 311 184 308 184 308 C184 308 189 311 194 316" fill="none" stroke="%s" stroke-width="6"/>

    <!-- 3 Whiskers on each side matching reference angles -->
    <line x1="98" y1="274" x2="22" y2="268" stroke="%s" stroke-width="7"/>
    <line x1="94" y1="298" x2="16" y2="298" stroke="%s" stroke-width="7"/>
    <line x1="98" y1="322" x2="26" y2="334" stroke="%s" stroke-width="7"/>

    <line x1="270" y1="274" x2="346" y2="268" stroke="%s" stroke-width="7"/>
    <line x1="274" y1="298" x2="352" y2="298" stroke="%s" stroke-width="7"/>
    <line x1="270" y1="322" x2="342" y2="334" stroke="%s" stroke-width="7"/>""" % [
		INK, INK, PINK, INK, INK, PINK, INK, INK, WHITE, WHITE, INK, WHITE, INK, INK, WHITE, INK, INK, RED, INK, INK, INK, INK, INK, INK, INK
	]


func _mascot_bunny() -> String:
	# Cute Pink Rabbit (larger scale)
	return """
    <!-- Mascot Pink Bunny -->
    <!-- Tall Ears -->
    <path d="M120 230 C105 110 110 45 136 40 C162 35 170 110 155 230 Z" fill="%s" stroke="%s" stroke-width="11"/>
    <path d="M126 205 C118 120 124 65 136 60 C148 55 154 120 145 205 Z" fill="#d94875"/>
    <path d="M248 230 C263 110 258 45 232 40 C206 35 198 110 213 230 Z" fill="%s" stroke="%s" stroke-width="11"/>
    <path d="M242 205 C250 120 244 65 232 60 C220 55 214 120 223 205 Z" fill="#d94875"/>
    <!-- Head -->
    <ellipse cx="184" cy="305" rx="125" ry="115" fill="%s" stroke="%s" stroke-width="11"/>
    <!-- Eyes -->
    <ellipse cx="140" cy="300" rx="17" ry="21" fill="%s"/>
    <circle cx="146" cy="293" r="6.5" fill="%s"/>
    <ellipse cx="228" cy="300" rx="17" ry="21" fill="%s"/>
    <circle cx="234" cy="293" r="6.5" fill="%s"/>
    <!-- Cheeks -->
    <circle cx="112" cy="332" r="17" fill="#fc9bb8" opacity="0.85"/>
    <circle cx="256" cy="332" r="17" fill="#fc9bb8" opacity="0.85"/>
    <!-- Nose & Mouth -->
    <ellipse cx="184" cy="322" rx="8" ry="6" fill="%s"/>
    <path d="M174 332 Q184 342 184 332 Q184 342 194 332" fill="none" stroke="%s" stroke-width="6"/>""" % [
		PINK, INK, PINK, INK, PINK, INK, INK, WHITE, INK, WHITE, INK, INK
	]


func _mascot_panda() -> String:
	# Cute Sitting Panda (larger scale)
	return """
    <!-- Mascot Panda -->
    <!-- Ears -->
    <circle cx="106" cy="165" r="38" fill="%s" stroke="%s" stroke-width="10"/>
    <circle cx="262" cy="165" r="38" fill="%s" stroke="%s" stroke-width="10"/>
    <!-- Body -->
    <ellipse cx="184" cy="365" rx="102" ry="92" fill="%s" stroke="%s" stroke-width="11"/>
    <!-- Arms / Pink Vest -->
    <path d="M98 325 C82 375 98 435 128 448 C152 435 152 365 132 330 Z" fill="%s" stroke="%s" stroke-width="10"/>
    <path d="M270 325 C286 375 270 435 240 448 C216 435 216 365 236 330 Z" fill="%s" stroke="%s" stroke-width="10"/>
    <ellipse cx="184" cy="385" rx="55" ry="42" fill="%s"/>
    <!-- Head -->
    <ellipse cx="184" cy="240" rx="108" ry="94" fill="%s" stroke="%s" stroke-width="11"/>
    <!-- Eye Patches -->
    <ellipse cx="140" cy="235" rx="29" ry="25" fill="%s" transform="rotate(-15 140 235)"/>
    <circle cx="144" cy="233" r="9" fill="%s"/>
    <ellipse cx="228" cy="235" rx="29" ry="25" fill="%s" transform="rotate(15 228 235)"/>
    <circle cx="232" cy="233" r="9" fill="%s"/>
    <!-- Nose & Mouth -->
    <ellipse cx="184" cy="272" rx="11" ry="8" fill="%s"/>
    <path d="M174 286 Q184 295 184 286 Q184 295 194 286" fill="none" stroke="%s" stroke-width="5.5"/>""" % [
		INK, INK, INK, INK, WHITE, INK, INK, INK, INK, INK, PINK, WHITE, INK, INK, WHITE, INK, WHITE, INK, INK
	]


func _mascot_oni() -> String:
	# Japanese Red Oni Mask (larger scale)
	return """
    <!-- Mascot Red Oni Mask -->
    <!-- Gold Horns -->
    <path d="M120 165 C100 115 95 60 108 40 C122 70 144 115 154 160 Z" fill="%s" stroke="%s" stroke-width="10"/>
    <path d="M248 165 C268 115 273 60 260 40 C246 70 224 115 214 160 Z" fill="%s" stroke="%s" stroke-width="10"/>
    <!-- Red Face -->
    <ellipse cx="184" cy="285" rx="118" ry="132" fill="%s" stroke="%s" stroke-width="12"/>
    <!-- Wild Eyebrows -->
    <path d="M98 205 C122 188 152 198 162 216" fill="none" stroke="%s" stroke-width="13"/>
    <path d="M270 205 C246 188 216 198 206 216" fill="none" stroke="%s" stroke-width="13"/>
    <!-- Fierce Eyes -->
    <circle cx="135" cy="242" r="23" fill="%s" stroke="%s" stroke-width="7"/>
    <circle cx="135" cy="242" r="11" fill="%s"/>
    <circle cx="233" cy="242" r="23" fill="%s" stroke="%s" stroke-width="7"/>
    <circle cx="233" cy="242" r="11" fill="%s"/>
    <!-- Broad Grinning Mouth with Teeth -->
    <path d="M115 328 C138 378 230 378 253 328 Z" fill="%s" stroke="%s" stroke-width="10"/>
    <path d="M128 340 H240 M148 328 V358 M184 328 V364 M220 328 V358" stroke="%s" stroke-width="5.5"/>""" % [
		GOLD, INK, GOLD, INK, RED, INK, INK, INK, WHITE, INK, INK, WHITE, INK, INK, INK, INK, WHITE
	]


func _mascot_fuji() -> String:
	# Mount Fuji with Rising Sun (large scale)
	return """
    <!-- Mascot Mount Fuji with Red Sun -->
    <!-- Radiant Red Sun -->
    <circle cx="184" cy="195" r="110" fill="%s" stroke="%s" stroke-width="10"/>
    <!-- Indigo Mountain Base -->
    <path d="M40 415 C75 405 138 275 152 215 H216 C230 275 293 405 328 415 Z" fill="%s" stroke="%s" stroke-width="12"/>
    <!-- White Snow Cap with Jagged Ridges -->
    <path d="M152 215 H216 L228 272 L210 260 L198 284 L184 262 L170 284 L158 260 L140 272 Z" fill="%s" stroke="%s" stroke-width="8"/>""" % [
		RED, INK, NAVY, INK, WHITE, INK
	]


func _mascot_skull() -> String:
	# Cute Pink Cartoon Skull (larger scale)
	return """
    <!-- Mascot Pink Skull -->
    <!-- Skull Cranium -->
    <path d="M82 230 C72 135 122 85 184 85 C246 85 296 135 286 230 C282 272 258 298 240 310 L240 390 H128 L128 310 C110 298 86 272 82 230 Z" fill="%s" stroke="%s" stroke-width="12"/>
    <!-- Big Eye Sockets -->
    <circle cx="138" cy="215" r="32" fill="%s"/>
    <circle cx="230" cy="215" r="32" fill="%s"/>
    <!-- Heart Nose -->
    <path d="M184 282 C174 264 162 270 172 286 L184 300 L196 286 C206 270 194 264 184 282 Z" fill="%s"/>
    <!-- Teeth -->
    <path d="M148 350 V390 M184 350 V390 M220 350 V390" stroke="%s" stroke-width="9"/>""" % [
		PINK, INK, INK, INK, INK, INK
	]


func _mascot_star() -> String:
	# Golden 5-Pointed Star (bold)
	return """
    <!-- Mascot Gold Star -->
    <polygon points="184,70 224,185 344,185 248,256 284,370 184,300 84,370 120,256 24,185 144,185" fill="%s" stroke="%s" stroke-width="15"/>
    <polygon points="184,105 215,194 312,194 234,250 262,340 184,286 106,340 134,250 56,194 153,194" fill="#fbc02d" opacity="0.6"/>""" % [
		GOLD, INK
	]


func _mascot_flower() -> String:
	# Sakura / Plum Blossom on Green Stem (larger scale)
	return """
    <!-- Mascot Sakura Flower -->
    <!-- Stem and Leaves -->
    <path d="M184 310 V445" stroke="%s" stroke-width="15"/>
    <path d="M184 380 C136 368 125 398 130 410 C148 410 172 398 184 386" fill="%s" stroke="%s" stroke-width="8"/>
    <path d="M184 380 C232 368 243 398 238 410 C220 410 196 398 184 386" fill="%s" stroke="%s" stroke-width="8"/>
    <!-- 5 Rounded Petals -->
    <g fill="%s" stroke="%s" stroke-width="11">
      <!-- Top Petal -->
      <ellipse cx="184" cy="165" rx="46" ry="55"/>
      <!-- Top-Right -->
      <ellipse cx="265" cy="216" rx="55" ry="46" transform="rotate(18 265 216)"/>
      <!-- Bottom-Right -->
      <ellipse cx="236" cy="305" rx="50" ry="48" transform="rotate(35 236 305)"/>
      <!-- Bottom-Left -->
      <ellipse cx="132" cy="305" rx="50" ry="48" transform="rotate(-35 132 305)"/>
      <!-- Top-Left -->
      <ellipse cx="103" cy="216" rx="55" ry="46" transform="rotate(-18 103 216)"/>
    </g>
    <!-- Center Pistil -->
    <circle cx="184" cy="242" r="33" fill="%s" stroke="%s" stroke-width="9"/>
    <circle cx="184" cy="242" r="12" fill="%s"/>""" % [
		GREEN, GREEN, INK, GREEN, INK, PINK, INK, RED, INK, GOLD
	]


func _mascot_dragon() -> String:
	# Red Mythical Coiled Dragon Crest (larger scale)
	return """
    <!-- Mascot Red Dragon Crest -->
    <g fill="none" stroke="%s" stroke-linecap="round" stroke-linejoin="round">
      <!-- Dragon Horns & Head -->
      <path d="M212 120 C242 75 288 68 300 52 C288 84 264 110 246 132" stroke-width="14"/>
      <path d="M188 132 C182 92 154 75 142 65 C158 92 172 115 178 138" stroke-width="12"/>
      <!-- Coiled Body -->
      <path d="M230 142 C290 164 326 235 302 305 C274 385 184 408 120 362 C64 305 76 215 142 168 C202 132 272 160 282 218 C292 276 248 325 188 325 C148 325 124 296 142 260" stroke-width="32"/>
      <!-- Spines / Crest Details -->
      <path d="M292 205 L322 198 M308 250 L338 258 M295 305 L322 322 M255 365 L274 395 M198 395 L204 430 M142 382 L135 418" stroke-width="10"/>
    </g>""" % RED

