extends SceneTree

const BASE_PATH := "res://game-assets/tiles/default/bases/tile_base_portrait.png"
const FACES_DIR := "res://game-assets/tiles/default/faces"
const SHADOW_PATH := "res://game-assets/tiles/default/tile_shadow_soft.png"
const OUTPUT_PATH := "res://docs/screenshots/in_game_theme_switcher_preview.png"

const TRAY_DARK := "res://game-assets/ui/board-trays/dark.png"
const TRAY_TERRAZZO := "res://game-assets/ui/board-trays/terrazzo.png"
const TRAY_WALNUT := "res://game-assets/ui/board-trays/walnut.png"
const TRAY_PORCELAIN := "res://game-assets/ui/board-trays/porcelain.png"
const TRAY_PAPER := "res://game-assets/ui/board-trays/paper.png"

const BG_MIDNIGHT := "res://game-assets/backgrounds/gameplay_midnight_ink.png"
const BG_MANGA := "res://game-assets/backgrounds/gameplay_manga_paper.png"

const FONT_BOLD_PATH := "res://assets/fonts/mila-script-sans-bold-tight.tres"
const FONT_REGULAR_PATH := "res://assets/fonts/mila-script-sans-regular-tight.tres"

func _init() -> void:
	print("Generating In-Game Theme Switcher Preview Screenshot...")
	var raw_base := Image.load_from_file(BASE_PATH)
	var raw_shadow := Image.load_from_file(SHADOW_PATH)
	if raw_base == null:
		printerr("Failed to load tile base.")
		quit(1)
		return
	raw_base.convert(Image.FORMAT_RGBA8)
	if raw_shadow != null:
		raw_shadow.convert(Image.FORMAT_RGBA8)

	var face_cat := Image.load_from_file("%s/mascot_cat.png" % FACES_DIR)
	var face_bamboo := Image.load_from_file("%s/bamboo_1.png" % FACES_DIR)
	var face_east := Image.load_from_file("%s/east.png" % FACES_DIR)
	if face_cat != null: face_cat.convert(Image.FORMAT_RGBA8)
	if face_bamboo != null: face_bamboo.convert(Image.FORMAT_RGBA8)
	if face_east != null: face_east.convert(Image.FORMAT_RGBA8)

	var font_bold: Font = load(FONT_BOLD_PATH)
	var font_regular: Font = load(FONT_REGULAR_PATH)

	# Overall composite canvas: 1600 x 920
	var canvas_w := 1600
	var canvas_h := 920
	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("0a1215")) # Dark backdrop

	# Left Column: In-Game Pause Menu presentation with Live Theme Button (x: 40 to 600)
	_draw_pause_menu_card(canvas, font_bold, font_regular, 60, 60, 480, 800)

	# Right Column: The 5 Swappable Themes live previews (x: 580 to 1540)
	var themes := [
		{
			"id": "default",
			"name": "DEFAULT CERAMIC",
			"tray_path": TRAY_DARK,
			"bg_path": BG_MIDNIGHT,
			"base_tint": Color(1.0, 1.0, 1.0),
			"neon_rim": Color(0, 0, 0, 0),
			"desc": "Midnight Ink background + Matte Dark Tray + Pure Ceramic",
		},
		{
			"id": "neon_nights",
			"name": "NEON NIGHTS",
			"tray_path": TRAY_TERRAZZO,
			"bg_path": BG_MIDNIGHT,
			"base_tint": Color(0.22, 0.23, 0.28),
			"neon_rim": Color(0.0, 0.95, 1.0, 0.9),
			"desc": "Terrazzo Tray + Midnight Ink + Dark Synthwave Cyan Bevel",
		},
		{
			"id": "imperial_jade",
			"name": "IMPERIAL JADE",
			"tray_path": TRAY_WALNUT,
			"bg_path": BG_MANGA,
			"base_tint": Color(0.18, 0.52, 0.38),
			"neon_rim": Color(0.3, 0.9, 0.6, 0.35),
			"desc": "Polished Walnut Tray + Manga Paper + Lustrous Jade",
		},
		{
			"id": "kawaii_pop",
			"name": "KAWAII POP",
			"tray_path": TRAY_PORCELAIN,
			"bg_path": BG_MANGA,
			"base_tint": Color(1.0, 0.88, 0.92),
			"neon_rim": Color(1.0, 0.45, 0.70, 0.6),
			"desc": "Porcelain Tray + Manga Paper + Bubblegum Pastel Tiles",
		},
		{
			"id": "vintage_washi",
			"name": "VINTAGE WASHI",
			"tray_path": TRAY_PAPER,
			"bg_path": BG_MANGA,
			"base_tint": Color(0.92, 0.86, 0.74),
			"neon_rim": Color(0.65, 0.45, 0.25, 0.4),
			"desc": "Handmade Paper Tray + Manga Paper + Aged Fibrous Tiles",
		},
	]

	var col_x := 580
	var panel_w := 960
	var panel_h := 148
	var panel_gap := 18
	var start_y := 60

	for i in range(themes.size()):
		var th: Dictionary = themes[i]
		var py := start_y + i * (panel_h + panel_gap)
		_draw_theme_row(canvas, font_bold, font_regular, raw_base, raw_shadow, face_cat, face_bamboo, face_east, th, col_x, py, panel_w, panel_h)

	var real_out := ProjectSettings.globalize_path(OUTPUT_PATH)
	canvas.save_png(real_out)
	print("Theme switcher preview saved successfully: ", real_out)
	quit()


