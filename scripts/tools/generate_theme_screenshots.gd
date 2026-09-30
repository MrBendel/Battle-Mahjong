extends SceneTree

const BASE_PATH := "res://game-assets/tiles/default/bases/tile_base_portrait.png"
const BACK_PATH := "res://game-assets/tiles/default/backs/tile_back_portrait.png"
const FACES_DIR := "res://game-assets/tiles/default/faces"
const SHADOW_PATH := "res://game-assets/tiles/default/tile_shadow_soft.png"

const SPECIMEN_OUTPUT := "res://docs/screenshots/base_tile_themes_specimen.png"
const IN_ACTION_OUTPUT := "res://docs/screenshots/themed_tiles_in_action.png"

const SAFE_X := 152
const SAFE_Y := 190
const SAFE_W := 720
const SAFE_H := 1050

func _init() -> void:
	print("Generating theme screenshots for PR...")
	var raw_base := Image.load_from_file(BASE_PATH)
	var raw_back := Image.load_from_file(BACK_PATH)
	var raw_shadow := Image.load_from_file(SHADOW_PATH)

	if raw_base == null or raw_back == null:
		printerr("Failed to load base or back images.")
		quit(1)
		return
	raw_base.convert(Image.FORMAT_RGBA8)
	raw_back.convert(Image.FORMAT_RGBA8)
	if raw_shadow != null:
		raw_shadow.convert(Image.FORMAT_RGBA8)

	var target_w := 256
	var target_h := 384
	var base_img := raw_base.duplicate()
	base_img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
	var back_img := raw_back.duplicate()
	back_img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
	var shadow_img := raw_shadow.duplicate() if raw_shadow != null else null
	if shadow_img != null:
		shadow_img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)

	var face_names := ["mascot_cat", "bamboo_1", "east", "dots_1"]
	var face_images: Array[Image] = []
	for fn in face_names:
		var p := "%s/%s.png" % [FACES_DIR, fn]
		var f := Image.load_from_file(p)
		if f != null:
			f.convert(Image.FORMAT_RGBA8)
			face_images.append(f)
		else:
			printerr("Missing face: ", p)

	var themes := [
		{
			"id": "classic_ivory",
			"name": "CLASSIC IVORY",
			"subtitle": "Warm porcelain ceramic + deep manga ink",
			"base_tint": Color(1.0, 1.0, 1.0, 1.0),
			"face_tint": Color(1.0, 1.0, 1.0, 1.0),
			"neon_rim": Color(0, 0, 0, 0),
			"selection_glow": Color(1.0, 0.82, 0.25, 0.50),
			"bg_gradient": [Color("16181f"), Color("0e1015")]
		},
		{
			"id": "neon_nights",
			"name": "NEON NIGHTS",
			"subtitle": "Obsidian matte stone + electric cyber glow",
			"base_tint": Color(0.22, 0.23, 0.28, 1.0),
			"neon_face": true,
			"face_tint": Color(1.0, 1.0, 1.0, 1.0),
			"neon_rim": Color(0.0, 0.95, 1.0, 0.90),
			"selection_glow": Color(0.0, 0.95, 1.0, 0.70),
			"bg_gradient": [Color("101424"), Color("070a12")]
		},
		{
			"id": "imperial_jade",
			"name": "IMPERIAL JADE",
			"subtitle": "Translucent polished jadeite + antique gold",
			"base_tint": Color(0.32, 0.62, 0.48, 1.0),
			"face_tint": Color(1.0, 0.98, 0.92, 1.0),
			"neon_rim": Color(1.0, 0.84, 0.25, 0.75),
			"selection_glow": Color(1.0, 0.84, 0.25, 0.60),
			"bg_gradient": [Color("0c1a14"), Color("050e0a")]
		},
		{
			"id": "kawaii_pop",
			"name": "KAWAII POP",
			"subtitle": "Pastel strawberry milk + glossy candy bevel",
			"base_tint": Color(1.0, 0.86, 0.92, 1.0),
			"face_tint": Color(1.0, 0.96, 0.98, 1.0),
			"neon_rim": Color(1.0, 0.45, 0.75, 0.60),
			"selection_glow": Color(1.0, 0.35, 0.70, 0.55),
			"bg_gradient": [Color("1f121a"), Color("120910")]
		},
		{
			"id": "vintage_washi",
			"name": "VINTAGE WASHI",
			"subtitle": "Fibrous aged parchment + woodblock sepia",
			"base_tint": Color(0.92, 0.86, 0.76, 1.0),
			"face_tint": Color(0.95, 0.90, 0.84, 1.0),
			"neon_rim": Color(0.48, 0.38, 0.28, 0.50),
			"selection_glow": Color(0.95, 0.65, 0.30, 0.50),
			"bg_gradient": [Color("1a1815"), Color("100e0c")]
		}
	]

	# --- SCREENSHOT 1: SPECIMEN GRID ---
	_build_specimen_screenshot(base_img, back_img, face_images, themes, target_w, target_h)

	# --- SCREENSHOT 2: THEMED TILES IN ACTION (STACKED BOARD CLUSTERS) ---
	_build_in_action_screenshot(base_img, shadow_img, face_images, themes, target_w, target_h)

	print("Screenshots generation complete.")
	quit(0)

