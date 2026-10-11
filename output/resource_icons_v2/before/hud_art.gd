extends Control
## Original, native-resolution pixel ornaments. No reference-game art is used.
var kind := "clock"
var progress := 0.0
var night := false
var weather := "clear"
const INK := Color("422b32")
const GOLD := Color("dfb66f")
const PAPER := Color("f4e5bf")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func _draw() -> void:
	if kind == "book":
		box(0, 0, size.x, size.y, INK)
		box(3, 3, size.x - 6, size.y - 6, Color("81533f"))
		box(8, 7, size.x - 16, size.y - 14, Color("b89167"))
		box(11, 9, size.x / 2 - 14, size.y - 21, Color("ead5aa"))
		box(size.x / 2 + 3, 9, size.x / 2 - 14, size.y - 21, PAPER)
		for y in [size.y - 10, size.y - 7]:
			box(12, y, size.x / 2 - 15, 1, Color("d1b48a"))
			box(size.x / 2 + 4, y, size.x / 2 - 16, 1, Color("d1b48a"))
		box(size.x / 2 - 2, 8, 4, size.y - 16, Color("986a4e"))
		for y in [58, 132, 206]:
			box(size.x / 2 - 8, y, 16, 4, INK)
			box(size.x / 2 - 7, y, 14, 1, GOLD)
		return
	if kind == "clock":
		var points := PackedVector2Array([Vector2(8,0),Vector2(24,0),Vector2(32,8),Vector2(32,24),Vector2(24,32),Vector2(8,32),Vector2(0,24),Vector2(0,8)])
		draw_colored_polygon(points, INK)
		draw_colored_polygon(PackedVector2Array([Vector2(9,3),Vector2(23,3),Vector2(29,9),Vector2(29,23),Vector2(23,29),Vector2(9,29),Vector2(3,23),Vector2(3,9)]), GOLD)
		box(7, 5, 18, 22, Color("63516c") if night else PAPER)
		box(5, 8, 22, 16, Color("63516c") if night else PAPER)
		for point in [Vector2(15,6),Vector2(15,25),Vector2(6,15),Vector2(25,15)]:
			draw_rect(Rect2(point,Vector2(2,2)), GOLD if night else INK)
		var hour_angle := (-PI / 2) + progress * TAU
		var minute_angle := (-PI / 2) + fposmod(progress * 12.0,1.0) * TAU
		draw_line(Vector2(16,16), (Vector2(16,16) + Vector2(cos(minute_angle), sin(minute_angle)) * 9).round(), GOLD if night else INK, 1, false)
		draw_line(Vector2(16,16), (Vector2(16,16) + Vector2(cos(hour_angle), sin(hour_angle)) * 6).round(), GOLD if night else INK, 2, false)
		box(15,15,3,3,Color("bb745d"))
		return
	# All icons occupy a 24 x 24 grid.
	match kind:
		"seed":
			box(5, 5, 14, 17, INK); box(6, 6, 12, 15, Color("caa778"))
			box(6, 7, 12, 3, GOLD); box(8, 12, 8, 7, PAPER)
			box(11, 12, 2, 6, Color("839b63")); box(9, 13, 2, 2, Color("a7ba76")); box(13, 12, 2, 2, Color("839b63"))
		"wand":
			box(10,8,4,15,INK); box(11,9,2,13,Color("b98957"))
			box(7,3,10,7,INK); box(9,1,6,11,INK)
			box(8,4,8,5,Color("8977ad")); box(10,2,4,9,Color("b39dcf"))
			box(10,3,2,4,Color("ede1f3")); box(9,10,6,2,GOLD)
			box(3,4,2,2,PAPER); box(19,7,2,2,GOLD)
		"mushroom":
			box(10,12,5,9,INK); box(11,13,3,7,PAPER)
			box(4,7,16,8,INK); box(7,4,10,3,INK)
			box(5,8,14,5,Color("b96764")); box(8,5,8,3,Color("d48574"))
			box(8,8,3,2,PAPER); box(15,10,2,2,PAPER)
		"berry":
			box(11,3,3,6,INK); box(13,4,6,3,Color("839b63"))
			box(4,10,7,9,INK); box(10,8,8,10,INK); box(9,16,8,6,INK)
			box(5,11,5,7,Color("9e597b")); box(11,9,6,8,Color("bc728e")); box(10,17,6,4,Color("aa5b7a"))
			box(6,11,2,2,PAPER); box(12,10,2,2,PAPER)
		"herb":
			box(11,5,2,17,INK)
			draw_colored_polygon(PackedVector2Array([Vector2(10,14),Vector2(3,11),Vector2(4,4),Vector2(11,7),Vector2(13,14)]),INK)
			draw_colored_polygon(PackedVector2Array([Vector2(13,18),Vector2(13,10),Vector2(21,6),Vector2(20,14)]),INK)
			box(5,6,4,6,Color("839b63")); box(14,11,5,4,Color("a7ba76"))
		"wood":
			box(3,9,18,12,INK); box(4,10,16,10,Color("a4724b")); box(4,7,6,13,Color("d0aa72"))
			box(6,10,3,7,INK); box(7,11,1,5,GOLD); box(12,11,7,2,Color("6c4835")); box(11,16,7,1,Color("6c4835"))
		"ore":
			draw_colored_polygon(PackedVector2Array([Vector2(2,18),Vector2(6,7),Vector2(14,3),Vector2(21,11),Vector2(20,20),Vector2(7,22)]),INK)
			draw_colored_polygon(PackedVector2Array([Vector2(4,17),Vector2(8,8),Vector2(14,5),Vector2(18,11),Vector2(18,18),Vector2(8,19)]),Color("8e8994"))
			box(8,9,4,4,Color("d6b582")); box(14,14,3,3,Color("d6b582"))
		"fish":
			draw_colored_polygon(PackedVector2Array([Vector2(2,8),Vector2(8,12),Vector2(14,6),Vector2(20,9),Vector2(22,13),Vector2(18,18),Vector2(12,18),Vector2(8,15),Vector2(2,19)]),INK)
			box(10,10,10,5,Color("83aaa7")); box(12,8,6,2,Color("b4d1bc")); box(10,15,8,2,PAPER); box(18,10,2,2,INK)
		"iron":
			draw_colored_polygon(PackedVector2Array([Vector2(3,11),Vector2(8,6),Vector2(20,6),Vector2(22,16),Vector2(17,21),Vector2(3,21)]),INK)
			box(5,12,12,7,Color("8f9d9e")); box(9,8,10,3,Color("ccd0bc")); box(18,12,2,5,Color("627d83"))
		"coin":
			box(7,3,10,18,INK); box(4,6,16,12,INK); box(7,5,10,14,GOLD); box(6,7,12,10,GOLD)
			box(10,7,4,10,Color("a97643")); box(11,7,2,8,Color("ffe6a1"))
		"journal":
			box(4,3,16,19,INK); box(6,4,12,16,Color("9e6670")); box(7,4,2,16,Color("d4a578"))
			box(11,8,5,1,PAPER); box(11,11,5,1,PAPER); box(14,17,3,6,Color("839b63"))
		"bag":
			box(8,3,8,7,INK); box(10,5,4,3,GOLD); box(4,8,16,14,INK); box(6,10,12,10,Color("ab7a4e"))
			box(6,14,12,2,GOLD); box(11,13,2,5,PAPER)
		"help":
			box(5,4,14,17,INK); box(7,6,10,13,PAPER); box(10,8,4,2,Color("9e6670")); box(12,10,2,3,Color("9e6670")); box(11,15,2,2,Color("9e6670"))
		"weather":
			if weather == "clear":
				if night:
					box(7,4,9,16,GOLD); box(4,7,3,10,GOLD)
					box(11,4,6,10,Color("ead9b0")); box(15,7,4,6,Color("ead9b0"))
				else:
					box(8,8,8,8,GOLD)
					for p in [Vector2(10,3),Vector2(10,19),Vector2(3,10),Vector2(19,10)]:
						draw_rect(Rect2(p,Vector2(3,3)),GOLD)
			else:
				box(4,7,16,8,Color("a6b8b4")); box(8,4,8,3,Color("d4ddc8"))
				for x in [6,11,16]:
					box(x,17,2,3,Color("8eb1c0") if weather == "rain" else PAPER)