func _draw_pause_menu_card(dest: Image, font_bold: Font, font_reg: Font, x: int, y: int, w: int, h: int) -> void:
	# Card background with border
	_draw_rounded_rect(dest, x, y, w, h, 14, Color("071e1a"), Color("d6a83a"), 3)

	# Title "PAUSED"
	var title_text := "PAUSED"
	_draw_text_centered(dest, font_bold, title_text, x, y + 54, w, 32, Color("f5e4a4"))

	# Divider line
	_fill_rect(dest, x + 24, y + 80, w - 48, 2, Color("9f7b28"))

	# Sound toggle button
	var btn_w := w - 48
	var btn_h := 56
	var btn_x := x + 24
	var curr_y := y + 104
	_draw_rounded_rect(dest, btn_x, curr_y, btn_w, btn_h, 8, Color("0b2520"), Color("426b52"), 2)
	_draw_text_centered(dest, font_reg, "SOUND    ON", btn_x, curr_y + 36, btn_w, 22, Color("f2e8c8"))

	# Haptics toggle button
	curr_y += btn_h + 14
	_draw_rounded_rect(dest, btn_x, curr_y, btn_w, btn_h, 8, Color("0b2520"), Color("426b52"), 2)
	_draw_text_centered(dest, font_reg, "HAPTICS    ON", btn_x, curr_y + 36, btn_w, 22, Color("f2e8c8"))

	# THEME SWITCHER BUTTON (Hero feature highlighted with gold glow / border)
	curr_y += btn_h + 14
	_draw_rounded_rect(dest, btn_x, curr_y, btn_w, btn_h, 8, Color("143830"), Color("00f0ff"), 3) # Glowing cyan border
	_draw_text_centered(dest, font_bold, "THEME: NEON NIGHTS", btn_x, curr_y + 36, btn_w, 22, Color("39d6c5"))

	# Resume button
	curr_y += btn_h + 18
	_draw_rounded_rect(dest, btn_x, curr_y, btn_w, btn_h + 4, 8, Color("102c27"), Color("9f7b28"), 2)
	_draw_text_centered(dest, font_bold, "RESUME", btn_x, curr_y + 38, btn_w, 23, Color("f5e4a4"))

	# Restart button
	curr_y += btn_h + 16
	_draw_rounded_rect(dest, btn_x, curr_y, btn_w, btn_h + 4, 8, Color("102c27"), Color("9f7b28"), 2)
	_draw_text_centered(dest, font_bold, "RESTART GAME", btn_x, curr_y + 38, btn_w, 23, Color("f5e4a4"))

	# Return to Town button
	curr_y += btn_h + 16
	_draw_rounded_rect(dest, btn_x, curr_y, btn_w, btn_h + 4, 8, Color("102c27"), Color("9f7b28"), 2)
	_draw_text_centered(dest, font_bold, "RETURN TO TOWN", btn_x, curr_y + 38, btn_w, 23, Color("f5e4a4"))

	# Subtext caption at bottom of card
	_draw_text_centered(dest, font_reg, "Instant Dynamic Runtime Swapping", x, y + h - 22, w, 15, Color("76a896"))