func _build_specimen_screenshot(base_img: Image, back_img: Image, face_images: Array[Image], themes: Array, target_w: int, target_h: int) -> void:
	var col_card_w := 340
	var tile_spacing := 24
	var row_height := target_h + 36
	var num_tiles := 5 # 4 faces + 1 back
	var canvas_w := 40 + col_card_w + 30 + num_tiles * target_w + (num_tiles - 1) * tile_spacing + 40
	var canvas_h := 80 + themes.size() * row_height + 40

	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("08090c"))

	_draw_header(canvas, canvas_w, 80)

	var start_y := 90
	for t_idx in range(themes.size()):
		var th: Dictionary = themes[t_idx]
		var y_pos: int = start_y + t_idx * row_height

		_draw_row_card(canvas, 20, y_pos, canvas_w - 40, row_height - 12, th)

		var start_tile_x: int = 40 + col_card_w + 30
		for f_idx in range(face_images.size()):
			var tx: int = start_tile_x + f_idx * (target_w + tile_spacing)
			var ty: int = y_pos + 12
			var rendered_tile := _render_themed_tile(base_img, face_images[f_idx], th, false, false)
			_composite_alpha(canvas, rendered_tile, tx, ty)

		var back_x: int = start_tile_x + 4 * (target_w + tile_spacing)
		var back_y: int = y_pos + 12
		var rendered_back := _render_themed_back(back_img, th)
		_composite_alpha(canvas, rendered_back, back_x, back_y)

	var real_path := ProjectSettings.globalize_path(SPECIMEN_OUTPUT)
	canvas.save_png(real_path)
	print("Saved specimen screenshot: ", real_path)

