extends Control
## New-game opening film: work, savings, notice, correspondence, packing,
## river journey, town and docking. Existing art keeps its native palette and pixels.
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
	"savings": "res://Art/Environment/Hearthwood/home_overview.aseprite",
	"notice": "res://Art/Environment/Hearthwood/home_overview.aseprite",
	"reply": "res://Art/Environment/Hearthwood/home_overview.aseprite",
	"packing": "res://Art/Environment/Hearthwood/home_overview.aseprite",
	"town": "res://Art/Environment/Hearthwood/town_overview.aseprite",
	"dock": "res://Art/Environment/Hearthwood/dock_ground.aseprite",
}
var shots: Array = []
var elapsed := 0.0
var textures := {}
var witch_sheet: Texture2D
var boat_texture: Texture2D
var maren_sheet: Texture2D
var starts: Array[float] = []
var durations: Array[float] = []

func setup(film_shots: Array) -> void:
	shots = film_shots
	size = SCREEN
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for scene in BACKGROUNDS: textures[scene] = AsepriteSource.texture(BACKGROUNDS[scene])
	witch_sheet = AsepriteSource.texture(Witch.SHEET)
	boat_texture = AsepriteSource.texture("res://Art/Environment/Hearthwood/dock_boat.aseprite")
	maren_sheet = AsepriteSource.texture("res://Art/Characters/NPC32/residents/nagi.aseprite")
	starts.clear()
	durations.clear()
	var cursor := 0.0
	for shot in shots:
		starts.append(cursor)
		var duration := float(shot.get("duration", SHOT))
		durations.append(duration)
		cursor += duration

func length() -> float:
	return starts[-1] + durations[-1] if not starts.is_empty() else 0.0

func index_at(time: float) -> int:
	for index in range(starts.size() - 1, -1, -1):
		if time >= starts[index]: return index
	return 0

func local_time(time: float) -> float:
	return clampf(time - starts[index_at(time)], 0.0, durations[index_at(time)])

func render(time: float) -> void:
	elapsed = time
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("272333"))
	if shots.is_empty(): return
	var index := index_at(elapsed)
	var duration: float = durations[index]
	var shot_time := local_time(elapsed)
	# Original drawing motion is normalized to six seconds; reading time is
	# independent, so a longer caption does not make the subject leave early.
	var t := shot_time / duration * SHOT
	match String(shots[index].scene):
		"kitchen": _kitchen(t)
		"savings": _savings(t)
		"notice": _notice(t)
		"reply": _reply(t)
		"packing": _packing(t)
		"voyage": _voyage(t)
		"town": _town(t)
		"dock": _dock(t)
	var fade := clampf(minf(shot_time, duration - shot_time) / FADE, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.153, 0.137, 0.2, 1.0 - fade))

# -- shots -----------------------------------------------------------------

func _kitchen(t: float) -> void:
	# A busy inn kitchen: the witch faces the back counter, the stove glows beside her.
	var origin := Vector2(roundf(lerpf(0.0, 40.0, t / SHOT)), 43.0)
	_background("kitchen", origin, 2)
	var flicker := 0.5 + 0.5 * sin(t * 9.0) * sin(t * 3.7)
	_glow(_to_screen(Vector2(275, 96), origin, 2), 70.0, WARM, 0.10 + 0.06 * flicker)
	_witch("idle", 1, t, Vector2(150, 128), origin, 2)
	# Steam and changing stove light show work continuing through the shot.
	for puff in range(5):
		var rise := fmod(t * 14.0 + puff * 7.0, 35.0)
		var steam := _to_screen(Vector2(272 + sin(t * 2.0 + puff) * 3.0, 94 - rise), origin, 2)
		draw_rect(Rect2(steam, Vector2(3, 5)), Color(INK, 0.24 * (1.0 - rise / 35.0)))
	_tint(Color(1.0, 0.75, 0.45, 0.08))

func _desk() -> void:
	_background("savings", Vector2(285,112), 2)
	_tint(Color(0.10,0.08,0.16,0.38))
	draw_rect(Rect2(152,38,336,160), Color("563c32"))
	draw_rect(Rect2(160,42,320,148), Color("a57850"))