func _draw_theme_row(dest: Image, font_bold: Font, font_reg: Font, base: Image, shadow: Image, f1: Image, f2: Image, f3: Image, th: Dictionary, x: int, y: int, w: int, h: int) -> void:
	# Row backdrop
	_draw_rounded_rect(dest, x, y, w, h, 10, Color("0f1d1d"), Color("24423c"), 2)

	# Mini background texture snippet (left badge: 140 x (h - 16))
	var bg_raw := Image.load_from_file(th.bg_path)
	if bg_raw != null:
		bg_raw.convert(Image.FORMAT_RGBA8)
		bg_raw.resize(180, h - 16, Image.INTERPOLATE_LANCZOS)
		_composite_alpha(dest, bg_raw, x + 8, y + 8)

	# Mini board tray snippet inside the background
	var tray_raw := Image.load_from_file(th.tray_path)
	if tray_raw != null:
		tray_raw.convert(Image.FORMAT_RGBA8)
		tray_raw.resize(164, h - 32, Image.INTERPOLATE_LANCZOS)
		_composite_alpha(dest, tray_raw, x + 16, y + 16)

	# Info text
	var text_x := x + 210
	_draw_text_left(dest, font_bold, th.name, text_x, y + 36, 24, Color("f5e4a4"))
	_draw_text_left(dest, font_reg, th.desc, text_x, y + 68, 17, Color("a8c8ba"))

	var badge_text: String = "ACTIVE THEME" if th.id == "neon_nights" else "ONE-TAP SWITCH"
	var badge_col: Color = Color("00f0ff") if th.id == "neon_nights" else Color("688878")
	_draw_text_left(dest, font_bold, badge_text, text_x, y + 104, 15, badge_col)

	# Render 3 sample tiles clustered on the right side of the row
	var tw := 68
	var th_h := 102
	var tile_start_x := x + w - 260
	var tile_y := y + 22

	var mini_base := base.duplicate()
	mini_base.resize(tw, th_h, Image.INTERPOLATE_LANCZOS)
	var mini_shadow := shadow.duplicate() if shadow != null else null
	if mini_shadow != null:
		mini_shadow.resize(tw, th_h, Image.INTERPOLATE_LANCZOS)

	var faces := [f1, f2, f3]
	for idx in range(3):
		var tx := tile_start_x + idx * (tw + 12)
		var t_img := _render_mini_tile(mini_base, faces[idx], th)
		if mini_shadow != null:
			_composite_shadow(dest, mini_shadow, tx + 4, tile_y + 8, 0.45)
		_composite_alpha(dest, t_img, tx, tile_y)


func _render_mini_tile(base: Image, face: Image, th: Dictionary) -> Image:
	var w: int = base.get_width()
	var h: int = base.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tint: Color = th.base_tint
	var rim: Color = th.neon_rim

	for y in range(h):
		for x in range(w):
			var c: Color = base.get_pixel(x, y)
			if c.a <= 0.001: continue
			var col: Color
			if th.id == "neon_nights":
				var lum: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				var dark_lum := pow(lum, 1.4) * 0.35 + 0.04
				col = Color(dark_lum * tint.r * 2.0, dark_lum * tint.g * 2.0, dark_lum * tint.b * 2.5, c.a)
			else:
				col = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)

			if rim.a > 0.0:
				var is_edge: bool = (x < 4 or x > w - 5 or y < 4 or y > h - 7) and c.a > 0.5
				if is_edge:
					col = col.lerp(rim, rim.a * 0.7)
			out.set_pixel(x, y, col)

	# Overlay face
	if face != null:
		var fw := int(w * 0.68)
		var fh := int(h * 0.68)
		var mini_face := face.duplicate()
		mini_face.resize(fw, fh, Image.INTERPOLATE_LANCZOS)
		var fx := (w - fw) / 2
		var fy := (h - fh) / 2 - 2
		for y in range(fh):
			for x in range(fw):
				var fc: Color = mini_face.get_pixel(x, y)
				if fc.a <= 0.001: continue
				var dx: int = fx + x
				var dy: int = fy + y
				if dx >= 0 and dx < w and dy >= 0 and dy < h:
					var bc: Color = out.get_pixel(dx, dy)
					out.set_pixel(dx, dy, bc.blend(fc))
	return out