func _build_in_action_screenshot(base_img: Image, shadow_img: Image, face_images: Array[Image], themes: Array, target_w: int, target_h: int) -> void:
	# Show 4 prominent themes side-by-side in stacked 3D mahjong clusters:
	# Classic Ivory, Neon Nights, Imperial Jade, Kawaii Pop
	var showcase_themes := [themes[0], themes[1], themes[2], themes[3]]
	var cluster_w := 420
	var cluster_h := 620
	var spacing := 36
	var canvas_w := 40 + showcase_themes.size() * (cluster_w + spacing) + 4
	var canvas_h := cluster_h + 100

	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("07080b"))

	for c_idx in range(showcase_themes.size()):
		var th: Dictionary = showcase_themes[c_idx]
		var cx: int = 40 + c_idx * (cluster_w + spacing)
		var cy: int = 40

		# Card panel
		_draw_cluster_card(canvas, cx, cy, cluster_w, cluster_h, th)

		# Render a 3-layer pyramid cluster of tiles:
		# Layer 0 (bottom): 2 tiles side-by-side (blocked, darker)
		# Layer 1 (middle): 1 tile overlapping (blocked)
		# Layer 2 (top): 1 tile on top (selectable with glowing neon rim)
		var scale_factor := 0.62
		var tw := int(target_w * scale_factor)
		var th_scaled := int(target_h * scale_factor)

		var mini_base := base_img.duplicate()
		mini_base.resize(tw, th_scaled, Image.INTERPOLATE_LANCZOS)
		var mini_shadow := shadow_img.duplicate() if shadow_img != null else null
		if mini_shadow != null:
			mini_shadow.resize(tw, th_scaled, Image.INTERPOLATE_LANCZOS)

		var center_x := cx + cluster_w / 2
		var start_board_y := cy + 130

		# Layer 0: Two bottom tiles
		var l0_y := start_board_y + 110
		var l0_x1 := center_x - tw + 10
		var l0_x2 := center_x - 10
		var t_bottom1 := _render_themed_tile(mini_base, face_images[1], th, true, false, 0.70)
		var t_bottom2 := _render_themed_tile(mini_base, face_images[2], th, true, false, 0.70)

		if mini_shadow != null:
			_composite_shadow(canvas, mini_shadow, l0_x1 + 6, l0_y + 16, 0.50)
			_composite_shadow(canvas, mini_shadow, l0_x2 + 6, l0_y + 16, 0.50)
		_composite_alpha(canvas, t_bottom1, l0_x1, l0_y)
		_composite_alpha(canvas, t_bottom2, l0_x2, l0_y)

		# Layer 1: Middle tile
		var l1_x := center_x - tw / 2
		var l1_y := start_board_y + 55
		var t_mid := _render_themed_tile(mini_base, face_images[3], th, true, false, 0.85)
		if mini_shadow != null:
			_composite_shadow(canvas, mini_shadow, l1_x + 6, l1_y + 18, 0.55)
		_composite_alpha(canvas, t_mid, l1_x, l1_y)

		# Layer 2: Top tile (Selectable + Active Glow Halo)
		var l2_x := center_x - tw / 2
		var l2_y := start_board_y
		var t_top := _render_themed_tile(mini_base, face_images[0], th, false, true, 1.0)
		if mini_shadow != null:
			_composite_shadow(canvas, mini_shadow, l2_x + 8, l2_y + 22, 0.65)
		# Selection glow
		_draw_selection_halo(canvas, l2_x, l2_y, tw, th_scaled, th.selection_glow)
		_composite_alpha(canvas, t_top, l2_x, l2_y)

	var real_path := ProjectSettings.globalize_path(IN_ACTION_OUTPUT)
	canvas.save_png(real_path)
	print("Saved in-action screenshot: ", real_path)

func _render_themed_tile(base: Image, face: Image, th: Dictionary, is_blocked: bool = false, is_selected: bool = false, brightness: float = 1.0) -> Image:
	var w: int = base.get_width()
	var h: int = base.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tint: Color = th.base_tint
	var rim_color: Color = th.get("neon_rim", Color(0,0,0,0))
	var is_neon: bool = th.get("neon_face", false)

	for y in range(h):
		for x in range(w):
			var c: Color = base.get_pixel(x, y)
			if c.a <= 0.001:
				continue
			var tinted: Color
			if is_neon:
				var lum: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				var dark_lum := pow(lum, 1.4) * 0.35 + 0.04
				tinted = Color(dark_lum * tint.r * 2.0, dark_lum * tint.g * 2.0, dark_lum * tint.b * 2.5, c.a)
			else:
				tinted = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)

			if rim_color.a > 0.0:
				var is_edge: bool = (x < 10 or x > w - 12 or y < 10 or y > h - 18) and c.a > 0.5
				if is_edge:
					tinted = tinted.lerp(rim_color, rim_color.a * 0.65)

			if is_blocked:
				var gray: float = tinted.r * 0.299 + tinted.g * 0.587 + tinted.b * 0.114
				tinted = tinted.lerp(Color(gray, gray, gray, tinted.a), 0.75) * 0.82

			tinted.r *= brightness
			tinted.g *= brightness
			tinted.b *= brightness
			out.set_pixel(x, y, tinted)

	# Composite face
	var safe_x_scaled: int = int(round(float(SAFE_X) / 1024.0 * float(w)))
	var safe_y_scaled: int = int(round(float(SAFE_Y) / 1536.0 * float(h)))
	var safe_w_scaled: int = int(round(float(SAFE_W) / 1024.0 * float(w)))
	var safe_h_scaled: int = int(round(float(SAFE_H) / 1536.0 * float(h)))

	var face_scaled := face.duplicate()
	face_scaled.resize(safe_w_scaled, safe_h_scaled, Image.INTERPOLATE_LANCZOS)

	for fy in range(safe_h_scaled):
		for fx in range(safe_w_scaled):
			var fc: Color = face_scaled.get_pixel(fx, fy)
			if fc.a <= 0.001:
				continue
			var dest_x: int = safe_x_scaled + fx
			var dest_y: int = safe_y_scaled + fy
			if dest_x >= w or dest_y >= h:
				continue

			if is_neon:
				var lum: float = fc.r * 0.299 + fc.g * 0.587 + fc.b * 0.114
				if lum < 0.3:
					fc = Color(0.0, 0.95, 1.0, fc.a * 0.9)
				else:
					fc = Color(fc.r * 1.3, fc.g * 1.2, fc.b * 1.4, fc.a)
			elif th.id == "imperial_jade":
				var lum: float = fc.r * 0.299 + fc.g * 0.587 + fc.b * 0.114
				if lum < 0.25:
					fc = Color(0.06, 0.18, 0.12, fc.a)
			elif th.id == "kawaii_pop":
				var lum: float = fc.r * 0.299 + fc.g * 0.587 + fc.b * 0.114
				if lum < 0.25:
					fc = Color(0.35, 0.12, 0.22, fc.a)

			if is_blocked:
				var gray: float = fc.r * 0.299 + fc.g * 0.587 + fc.b * 0.114
				fc = fc.lerp(Color(gray, gray, gray, fc.a), 0.75) * 0.82

			fc.r *= brightness
			fc.g *= brightness
			fc.b *= brightness

			var base_c: Color = out.get_pixel(dest_x, dest_y)
			out.set_pixel(dest_x, dest_y, base_c.blend(fc))

	return out