func _savings(t: float) -> void:
	_desk()
	draw_rect(Rect2(190,58,140,110), Color("e9d8ad"))
	for row in range(5):
		draw_rect(Rect2(202,74 + row * 16,64,2), Color("80634c"))
		draw_rect(Rect2(284,74 + row * 16,30,2), Color("80634c"))
	# Two modest piles beside an expense ledger, all above the caption band.
	for coin in range(12):
		var arrival := clampf(t * 3.0 - coin, 0.0, 1.0)
		var target := Vector2(368 + (coin % 3) * 18, 122 - floori(coin / 3.0) * 8)
		var at := Vector2(target.x, roundf(lerpf(48.0, target.y, arrival)))
		if arrival > 0.0:
			draw_rect(Rect2(at,Vector2(13,6)), Color("d6a555"))
			draw_rect(Rect2(at + Vector2(2,0),Vector2(9,2)), Color("ffe0a0"))

func _reply(t: float) -> void:
	_desk()
	# A written inquiry and a reply placed beside it; no anonymous falling letter.
	for sheet in range(2):
		var x := 190.0 + sheet * 134.0
		var slide := 0.0 if sheet == 0 else roundf(20.0 * (1.0 - clampf(t / 2.0,0,1)))
		draw_rect(Rect2(x,52 + slide,116,118), Color("e9d8ad"))
		for row in range(6):
			draw_rect(Rect2(x + 12,72 + slide + row * 13,84 if row < 5 else 44,2),Color("80634c"))
	_paper(Vector2(422,155),0.0)
	var pen := Vector2(260 + sin(t * 4.0) * 12,138)
	draw_line(pen,pen + Vector2(14,-25),Color("423044"),3)

func _packing(t: float) -> void:
	_desk()
	var trunk := Rect2(236,75,168,100)
	draw_rect(trunk.grow(6),Color("563c32"))
	draw_rect(trunk,Color("c69764"))
	draw_rect(trunk.grow(-8),Color("493b39"))
	for bowl in range(3):
		var y := roundf(lerpf(52.0,132.0 - bowl * 9,clampf((t - bowl * 0.4) / 1.2,0,1)))
		draw_rect(Rect2(262,y,38,9),Color("d8c7aa"))
		draw_rect(Rect2(266,y + 9,30,5),Color("9c8f82"))
	draw_circle(Vector2(352,120),24,Color("5d6270"))
	draw_circle(Vector2(352,120),18,Color("9495a0"))
	draw_rect(Rect2(374,115,24,8),Color("493b39"))
	_paper(Vector2(329,151),0)
	if t > 3.0:
		var strap := clampf((t - 3.0) / 1.5,0,1)
		draw_rect(Rect2(254,73,8,roundf(104 * strap)),Color("d6a555"))
		draw_rect(Rect2(378,73,8,roundf(104 * strap)),Color("d6a555"))

func _notice(t: float) -> void:
	# A pinned public advertisement. The circled rent clause is visual, not a
	# second untranslated text layer; the localized caption supplies its wording.
	var origin := Vector2(285.0, roundf(lerpf(112.0, 120.0, t / SHOT)))
	_background("notice", origin, 2)
	_tint(Color(0.10, 0.12, 0.20, 0.22))
	_witch("idle", 1, t, Vector2(445, 216), origin, 2)
	var board := Rect2(220, 35, 188, 142)
	draw_rect(board.grow(8), Color("674832"))
	draw_rect(board, Color("e9d8ad"))
	for y in [62, 82, 102, 132]:
		draw_rect(Rect2(244, y, 136 if y != 132 else 100, 3), Color("80634c"))
	draw_circle(Vector2(314, 42), 4, Color("9a5e40"))
	draw_arc(Vector2(294, 133), 57, 0, TAU * clampf((t - 1.0) / 1.5, 0, 1), 64, Color("b5534b"), 2)

