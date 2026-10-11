extends SceneTree
## Original 4x6 digit glyphs on an 8-pixel line, without fractional scaling.
const GLYPHS := [
	["0110", "1001", "1001", "1001", "1001", "0110"],
	["0100", "1100", "0100", "0100", "0100", "1110"],
	["1110", "0001", "0010", "0100", "1000", "1111"],
	["1110", "0001", "0110", "0001", "0001", "1110"],
	["1001", "1001", "1111", "0001", "0001", "0001"],
	["1111", "1000", "1110", "0001", "0001", "1110"],
	["0111", "1000", "1110", "1001", "1001", "0110"],
	["1111", "0001", "0010", "0100", "0100", "0100"],
	["0110", "1001", "0110", "1001", "1001", "0110"],
	["0110", "1001", "1001", "0111", "0001", "1110"]
]

func _initialize() -> void:
	var atlas := Image.create(80, 8, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var font := FontFile.new()
	font.resource_name = "Walala HUD Digits 8"
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.generate_mipmaps = false
	font.allow_system_fallback = false
	font.fixed_size = 8
	font.set_cache_ascent(0, 8, 7)
	font.set_cache_descent(0, 8, 1)
	for digit in range(GLYPHS.size()):
		for y in range(6):
			for x in range(4):
				if GLYPHS[digit][y][x] == "1": atlas.set_pixel(digit * 8 + x, y, Color.WHITE)
		var code := 48 + digit
		font.set_glyph_advance(0, 8, code, Vector2(5, 0))
		font.set_glyph_offset(0, Vector2i(8, 0), code, Vector2(0, -6))
		font.set_glyph_size(0, Vector2i(8, 0), code, Vector2(4, 6))
		font.set_glyph_uv_rect(0, Vector2i(8, 0), code, Rect2(digit * 8, 0, 4, 6))
		font.set_glyph_texture_idx(0, Vector2i(8, 0), code, 0)
	font.set_texture_image(0, Vector2i(8, 0), 0, atlas)
	var result := ResourceSaver.save(font, "res://Art/Fonts/HudDigits8/digits8.tres")
	print("HUD DIGITS FONT BUILD ", result)
	quit(0 if result == OK else 1)
