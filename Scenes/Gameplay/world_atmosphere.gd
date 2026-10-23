extends Node2D
## Sparse pixel motion supports the scene; it owns no input or random game state.
const INDOORS := ["home", "restaurant", "store", "blacksmith", "furniture_store"]
var loop
var elapsed := 0.0

func _ready() -> void:
	name = "SeasonalAtmosphere"
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 720.0)
	queue_redraw()

func _draw() -> void:
	if loop == null: return
	var minutes: float = loop.state.get_time_minutes()
	var twilight: bool = minutes >= 960.0
	var night: bool = minutes >= 1200.0 or minutes < 360.0
	var weather_kind: String = loop.lane.weather.get_weather()
	if loop.location in INDOORS:
		if loop.location == "restaurant" and loop.state.cooking >= 0:
			for i in range(5):
				var age := fposmod(elapsed * 0.7 + i * 0.2, 1.0)
				var at := Vector2(230 + sin(age * 5.0 + i) * 5.0, 90 - age * 23.0).round()
				draw_rect(Rect2(at,Vector2(3,2)), Color(1.0,0.94,0.8,0.35*(1.0-age)))
		if twilight:
			for i in range(4):
				var phase := elapsed * 1.35 + float(i) * 1.7
				var at := Vector2(34 + i * 148 + sin(phase) * 4.0, 54 + cos(phase * 0.8) * 3.0).round()
				draw_rect(Rect2(at, Vector2(1, 1)), Color("f5d28f", 0.34 + 0.12 * sin(phase)))
		return
	var origin: Vector2 = loop.lane.camera.get_screen_center_position() - Vector2(320,180)
	# Weather is kept intentionally sparse so it reads as atmosphere instead of
	# a full-screen particle layer.  The ground accents sit below the character
	# and use fixed pixel positions, which makes them stable in screenshots.
	if weather_kind == "rain":
		for i in range(9):
			var puddle := (origin + Vector2(34 + i * 79, 274 + (i % 3) * 22)).round()
			var ripple := 2.0 + fposmod(elapsed * 3.2 + i * 0.7, 3.0)
			draw_arc(puddle, ripple, 0.0, TAU, 12, Color("b9d3d0", 0.12), 1.0, true)
		for i in range(22):
			var phase := elapsed * (7.0 + float(i % 4)) + float(i) * 2.17
			var point := origin + Vector2(fposmod(i * 97.0 + phase * 13.0, 670.0) - 15.0, fposmod(i * 41.0 + phase * 19.0, 390.0) - 15.0)
			draw_rect(Rect2(point.round(), Vector2(1, 4)), Color("c7d9dc", 0.18 if not twilight else 0.26))
		if twilight:
			for i in range(5):
				var point: Vector2 = origin + Vector2(i * 47 + 134, 272 + sin(elapsed * 2.0 + i) * 2.0)
				draw_rect(Rect2(point.round(), Vector2(4, 1)), Color("f1c27c", 0.16))
	elif weather_kind == "snow":
		for i in range(18):
			var phase := elapsed * (1.2 + float(i % 3) * 0.18) + float(i) * 1.8
			var point := origin + Vector2(fposmod(i * 83.0 + sin(phase) * 12.0, 670.0) - 15.0, fposmod(i * 47.0 + elapsed * (12.0 + i % 4), 390.0) - 15.0)
			draw_rect(Rect2(point.round(), Vector2(2, 2)), Color("eef3e9", 0.42 if not night else 0.3))
	# Rain and snow still receive the regular night fireflies below, but clear
	# weather gets the warmer seasonal motes first.
	var season: int = loop.state.Campaign.season(loop.state)
	var evening: bool = minutes >= 1020.0
	var colors := [Color("e9c1ba"),Color("dfcf94"),Color("c58b57"),Color("c5d6d1")]
	for i in range(16 if evening and weather_kind == "clear" else 10 if weather_kind == "clear" else 4):
		var drift := elapsed * (4.0 if evening else 7.0)
		var x := fposmod(float(i*137) + drift + sin(elapsed*0.4+i)*12.0, 672.0) - 16.0
		var y := fposmod(float(i*73) + elapsed*(1.0 if evening else 3.0), 392.0) - 16.0
		var at := (origin + Vector2(x,y)).round()
		var color: Color = Color("e9d891") if evening else colors[season]
		color.a = 0.35 + sin(elapsed*1.4+i)*0.12 if evening else 0.42
		draw_rect(Rect2(at,Vector2(2,1)),color)
		if season == 2 and not evening: draw_rect(Rect2(at+Vector2(1,1),Vector2(1,1)),color)
	if night or twilight:
		for i in range(12 if night else 7):
			var phase := elapsed * (0.75 + float(i % 3) * 0.18) + float(i) * 2.1
			var x := fposmod(float(i * 113) + sin(phase) * 15.0, 672.0) - 16.0
			var y := fposmod(float(i * 59) + cos(phase * 0.7) * 10.0, 392.0) - 16.0
			var alpha := 0.28 + 0.28 * (sin(phase * 1.6) + 1.0) * 0.5
			draw_rect(Rect2((origin + Vector2(x, y)).round(), Vector2(1, 1)), Color("f5dc9a", alpha))