func _voyage(t: float) -> void:
	draw_rect(Rect2(Vector2.ZERO,SCREEN),Color("598b99"))
	for row in range(16):
		for column in range(8):
			var x := fposmod(column * 97.0 - t * (20 + row % 3 * 5) + row * 31,680.0) - 20
			draw_rect(Rect2(roundf(x),row * 14,22,2),Color("87adb2"))
	# Riverbanks scroll past the existing cargo-boat sprite; it is a river
	# journey rather than the old forest walk beneath a sailing caption.
	for bank in range(2):
		for patch in range(14):
			var x := fposmod(patch * 58.0 - t * 24,812.0) - 58
			var y := -12.0 + bank * 212.0
			draw_rect(Rect2(roundf(x),y,60,28 + (patch % 3) * 4),Color("668460"))
	var center := Vector2(310 + roundf(t * 9),140 + roundf(sin(t * 3) * 2))
	_draw_boat(center, true)
	_witch("idle",2,t,center + Vector2(-8,-14),Vector2.ZERO,1)
	_luggage(center + Vector2(-28,-22))
	for wake in range(4):
		draw_rect(Rect2(center + Vector2(-90 - wake * 13,6 + wake % 2 * 4),Vector2(8,2)),Color("c3d5ce"))

func _town(t: float) -> void:
	# The ring was shut down years ago; it does not fail as the witch arrives.
	var origin := Vector2(362.0, roundf(lerpf(290.0, 330.0, t / SHOT)))
	_background("town", origin, 1)
	_tint(Color(0.95,0.81,0.60,0.05))
	var center := _to_screen(Vector2(682, 452), origin, 1)
	var ring := 0.12
	if ring > 0.0:
		draw_arc(center, 88.0, 0.0, TAU, 96, Color(INK, ring), 2.0)
		draw_arc(center, 96.0, 0.0, TAU, 96, Color(INK, ring * 0.4), 1.0)
	for spot in [Vector2(455, 420), Vector2(812, 468), Vector2(750, 330), Vector2(1100, 545)]:
		_glow(_to_screen(spot, origin, 1), 10.0, WARM, 0.05)

func _dock(t: float) -> void:
	# End at the same pier as the first playable scene, before any farm visit.
	_background("dock",Vector2(0,70),1)
	var center := Vector2(574,roundf(lerpf(240,114,clampf(t / 2.0,0,1))))
	_draw_boat(center)
	# The pier ends at x=532. Boat and gangplank stay in the water to its east.
	if t >= 2.0:
		draw_rect(Rect2(526,109,42,12),Color("a57850"))
		for x in range(530,568,8): draw_line(Vector2(x,109),Vector2(x,121),Color("674832"),1)
	var walking := t > 2.5 and t < 4.8
	var feet := center + Vector2(-8,-14)
	if t > 2.5:
		if t < 3.2: feet = Vector2(566,100).lerp(Vector2(510,115),clampf((t - 2.5) / 0.7,0,1)).round()
		else: feet = Vector2(510,115).lerp(Vector2(300,169),clampf((t - 3.2) / 1.6,0,1)).round()
	var maren := Vector2(332,153)
	_shadow(maren,1)
	draw_texture_rect_region(maren_sheet,Rect2(maren - Vector2(16,32),Vector2(32,32)),Rect2(8 * 32,0,32,32))
	_witch("walk" if walking else "idle",3,t,feet,Vector2.ZERO,1)
	_luggage(feet + Vector2(15,-8) if t < 4.8 else maren + Vector2(-15,0))

func _draw_boat(center: Vector2, horizontal: bool = false) -> void:
	var boat_size := boat_texture.get_size()
	draw_set_transform(center.round(),PI / 2 if horizontal else 0.0)
	draw_texture_rect(boat_texture,Rect2(-boat_size / 2,boat_size),false)
	draw_set_transform(Vector2.ZERO)

func _luggage(at: Vector2) -> void:
	draw_rect(Rect2(at,Vector2(20,16)),Color("6e4a32"))
	draw_rect(Rect2(at + Vector2(0,4),Vector2(20,2)),Color("c9a46a"))

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
