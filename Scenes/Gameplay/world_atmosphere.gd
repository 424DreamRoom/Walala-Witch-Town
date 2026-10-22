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
	if loop.location in INDOORS:
		if loop.location == "restaurant" and loop.state.cooking >= 0:
			for i in range(5):
				var age := fposmod(elapsed * 0.7 + i * 0.2, 1.0)
				var at := Vector2(230 + sin(age * 5.0 + i) * 5.0, 90 - age * 23.0).round()
				draw_rect(Rect2(at,Vector2(3,2)), Color(1.0,0.94,0.8,0.35*(1.0-age)))
		return
	if loop.lane.weather.get_weather() != "clear": return
	var season: int = loop.state.Campaign.season(loop.state)
	var origin: Vector2 = loop.lane.camera.get_screen_center_position() - Vector2(320,180)
	var evening: bool = loop.state.get_time_minutes() >= 1020
	var colors := [Color("e9c1ba"),Color("dfcf94"),Color("c58b57"),Color("c5d6d1")]
	for i in range(16 if evening else 10):
		var drift := elapsed * (4.0 if evening else 7.0)
		var x := fposmod(float(i*137) + drift + sin(elapsed*0.4+i)*12.0, 672.0) - 16.0
		var y := fposmod(float(i*73) + elapsed*(1.0 if evening else 3.0), 392.0) - 16.0
		var at := (origin + Vector2(x,y)).round()
		var color: Color = Color("e9d891") if evening else colors[season]
		color.a = 0.35 + sin(elapsed*1.4+i)*0.12 if evening else 0.42
		draw_rect(Rect2(at,Vector2(2,1)),color)
		if season == 2 and not evening: draw_rect(Rect2(at+Vector2(1,1),Vector2(1,1)),color)