func _draw_rounded_rect(dest: Image, x: int, y: int, w: int, h: int, radius: int, fill: Color, border: Color, border_w: int) -> void:
	for dy in range(h):
		var py := y + dy
		if py < 0 or py >= dest.get_height(): continue
		for dx in range(w):
			var px := x + dx
			if px < 0 or px >= dest.get_width(): continue
			# Check corner radius
			var corner_dist := 0.0
			if dx < radius and dy < radius:
				corner_dist = Vector2(radius - dx, radius - dy).length()
			elif dx >= w - radius and dy < radius:
				corner_dist = Vector2(dx - (w - radius - 1), radius - dy).length()
			elif dx < radius and dy >= h - radius:
				corner_dist = Vector2(radius - dx, dy - (h - radius - 1)).length()
			elif dx >= w - radius and dy >= h - radius:
				corner_dist = Vector2(dx - (w - radius - 1), dy - (h - radius - 1)).length()

			if corner_dist > radius:
				continue
			var is_border := (corner_dist > radius - border_w) or dx < border_w or dx >= w - border_w or dy < border_w or dy >= h - border_w
			dest.set_pixel(px, py, border if is_border else fill)


func _fill_rect(dest: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for dy in range(h):
		var py := y + dy
		if py < 0 or py >= dest.get_height(): continue
		for dx in range(w):
			var px := x + dx
			if px < 0 or px >= dest.get_width(): continue
			dest.set_pixel(px, py, color)


func _draw_text_centered(dest: Image, font: Font, text: String, x: int, baseline_y: int, width: int, size: int, color: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var start_x := x + int((width - tw) * 0.5)
	font.draw_string(dest.get_rid(), Vector2(start_x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_text_left(dest: Image, font: Font, text: String, x: int, baseline_y: int, size: int, color: Color) -> void:
	font.draw_string(dest.get_rid(), Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _composite_alpha(dest: Image, src: Image, x: int, y: int) -> void:
	var sw: int = src.get_width()
	var sh: int = src.get_height()
	var dw: int = dest.get_width()
	var dh: int = dest.get_height()
	for sy in range(sh):
		var dy: int = y + sy
		if dy < 0 or dy >= dh: continue
		for sx in range(sw):
			var dx: int = x + sx
			if dx < 0 or dx >= dw: continue
			var sc: Color = src.get_pixel(sx, sy)
			if sc.a <= 0.001: continue
			var dc: Color = dest.get_pixel(dx, dy)
			dest.set_pixel(dx, dy, dc.blend(sc))


func _composite_shadow(dest: Image, shadow: Image, x: int, y: int, opacity: float = 0.5) -> void:
	var sw: int = shadow.get_width()
	var sh: int = shadow.get_height()
	var dw: int = dest.get_width()
	var dh: int = dest.get_height()
	for sy in range(sh):
		var dy: int = y + sy
		if dy < 0 or dy >= dh: continue
		for sx in range(sw):
			var dx: int = x + sx
			if dx < 0 or dx >= dw: continue
			var sc: Color = shadow.get_pixel(sx, sy)
			if sc.a <= 0.001: continue
			var dc: Color = dest.get_pixel(dx, dy)
			var shadow_col := Color(0.01, 0.01, 0.02, sc.a * opacity)
			dest.set_pixel(dx, dy, dc.blend(shadow_col))