func _render_themed_back(back: Image, th: Dictionary) -> Image:
	var w: int = back.get_width()
	var h: int = back.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tint: Color = th.base_tint

	for y in range(h):
		for x in range(w):
			var c: Color = back.get_pixel(x, y)
			if c.a <= 0.001:
				continue
			var tinted: Color
			if th.id == "neon_nights":
				tinted = Color(c.r * 0.35 + 0.15, c.g * 0.1 + 0.05, c.b * 0.5 + 0.25, c.a)
			elif th.id == "imperial_jade":
				tinted = Color(c.r * 0.4 + 0.05, c.g * 0.75 + 0.1, c.b * 0.5 + 0.1, c.a)
			elif th.id == "kawaii_pop":
				tinted = Color(1.0, 0.65, 0.80, c.a)
			elif th.id == "vintage_washi":
				tinted = Color(0.68, 0.50, 0.35, c.a)
			else:
				tinted = c
			out.set_pixel(x, y, tinted)
	return out

func _composite_alpha(dest: Image, src: Image, x: int, y: int) -> void:
	var sw: int = src.get_width()
	var sh: int = src.get_height()
	var dw: int = dest.get_width()
	var dh: int = dest.get_height()
	for sy in range(sh):
		var dy: int = y + sy
		if dy < 0 or dy >= dh:
			continue
		for sx in range(sw):
			var dx: int = x + sx
			if dx < 0 or dx >= dw:
				continue
			var sc: Color = src.get_pixel(sx, sy)
			if sc.a <= 0.001:
				continue
			var dc: Color = dest.get_pixel(dx, dy)
			dest.set_pixel(dx, dy, dc.blend(sc))

func _composite_shadow(dest: Image, shadow: Image, x: int, y: int, opacity: float = 0.55) -> void:
	var sw: int = shadow.get_width()
	var sh: int = shadow.get_height()
	var dw: int = dest.get_width()
	var dh: int = dest.get_height()
	for sy in range(sh):
		var dy: int = y + sy
		if dy < 0 or dy >= dh:
			continue
		for sx in range(sw):
			var dx: int = x + sx
			if dx < 0 or dx >= dw:
				continue
			var sc: Color = shadow.get_pixel(sx, sy)
			if sc.a <= 0.001:
				continue
			var dc: Color = dest.get_pixel(dx, dy)
			var shadow_col := Color(0.02, 0.02, 0.04, sc.a * opacity)
			dest.set_pixel(dx, dy, dc.blend(shadow_col))

