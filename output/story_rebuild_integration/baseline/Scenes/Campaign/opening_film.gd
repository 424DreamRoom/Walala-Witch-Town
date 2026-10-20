extends Control
## New-game opening film. Five shots drawn from existing pixel art with integer zoom,
## plus procedural rain, falling letter, walking witch, fading moonring and window light.
## The film is a pure function of `elapsed`, so pausing, skipping and tests stay deterministic.
const AsepriteSource = preload("res://Art/Source/aseprite_source.gd")
const Witch = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")
const SHOT := 6.0
const FADE := 0.8
const SCREEN := Vector2(640, 360)
const TEXT_TOP := 220.0
const WARM := Color("ffc978")
const INK := Color("fff0d5")
const BACKGROUNDS := {
	"kitchen": "res://Art/Environment/Hearthwood/restaurant_background.aseprite",
	"letter": "res://Art/Environment/Hearthwood/home_overview.aseprite",
	"road": "res://Art/Environment/Hearthwood/field_overview.aseprite",
	"town": "res://Art/Environment/Hearthwood/town_overview.aseprite",
	"home": "res://Art/Environment/Hearthwood/farm_overview.aseprite",
}
var shots: Array = []
var elapsed := 0.0
var textures := {}
var witch_sheet: Texture2D

func setup(film_shots: Array) -> void:
	shots = film_shots
	size = SCREEN
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for scene in BACKGROUNDS: textures[scene] = AsepriteSource.texture(BACKGROUNDS[scene])
	witch_sheet = AsepriteSource.texture(Witch.SHEET)

static func length_for(count: int) -> float:
	return SHOT * count

func index_at(time: float) -> int:
	return clampi(int(time / SHOT), 0, shots.size() - 1)

func render(time: float) -> void:
	elapsed = time
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("272333"))
	if shots.is_empty(): return
	var index := index_at(elapsed)
	var t := clampf(elapsed - index * SHOT, 0.0, SHOT)
	match String(shots[index].scene):
		"kitchen": _kitchen(t)
		"letter": _letter(t)
		"road": _road(t)
		"town": _town(t)
		"home": _home(t)
	var fade := clampf(minf(t, SHOT - t) / FADE, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.153, 0.137, 0.2, 1.0 - fade))

# -- shots -----------------------------------------------------------------

func _kitchen(t: float) -> void:
	# A busy inn kitchen: the witch faces the back counter, the stove glows beside her.
	var origin := Vector2(roundf(lerpf(0.0, 40.0, t / SHOT)), 43.0)
	_background("kitchen", origin, 2)
	var flicker := 0.5 + 0.5 * sin(t * 9.0) * sin(t * 3.7)
	_glow(_to_screen(Vector2(275, 96), origin, 2), 70.0, WARM, 0.10 + 0.06 * flicker)
	_witch("idle", 1, t, Vector2(150, 128), origin, 2)
	_tint(Color(1.0, 0.75, 0.45, 0.08))

func _letter(t: float) -> void:
	# A rainy night at the sink. The letter drifts down and settles on the counter.
	var origin := Vector2(285.0, roundf(lerpf(112.0, 120.0, t / SHOT)))
	_background("letter", origin, 2)
	_tint(Color(0.10, 0.12, 0.30, 0.48))
	_glow(_to_screen(Vector2(436, 120), origin, 2), 60.0, Color("b9c8ff"), 0.07)
	_rain(t)
	_witch("idle", 1, t, Vector2(445, 216), origin, 2)
	var land := 3.4
	var rest := Vector2(434, 170)
	var p := rest
	var tilt := 0.0
	if t < land:
		var k := t / land
		p = Vector2(rest.x + sin(t * 3.2) * 14.0 * (1.0 - k), lerpf(origin.y - 10.0, rest.y, k))
		tilt = sin(t * 3.2) * 0.35 * (1.0 - k)
	_paper(_to_screen(p, origin, 2), tilt)

func _road(t: float) -> void:
	# The first journey of her own: walking the forest road with her trunk of pots.
	var x := lerpf(70.0, 380.0, t / SHOT)
	var origin := Vector2(roundf(clampf(x - 160.0, 0.0, 320.0)), 171.0)
	_background("road", origin, 2)
	_tint(Color(1.0, 0.85, 0.6, 0.06))
	var feet := Vector2(roundf(x), 266.0)
	var bob := 1.0 if fmod(t, 0.28) < 0.14 else 0.0
	var trunk := _to_screen(feet + Vector2(-17, -9 + bob), origin, 2)
	draw_rect(Rect2(trunk, Vector2(20, 16)), Color("6e4a32"))
	draw_rect(Rect2(trunk + Vector2(0, 4), Vector2(20, 2)), Color("c9a46a"))
	draw_rect(Rect2(trunk + Vector2(8, -4), Vector2(4, 4)), Color("3d2a20"))
	_witch("walk", 2, t, feet, origin, 2)

