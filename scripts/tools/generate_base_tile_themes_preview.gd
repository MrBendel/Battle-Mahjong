extends SceneTree

const BASE_PATH := "res://game-assets/tiles/default/bases/tile_base_portrait.png"
const BACK_PATH := "res://game-assets/tiles/default/backs/tile_back_portrait.png"
const FACES_DIR := "res://game-assets/tiles/default/faces"
const OUTPUT_PATH := "C:/Users/andre/.gemini/antigravity/brain/fa260e08-55a8-46c3-84df-15f95842b4f1/base_tile_themes_preview.png"

# Safe area in 1024x1536: [152, 190, 720, 1050]
const SAFE_X := 152
const SAFE_Y := 190
const SAFE_W := 720
const SAFE_H := 1050

func _init() -> void:
	print("Generating base tile theme previews...")
	var raw_base := Image.load_from_file(BASE_PATH)
	var raw_back := Image.load_from_file(BACK_PATH)
	if raw_base == null:
		printerr("Failed to load tile base from ", BASE_PATH)
		quit(1)
		return
	raw_base.convert(Image.FORMAT_RGBA8)
	if raw_back != null:
		raw_back.convert(Image.FORMAT_RGBA8)

	# We'll work at 512x768 scale for high fidelity
	var target_w := 256
	var target_h := 384
	var base_img := raw_base.duplicate()
	base_img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)

	var back_img: Image = null
	if raw_back != null:
		back_img = raw_back.duplicate()
		back_img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)

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

	# Themes to showcase:
	# 1. Classic Ivory (Default)
	# 2. Midnight Obsidian / Neon Nights
	# 3. Imperial Jade
	# 4. Kawaii Bubblegum Pop
	# 5. Vintage Washi Manga
	var themes := [
		{
			"id": "classic_ivory",
			"name": "CLASSIC IVORY",
			"subtitle": "Warm porcelain ceramic + deep manga ink",
			"base_tint": Color(1.0, 1.0, 1.0, 1.0),
			"invert_face": false,
			"face_tint": Color(1.0, 1.0, 1.0, 1.0),
			"neon_rim": Color(0, 0, 0, 0),
			"bg_gradient": [Color("16181f"), Color("0e1015")]
		},
		{
			"id": "neon_nights",
			"name": "NEON NIGHTS",
			"subtitle": "Obsidian matte stone + electric cyber glow",
			"base_tint": Color(0.18, 0.19, 0.24, 1.0),
			"invert_face": false,
			"neon_face": true,
			"face_tint": Color(1.3, 1.2, 1.5, 1.0),
			"neon_rim": Color(0.0, 0.95, 1.0, 0.9), # Cyan neon bevel
			"bg_gradient": [Color("101424"), Color("070a12")]
		},
		{
			"id": "imperial_jade",
			"name": "IMPERIAL JADE",
			"subtitle": "Translucent polished jadeite + antique gold",
			"base_tint": Color(0.32, 0.62, 0.48, 1.0),
			"invert_face": false,
			"face_tint": Color(1.05, 0.98, 0.88, 1.0),
			"neon_rim": Color(1.0, 0.84, 0.25, 0.75), # Gold leaf rim
			"bg_gradient": [Color("0c1a14"), Color("050e0a")]
		},
		{
			"id": "kawaii_pop",
			"name": "KAWAII POP",
			"subtitle": "Pastel strawberry milk + glossy candy bevel",
			"base_tint": Color(1.0, 0.86, 0.92, 1.0),
			"invert_face": false,
			"face_tint": Color(1.0, 0.95, 0.98, 1.0),
			"neon_rim": Color(1.0, 0.45, 0.75, 0.6), # Strawberry pink rim
			"bg_gradient": [Color("1f121a"), Color("120910")]
		},
		{
			"id": "vintage_washi",
			"name": "VINTAGE WASHI",
			"subtitle": "Fibrous aged parchment + woodblock sepia",
			"base_tint": Color(0.92, 0.86, 0.76, 1.0),
			"invert_face": false,
			"face_tint": Color(0.95, 0.88, 0.80, 1.0),
			"neon_rim": Color(0.48, 0.38, 0.28, 0.5), # Sepia wood rim
			"bg_gradient": [Color("1a1815"), Color("100e0c")]
		}
	]

	# Layout:
	# 5 rows (one per theme), each row has:
	# - Theme Label / Description card on the left (width: 320px)
	# - 4 face tiles (Cat, Bamboo 1, East, Dot 1)
	# - 1 tile back (to show backing theming)
	var col_card_w := 340
	var tile_spacing := 24
	var row_height := target_h + 36
	var num_tiles := 5 # 4 faces + 1 back
	var canvas_w := 40 + col_card_w + 30 + num_tiles * target_w + (num_tiles - 1) * tile_spacing + 40
	var canvas_h := 80 + themes.size() * row_height + 40

	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("08090c"))

	# Header bar
	_draw_header(canvas, canvas_w, 80)

	var start_y := 90
	for t_idx in range(themes.size()):
		var th: Dictionary = themes[t_idx]
		var y_pos: int = start_y + t_idx * row_height

		# Draw row background card
		_draw_row_card(canvas, 20, y_pos, canvas_w - 40, row_height - 12, th)

		# Draw the 4 face tiles
		var start_tile_x: int = 40 + col_card_w + 30
		for f_idx in range(face_images.size()):
			var tx: int = start_tile_x + f_idx * (target_w + tile_spacing)
			var ty: int = y_pos + 12
			var rendered_tile := _render_themed_tile(base_img, face_images[f_idx], th)
			_composite_alpha(canvas, rendered_tile, tx, ty)

		# Draw 5th tile: The Back
		var back_x: int = start_tile_x + 4 * (target_w + tile_spacing)
		var back_y: int = y_pos + 12
		var rendered_back := _render_themed_back(back_img if back_img != null else base_img, th)
		_composite_alpha(canvas, rendered_back, back_x, back_y)

	var err := canvas.save_png(OUTPUT_PATH)
	if err == OK:
		print("Successfully generated theme preview: ", OUTPUT_PATH)
	else:
		printerr("Failed to save image: ", err)
	quit(0)

