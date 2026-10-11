extends Node2D
## Native 640x360 pixel scenery, assembled from the project's original art.
const ART := "res://Art/Environment/Hearthwood/"
const Ambient = preload("res://Scenes/Gameplay/ambient_animation.gd")
const WitchAnimation = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")
const WITCH_ORIGIN := Vector2(463, 312)
var elapsed := 0.0
var stars: Array[Vector2] = []
var witch: Sprite2D

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1024
	for i in range(35):
		stars.append(Vector2(rng.randi_range(12, 628), rng.randi_range(8, 113)))
	_prop("outdoor_pine", Vector2(25, 240), Color("69617b"))
	_prop("town_tree", Vector2(610, 245), Color("948c91"))
	_prop("shop_0", Vector2(111, 285), Color("d5b0b2"))
	_prop("shop_1", Vector2(532, 285), Color("e1b6b6"))
	_prop("outdoor_fence", Vector2(29, 291))
	_prop("outdoor_fence", Vector2(613, 291))
	_prop("outdoor_flowerbed", Vector2(155, 302))
	_prop("planter", Vector2(565, 302))
	_prop("outdoor_lamp", Vector2(204, 287))
	_prop("outdoor_lamp", Vector2(431, 287))
	_prop("outdoor_bench", Vector2(95, 320), Color("c3a7a6"))
	_prop("outdoor_bush", Vector2(20, 350), Color("8e7e8c"))
	_prop("outdoor_bush", Vector2(618, 349), Color("8e7e8c"))
	witch = Sprite2D.new()
	witch.name = "MenuWitch"
	WitchAnimation.configure(witch)
	witch.position = WITCH_ORIGIN
	add_child(witch)

func _prop(kind: String, feet: Vector2, tint: Color = Color.WHITE) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + kind + ".aseprite")
	sprite.position = feet - Vector2(0, sprite.texture.get_height() / 2.0)
	sprite.modulate = tint
	add_child(sprite)
	var animation := Ambient.attach(sprite, kind)
	if animation != null:
		# Neighbouring trees and lamps should not animate in perfect synchrony.
		animation.elapsed = fposmod(feet.x * 0.019 + feet.y * 0.023, animation.frames_per_bank / float(animation.spec.fps))
		animation.update_frame()

func _process(delta: float) -> void:
	elapsed += delta
	_update_witch()
	queue_redraw()

func _update_witch() -> void:
	# A little evening stroll, with long rests between the authored walk cycles.
	var phase := fposmod(elapsed, 18.0)
	witch.position = WITCH_ORIGIN
	witch.frame = WitchAnimation.frame_for("idle", 0, elapsed)
	if phase >= 5.0 and phase < 8.0:
		witch.position.x += roundf((phase - 5.0) * 6.0)
		witch.frame = WitchAnimation.frame_for("walk", 2, phase - 5.0)
	elif phase >= 8.0 and phase < 11.0:
		witch.position.x += 18.0
		witch.frame = WitchAnimation.frame_for("idle", 0, phase - 8.0)
	elif phase >= 11.0 and phase < 14.0:
		witch.position.x += roundf(18.0 - (phase - 11.0) * 6.0)
		witch.frame = WitchAnimation.frame_for("walk", 3, phase - 11.0)