func _town(t: float) -> void:
	# Dusk over the town; a faint moonring flickers above the fountain and goes out.
	var origin := Vector2(362.0, roundf(lerpf(290.0, 330.0, t / SHOT)))
	_background("town", origin, 1)
	_tint(Color(0.16, 0.10, 0.26, 0.42))
	var center := _to_screen(Vector2(682, 452), origin, 1)
	var ring := 0.0
	if t < 3.2:
		ring = (0.35 + 0.25 * sin(t * 11.0) * sin(t * 4.3)) * clampf((3.2 - t) / 1.2, 0.0, 1.0)
	if ring > 0.0:
		draw_arc(center, 88.0, 0.0, TAU, 96, Color(INK, ring), 2.0)
		draw_arc(center, 96.0, 0.0, TAU, 96, Color(INK, ring * 0.4), 1.0)
	for spot in [Vector2(455, 420), Vector2(812, 468), Vector2(750, 330), Vector2(1100, 545)]:
		_glow(_to_screen(spot, origin, 1), 10.0, WARM, 0.05)

func _home(t: float) -> void:
	# She climbs to the unlocked cottage; the windows warm up as she sets down her trunk.
	var origin := Vector2(30.0, 70.0)
	_background("home", origin, 1)
	var dusk := clampf((t - 2.5) / 2.0, 0.0, 1.0)
	_tint(Color(0.20, 0.12, 0.28, 0.18 + 0.22 * dusk))
	var walking := t < 3.4
	var feet := Vector2(268, roundf(lerpf(330.0, 262.0, clampf(t / 3.4, 0.0, 1.0))))
	if not walking:
		var trunk := _to_screen(feet + Vector2(12, -9), origin, 1)
		draw_rect(Rect2(trunk, Vector2(10, 8)), Color("6e4a32"))
		draw_rect(Rect2(trunk + Vector2(0, 2), Vector2(10, 1)), Color("c9a46a"))
	_witch("walk" if walking else "idle", 1, t, feet, origin, 1)
	var light := clampf((t - 3.6) / 1.4, 0.0, 1.0)
	for window in [Vector2(218, 214), Vector2(322, 214)]:
		_glow(_to_screen(window, origin, 1), 26.0, WARM, 0.22 * light)

# -- drawing helpers -------------------------------------------------------

func _to_screen(point: Vector2, origin: Vector2, zoom: int) -> Vector2:
	return ((point - origin) * zoom).round()

func _background(scene: String, origin: Vector2, zoom: int) -> void:
	var texture: Texture2D = textures[scene]
	var source := Rect2(origin, SCREEN / zoom).intersection(Rect2(Vector2.ZERO, texture.get_size()))
	draw_texture_rect_region(texture, Rect2((source.position - origin) * zoom, source.size * zoom), source)

func _tint(color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), color)

func _glow(center: Vector2, radius: float, color: Color, strength: float) -> void:
	if strength <= 0.0: return
	for step in range(4):
		var k := 1.0 - step * 0.22
		draw_circle(center, radius * k, Color(color, strength * (0.4 + step * 0.2)))

func _witch(action: String, facing: int, t: float, feet: Vector2, origin: Vector2, zoom: int) -> void:
	var frame := Witch.frame_for(action, facing, t)
	var source := Rect2(frame % Witch.COLUMNS * 32, frame / Witch.COLUMNS * 32, 32, 32)
	var base := _to_screen(feet, origin, zoom)
	draw_set_transform(Vector2.ZERO)
	_shadow(base, zoom)
	draw_texture_rect_region(witch_sheet, Rect2(base - Vector2(16, 32) * zoom, Vector2(32, 32) * zoom), source)

func _shadow(base: Vector2, zoom: int) -> void:
	draw_set_transform(base, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0 * zoom, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)

func _paper(center: Vector2, tilt: float) -> void:
	draw_set_transform(center, tilt)
	draw_rect(Rect2(-12, -8, 24, 16), Color("fff0d5"))
	draw_polyline(PackedVector2Array([Vector2(-12, -8), Vector2(0, 1), Vector2(12, -8)]), Color("c7a477"), 2.0)
	draw_rect(Rect2(-2, -1, 4, 4), Color("c0505a"))
	draw_set_transform(Vector2.ZERO)

func _rain(t: float) -> void:
	for drop in range(70):
		var seed := float(drop) * 37.31
		var speed := 360.0 + fmod(seed * 13.0, 160.0)
		var x := fmod(seed * 19.7 + t * 90.0, SCREEN.x + 80.0) - 40.0
		var y := fmod(seed * 7.3 + t * speed, SCREEN.y + 40.0) - 20.0
		draw_line(Vector2(x, y), Vector2(x - 4, y + 12), Color(0.75, 0.82, 1.0, 0.28), 1.0)
