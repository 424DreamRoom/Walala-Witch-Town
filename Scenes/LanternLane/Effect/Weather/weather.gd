class_name WeatherEffect
extends Node2D
## Reusable pixel weather overlay. Screen-space particles follow the active camera.
## Public API: set_weather("clear"|"rain"|"snow"), clear_weather(), get_weather().

const VIEW_SIZE := Vector2(640.0, 360.0)
const RAIN_COUNT := 92
const SNOW_COUNT := 48
const RAIN_COLOR := Color("9ec8d4")
const RAIN_SPLASH_COLOR := Color("b9dce0")
const SNOW_COLOR := Color("fff4d6")

var weather: String = "clear"
var camera: Camera2D
var player: Node2D
var roof_rects: Array = []
var rng := RandomNumberGenerator.new()
var rain: Array[Dictionary] = []
var snow: Array[Dictionary] = []
var elapsed := 0.0
var splashes: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Cancel the viewport's camera transform: particles cover screen, not world.
	set_notify_transform(false)
	rng.seed = 73129
	_make_particles()
	set_process(true)

func configure(follow_camera: Camera2D, watched_player: Node2D, blocked_roofs: Array = []) -> void:
	camera = follow_camera
	player = watched_player
	roof_rects = blocked_roofs
	queue_redraw()

func set_weather(next_weather: String) -> void:
	var normalized := next_weather.to_lower()
	weather = normalized if normalized in ["clear", "rain", "snow"] else "clear"
	splashes.clear()
	queue_redraw()

func clear_weather() -> void:
	set_weather("clear")

func get_weather() -> String:
	return weather

func _make_particles() -> void:
	rain.clear()
	snow.clear()
	for i in range(RAIN_COUNT):
		rain.append({"x": rng.randf_range(0.0, VIEW_SIZE.x), "y": rng.randf_range(0.0, VIEW_SIZE.y), "speed": rng.randf_range(210.0, 310.0), "length": rng.randi_range(5, 10), "landing": rng.randf_range(12.0, VIEW_SIZE.y)})
	for i in range(SNOW_COUNT):
		snow.append({"x": rng.randf_range(0.0, VIEW_SIZE.x), "y": rng.randf_range(0.0, VIEW_SIZE.y), "speed": rng.randf_range(18.0, 38.0), "drift": rng.randf_range(5.0, 14.0), "size": rng.randi_range(1, 2), "phase": rng.randf_range(0.0, 6.28)})

func _process(delta: float) -> void:
	# Updating each frame also handles clamped map edges and camera teleports.
	transform = get_viewport().get_canvas_transform().affine_inverse()
	elapsed += delta
	if weather == "clear":
		return
	if weather == "rain":
		for i in range(splashes.size() - 1, -1, -1):
			splashes[i].life -= delta
			if splashes[i].life <= 0.0:
				splashes.remove_at(i)
		for drop in rain:
			drop.y += drop.speed * delta
			if drop.y >= drop.landing:
				var impact := Vector2(roundf(drop.x), roundf(drop.landing))
				if not _is_roof(impact) and not _near_player_face(impact):
					# World anchor: water does not slide across the ground with camera.
					splashes.append({"world": _world_at(impact), "life": 0.16})
				drop.y = -drop.length
				drop.x = rng.randf_range(0.0, VIEW_SIZE.x)
				drop.landing = rng.randf_range(12.0, VIEW_SIZE.y)
	else:
		for flake in snow:
			flake.y += flake.speed * delta
			flake.x += sin(elapsed * 1.5 + flake.phase) * flake.drift * delta
			if flake.y > VIEW_SIZE.y + 4.0:
				flake.y = -4.0
				flake.x = rng.randf_range(0.0, VIEW_SIZE.x)
			if flake.x < -4.0:
				flake.x = VIEW_SIZE.x + 4.0
			elif flake.x > VIEW_SIZE.x + 4.0:
				flake.x = -4.0
	queue_redraw()

func _world_at(screen_point: Vector2) -> Vector2:
	if camera == null:
		return screen_point
	return camera.get_screen_center_position() + screen_point - VIEW_SIZE * 0.5

func _is_roof(screen_point: Vector2) -> bool:
	var world_point := _world_at(screen_point)
	for rect in roof_rects:
		if rect.has_point(world_point):
			return true
	return false

func _near_player_face(screen_point: Vector2) -> bool:
	if player == null:
		return false
	var player_screen := player.global_position - _world_at(Vector2.ZERO)
	return Rect2(player_screen + Vector2(-9, -26), Vector2(18, 27)).has_point(screen_point)

func _draw() -> void:
	if weather == "rain":
		for drop in rain:
			var point := Vector2(roundf(drop.x), roundf(drop.y))
			# Falling rain is foreground, including over roofs; only splashes use roof masking.
			# Individual pixels preserve clean player masking without antialiasing.
			for y in range(int(drop.length)):
				var pixel := point + Vector2(0, y)
				if not _near_player_face(pixel):
					draw_rect(Rect2(pixel, Vector2.ONE), RAIN_COLOR)
		for splash in splashes:
			var point: Vector2 = (splash.world - _world_at(Vector2.ZERO)).round()
			if not _is_roof(point) and not _near_player_face(point):
				var spread := 1 if splash.life > 0.08 else 2
				draw_rect(Rect2(point + Vector2(-spread, -1), Vector2.ONE), RAIN_SPLASH_COLOR)
				draw_rect(Rect2(point + Vector2(spread, -1), Vector2.ONE), RAIN_SPLASH_COLOR)
				draw_rect(Rect2(point, Vector2.ONE), RAIN_SPLASH_COLOR)
	elif weather == "snow":
		for flake in snow:
			var point := Vector2(roundf(flake.x), roundf(flake.y))
			var size: int = flake.size
			if size == 1:
				draw_rect(Rect2(point, Vector2.ONE), SNOW_COLOR)
			else:
				draw_rect(Rect2(point + Vector2(-1, 0), Vector2(3, 1)), SNOW_COLOR)
				draw_rect(Rect2(point + Vector2(0, -1), Vector2(1, 3)), SNOW_COLOR)