func _draw() -> void:
	# Broad, stepped color bands keep the sunset in the same pixel vocabulary.
	var bands := ["393147", "45364e", "654055", "8c4d60", "b56567", "d58b78", "e9ae85"]
	var edges := [0, 74, 108, 139, 169, 197, 227, 266]
	for i in range(bands.size()):
		draw_rect(Rect2(0, edges[i], 640, edges[i + 1] - edges[i]), Color(bands[i]))
	for i in range(stars.size()):
		var point := stars[i]
		var light := Color("f3c996")
		light.a = 0.3 + 0.4 * (sin(elapsed * 1.2 + i * 2.7) + 1.0) / 2.0
		draw_rect(Rect2(point, Vector2(1, 1)), light)
		if i % 9 == 0:
			draw_rect(Rect2(point + Vector2(-1, 1), Vector2(3, 1)), light)
			draw_rect(Rect2(point + Vector2(0, 2), Vector2(1, 1)), light)
	# Full moon with a stepped pixel outline above the western roof.
	for band in [Rect2(79, 38, 10, 2), Rect2(75, 40, 18, 3), Rect2(73, 43, 22, 3), Rect2(71, 46, 26, 10), Rect2(73, 56, 22, 3), Rect2(75, 59, 18, 3), Rect2(79, 62, 10, 2)]:
		draw_rect(band, Color("f9d4a0"))
	# Sunset clouds, kept away from the title.
	var clouds := [Rect2(16, 132, 110, 4), Rect2(38, 128, 60, 4), Rect2(496, 136, 120, 4), Rect2(522, 132, 58, 4), Rect2(183, 152, 69, 3), Rect2(373, 150, 60, 3)]
	for i in range(clouds.size()):
		var spec: Rect2 = clouds[i]
		var drift := roundf(sin(elapsed * 0.09 + float(i / 2) * 1.7) * 12.0)
		draw_rect(Rect2(spec.position + Vector2(drift, 0), spec.size), Color("d98c87"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,224),Vector2(0,192),Vector2(62,166),Vector2(111,197),Vector2(170,160),Vector2(241,211),Vector2(302,190),Vector2(377,210),Vector2(449,169),Vector2(518,196),Vector2(573,163),Vector2(640,191),Vector2(640,266),Vector2(0,266)]), Color("785e74"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,240),Vector2(0,213),Vector2(63,205),Vector2(121,228),Vector2(190,205),Vector2(263,238),Vector2(335,218),Vector2(409,231),Vector2(480,207),Vector2(548,225),Vector2(640,204),Vector2(640,281),Vector2(0,281)]), Color("55505e"))
	draw_rect(Rect2(0, 251, 640, 109), Color("66614e"))
	draw_rect(Rect2(0, 276, 640, 84), Color("77705a"))
	draw_colored_polygon(PackedVector2Array([Vector2(281,252),Vector2(359,252),Vector2(447,360),Vector2(194,360)]), Color("a18a70"))
	for i in range(88):
		var x := float((i * 83 + 11) % 640)
		var y := float(264 + (i * 47) % 96)
		if x < 215 or x > 426:
			draw_rect(Rect2(x, y, 3 + i % 5, 1), Color("8b8063") if i % 2 == 0 else Color("5d604d"))
	for i in range(5):
		draw_rect(Rect2(304 - i * 13, 276 + i * 18, 32 + i * 10, 2), Color("c2a385"))
	# Soft stepped halos sit behind the animated lamp sprites.
	for i in range(2):
		var center := Vector2(213 + i * 227, 234)
		var pulse := 0.5 + 0.5 * sin(elapsed * 2.3 + i * 2.1)
		draw_rect(Rect2(center - Vector2(12, 10), Vector2(24, 20)), Color(1.0, 0.76, 0.38, 0.035 + pulse * 0.025))
		draw_rect(Rect2(center - Vector2(8, 14), Vector2(16, 28)), Color(1.0, 0.76, 0.38, 0.04 + pulse * 0.03))
	draw_rect(Rect2(witch.position + Vector2(-6, 22), Vector2(12, 2)), Color(0.15, 0.12, 0.19, 0.25))
	# Fireflies animate in discrete pixels beside the menu, never over its text.
	for i in range(10):
		var origin := Vector2(176 + (i * 73) % 280, 204 + (i * 29) % 112)
		if origin.x > 226 and origin.x < 414:
			continue
		origin += Vector2(roundf(sin(elapsed * 0.7 + i) * 3), roundf(cos(elapsed * 0.8 + i) * 3))
		var glow := Color("ffe3a1")
		glow.a = 0.35 + 0.5 * (sin(elapsed * 1.5 + i) + 1.0) / 2.0
		draw_rect(Rect2(origin, Vector2(2, 2)), glow)
