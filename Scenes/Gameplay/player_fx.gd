extends Node2D
## Small native-pixel effects that make the witch readable without touching the
## authored character source. The effect follows movement and the current
## weather, while keeping the sprite's original palette intact.

var elapsed := 0.0
var moving := false
var running := false
var facing := 0
var weather := "clear"
var night := false
var wand_mode := "red"

func _ready() -> void:
	name = "WitchMagicFX"
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)

func configure(next_weather: String = "clear") -> void:
	weather = next_weather
	queue_redraw()

func set_motion(is_moving: bool, is_running: bool, direction: int) -> void:
	if moving != is_moving or running != is_running or facing != direction:
		moving = is_moving
		running = is_running
		facing = direction
		queue_redraw()

func set_world_state(next_weather: String, is_night: bool, next_wand_mode: String) -> void:
	var changed := weather != next_weather or night != is_night or wand_mode != next_wand_mode
	weather = next_weather
	night = is_night
	wand_mode = next_wand_mode
	if changed:
		queue_redraw()

func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 64.0)
	if moving or night:
		queue_redraw()

func _draw() -> void:
	# A tiny contact shimmer anchors the character to wet or snowy ground.
	if weather == "rain" or weather == "snow":
		var contact := 1.0 + sin(elapsed * 5.0) * 0.25
		var contact_color := Color("9cc6cf", 0.24) if weather == "rain" else Color("fff1d0", 0.28)
		draw_rect(Rect2(-7.0 * contact, 0, 14.0 * contact, 1), contact_color)

	# Running leaves a short warm dust ribbon; walking gets two restrained motes.
	if moving:
		var count := 3 if running else 2
		var tint := Color("f0c788", 0.52) if weather != "snow" else Color("e9edf0", 0.55)
		for index in range(count):
			var phase := elapsed * (7.0 if running else 4.5) + float(index) * 1.9
			var side := -1.0 if index % 2 == 0 else 1.0
			var drift := sin(phase) * (2.0 + index)
			var offset := Vector2(side * (5.0 + index * 2.0) + drift, 1.0 - fposmod(phase, 2.7) * 1.6)
			draw_rect(Rect2(offset.round(), Vector2(1, 1)), tint)

	# The wand tip receives a single pixel halo. It is deliberately abstract so
	# the effect supports every authored animation frame and direction.
	if night or moving:
		var tip := Vector2(9, -18)
		match facing:
			0: tip = Vector2(10, -18)
			1: tip = Vector2(8, -25)
			2: tip = Vector2(14, -20)
			3: tip = Vector2(-14, -20)
		var glow := Color("93c7d8", 0.8) if wand_mode == "blue" else Color("edb56d", 0.76)
		var pulse := 1 if int(elapsed * 7.0) % 3 != 0 else 2
		draw_rect(Rect2(tip - Vector2(pulse, pulse), Vector2(pulse * 2 + 1, 1)), Color(glow, glow.a * 0.32))
		draw_rect(Rect2(tip, Vector2(1, 1)), glow)

	# Firefly-sized pixels make the silhouette feel alive at dusk without a
	# persistent outline that would flatten the original pixel art.
	if night:
		for index in range(2):
			var phase := elapsed * 1.8 + float(index) * 3.14
			var mote := Vector2(cos(phase) * 8.0, -12.0 + sin(phase * 1.4) * 5.0).round()
			draw_rect(Rect2(mote, Vector2(1, 1)), Color("f6df9b", 0.62))