func _render_themed_tile(base: Image, face: Image, th: Dictionary) -> Image:
	var w: int = base.get_width()
	var h: int = base.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tint: Color = th.base_tint
	var rim_color: Color = th.get("neon_rim", Color(0,0,0,0))
	var is_neon: bool = th.get("neon_face", false)

	# 1. Process base
	for y in range(h):
		for x in range(w):
			var c := base.get_pixel(x, y)
			if c.a <= 0.001:
				continue
			var tinted: Color
			if is_neon:
				# Dark obsidian face, preserve luminance variations for bevel
				var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				var dark_lum := pow(lum, 1.4) * 0.35 + 0.04
				tinted = Color(dark_lum * tint.r * 2.0, dark_lum * tint.g * 2.0, dark_lum * tint.b * 2.5, c.a)
			else:
				# Multiply tint
				tinted = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
			
			# Add neon edge glow if specified
			if rim_color.a > 0.0:
				# Bevel rim detection: near border or high bevel contrast
				var is_edge: bool = (x < 14 or x > w - 16 or y < 14 or y > h - 24) and c.a > 0.5
				if is_edge:
					tinted = tinted.lerp(rim_color, rim_color.a * 0.55)
			out.set_pixel(x, y, tinted)

	# 2. Composite Face
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
				# Convert face ink to glowing neon colors!
				var lum: float = fc.r * 0.299 + fc.g * 0.587 + fc.b * 0.114
				if lum < 0.3:
					# Dark outlines in neon nights become electric cyan/magenta glow
					fc = Color(0.0, 0.95, 1.0, fc.a * 0.9)
				else:
					# Bright elements get boosted saturation
					fc = Color(fc.r * 1.3, fc.g * 1.2, fc.b * 1.4, fc.a)
			elif th.id == "imperial_jade":
				# Jade tint: dark lines become deep forest ink, red becomes coral vermillion
				var lum: float = fc.r * 0.299 + fc.g * 0.587 + fc.b * 0.114
				if lum < 0.25:
					fc = Color(0.06, 0.18, 0.12, fc.a)
			elif th.id == "kawaii_pop":
				# Pastel tint: dark lines become berry purple
				var lum: float = fc.r * 0.299 + fc.g * 0.587 + fc.b * 0.114
				if lum < 0.25:
					fc = Color(0.35, 0.12, 0.22, fc.a)

			var base_c: Color = out.get_pixel(dest_x, dest_y)
			var blended: Color = base_c.blend(fc)
			out.set_pixel(dest_x, dest_y, blended)

	return out