func _draw_selection_halo(dest: Image, x: int, y: int, w: int, h: int, glow_color: Color) -> void:
	var margin := 8
	var rx: int = x - margin
	var ry: int = y - margin
	var rw: int = w + margin * 2
	var rh: int = h + margin * 2
	var dw: int = dest.get_width()
	var dh: int = dest.get_height()

	for py in range(rh):
		var dy: int = ry + py
		if dy < 0 or dy >= dh:
			continue
		for px in range(rw):
			var dx: int = rx + px
			if dx < 0 or dx >= dw:
				continue
			# Distance to inner rect
			var dist_x: float = maxf(0.0, maxf(float(rx + margin - dx), float(dx - (rx + rw - margin))))
			var dist_y: float = maxf(0.0, maxf(float(ry + margin - dy), float(dy - (ry + rh - margin))))
			var dist: float = sqrt(dist_x * dist_x + dist_y * dist_y)
			if dist <= float(margin) and dist > 0.5:
				var falloff: float = 1.0 - (dist / float(margin))
				var halo := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * falloff * 0.75)
				var dc: Color = dest.get_pixel(dx, dy)
				dest.set_pixel(dx, dy, dc.blend(halo))

func _draw_header(canvas: Image, w: int, h: int) -> void:
	for y in range(h):
		var v: float = float(y) / float(h)
		for x in range(w):
			var c: Color = Color("0d0f14").lerp(Color("161922"), v)
			canvas.set_pixel(x, y, c)
	for x in range(w):
		canvas.set_pixel(x, h - 1, Color("ff2a85"))
		canvas.set_pixel(x, h - 2, Color("00f0ff"))

func _draw_row_card(canvas: Image, x: int, y: int, w: int, h: int, th: Dictionary) -> void:
	var bg_colors: Array = th.get("bg_gradient", [Color("151720"), Color("0e1015")])
	var c_top: Color = bg_colors[0]
	var c_bot: Color = bg_colors[1]
	for py in range(h):
		var v: float = float(py) / float(h)
		var c: Color = c_top.lerp(c_bot, v)
		for px in range(w):
			canvas.set_pixel(x + px, y + py, c)
	var border_color: Color = th.get("neon_rim", Color(0.3, 0.35, 0.4, 0.5))
	if border_color.a <= 0.01:
		border_color = Color(0.25, 0.28, 0.35, 0.6)
	for px in range(w):
		canvas.set_pixel(x + px, y, border_color)
		canvas.set_pixel(x + px, y + h - 1, border_color)
	for py in range(h):
		canvas.set_pixel(x, y + py, border_color)
		canvas.set_pixel(x + w - 1, y + py, border_color)

	var card_x := x + 24
	var card_y := y + 24
	var card_h := h - 48
	var bar_color: Color = th.base_tint
	if th.id == "neon_nights":
		bar_color = Color("00f0ff")
	for by in range(card_h):
		for bx in range(6):
			canvas.set_pixel(card_x + bx, card_y + by, bar_color)

	var swatches := [
		th.base_tint,
		th.get("neon_rim", Color("1a1a1a")),
		th.get("face_tint", Color.WHITE)
	]
	var swatch_y := card_y + card_h - 48
	for s_idx in range(swatches.size()):
		var sx := card_x + 20 + s_idx * 52
		var sc: Color = swatches[s_idx]
		if sc.a <= 0.01:
			sc = Color("0a0a0e")
		for sy in range(32):
			for sx_box in range(40):
				var is_edge := (sy == 0 or sy == 31 or sx_box == 0 or sx_box == 39)
				var pixel_c := Color.WHITE if is_edge else sc
				canvas.set_pixel(sx + sx_box, swatch_y + sy, pixel_c)

func _draw_cluster_card(canvas: Image, x: int, y: int, w: int, h: int, th: Dictionary) -> void:
	var bg_colors: Array = th.get("bg_gradient", [Color("151720"), Color("0e1015")])
	var c_top: Color = bg_colors[0]
	var c_bot: Color = bg_colors[1]
	for py in range(h):
		var v: float = float(py) / float(h)
		var c: Color = c_top.lerp(c_bot, v)
		for px in range(w):
			canvas.set_pixel(x + px, y + py, c)
	var border_color: Color = th.get("neon_rim", Color(0.25, 0.28, 0.35, 0.6))
	if border_color.a <= 0.01:
		border_color = Color(0.25, 0.28, 0.35, 0.6)
	for px in range(w):
		canvas.set_pixel(x + px, y, border_color)
		canvas.set_pixel(x + px, y + h - 1, border_color)
	for py in range(h):
		canvas.set_pixel(x, y + py, border_color)
		canvas.set_pixel(x + w - 1, y + py, border_color)