func _render_themed_back(back: Image, th: Dictionary) -> Image:
	var w: int = back.get_width()
	var h: int = back.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tint: Color = th.base_tint

	for y in range(h):
		for x in range(w):
			var c := back.get_pixel(x, y)
			if c.a <= 0.001:
				continue
			var tinted: Color
			if th.id == "neon_nights":
				# Dark cyber back with violet glow
				tinted = Color(c.r * 0.35 + 0.15, c.g * 0.1 + 0.05, c.b * 0.5 + 0.25, c.a)
			elif th.id == "imperial_jade":
				# Jade back
				tinted = Color(c.r * 0.4 + 0.05, c.g * 0.75 + 0.1, c.b * 0.5 + 0.1, c.a)
			elif th.id == "kawaii_pop":
				# Bubblegum pink back
				tinted = Color(1.0, 0.65, 0.80, c.a)
			elif th.id == "vintage_washi":
				# Antique wooden back
				tinted = Color(0.68, 0.50, 0.35, c.a)
			else:
				# Classic terracotta
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
			var sc := src.get_pixel(sx, sy)
			if sc.a <= 0.001:
				continue
			var dc := dest.get_pixel(dx, dy)
			dest.set_pixel(dx, dy, dc.blend(sc))

func _draw_header(canvas: Image, w: int, h: int) -> void:
	for y in range(h):
		var v := float(y) / float(h)
		for x in range(w):
			var c := Color("0d0f14").lerp(Color("161922"), v)
			canvas.set_pixel(x, y, c)
	# Accent bottom line
	for x in range(w):
		canvas.set_pixel(x, h - 1, Color("ff2a85"))
		canvas.set_pixel(x, h - 2, Color("00f0ff"))

func _draw_row_card(canvas: Image, x: int, y: int, w: int, h: int, th: Dictionary) -> void:
	var bg_colors: Array = th.get("bg_gradient", [Color("151720"), Color("0e1015")])
	var c_top: Color = bg_colors[0]
	var c_bot: Color = bg_colors[1]
	for py in range(h):
		var v := float(py) / float(h)
		var c := c_top.lerp(c_bot, v)
		for px in range(w):
			canvas.set_pixel(x + px, y + py, c)
	# Border
	var border_color: Color = th.get("neon_rim", Color(0.3, 0.35, 0.4, 0.5))
	if border_color.a <= 0.01:
		border_color = Color(0.25, 0.28, 0.35, 0.6)
	for px in range(w):
		canvas.set_pixel(x + px, y, border_color)
		canvas.set_pixel(x + px, y + h - 1, border_color)
	for py in range(h):
		canvas.set_pixel(x, y + py, border_color)
		canvas.set_pixel(x + w - 1, y + py, border_color)

	# Left Theme Card Swatches & Accents
	var card_x := x + 24
	var card_y := y + 24
	var card_w := 280
	var card_h := h - 48

	# Accent vertical bar
	var bar_color: Color = th.base_tint
	if th.id == "neon_nights":
		bar_color = Color("00f0ff")
	for by in range(card_h):
		for bx in range(6):
			canvas.set_pixel(card_x + bx, card_y + by, bar_color)

	# Swatch boxes (Base Color, Rim Color, Ink Tone)
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
