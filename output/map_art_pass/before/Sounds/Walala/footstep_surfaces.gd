extends RefCounted
## Geometry matches Hearthwood/tools/build_art.py's ground drawing.
const TOWN_ROADS = [
	Rect2(32, 312, 1216, 104), Rect2(32, 632, 1216, 104),
	Rect2(360, 32, 96, 896), Rect2(760, 32, 96, 896),
	Rect2(32, 32, 1216, 48), Rect2(32, 880, 1216, 48),
	Rect2(32, 32, 64, 896), Rect2(1184, 32, 64, 896),
]
const FIELD_PATH = [
	Vector2(25, 282), Vector2(62, 256), Vector2(47, 130),
	Vector2(65, 86), Vector2(95, 85), Vector2(75, 135),
	Vector2(87, 245), Vector2(417, 250), Vector2(420, 275),
	Vector2(77, 273), Vector2(45, 297),
]
var town_paths: Array[Rect2] = []
var town_plots: Array[Rect2] = []
var town_routes: Array = []
var town_plazas: Array = []
var outdoor_routes := {}

func configure(layout: Dictionary) -> void:
	town_paths.clear()
	town_plots.clear()
	town_routes = layout.get("paths", [])
	town_plazas = layout.get("plazas", [])
	for region in ["farm", "field", "dock"]:
		var area: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Environment/Hearthwood/" + region + "_layout.json"))
		outdoor_routes[region] = area.get("paths", [])
	for building in layout.buildings:
		town_paths.append(Rect2(building.x - 18, building.y - 1, 37, mini(building.y + 28, int(layout.size[1]) - 1) - building.y + 2))
		town_plots.append(Rect2(building.x - 109, building.y - 153, 218, 168))

func resolve(location: String, position: Vector2, weather: String) -> String:
	if location == "blacksmith":
		return "stone" if Rect2(57, 122, 322, 241).has_point(position) else "wood"
	if location in ["home", "restaurant", "blacksmith", "store", "furniture_store"]:
		return "wood"
	if weather == "snow":
		return "snow"
	for route in outdoor_routes.get(location, []):
		for i in range(route.points.size() - 1):
			var a := Vector2(route.points[i][0], route.points[i][1])
			var b := Vector2(route.points[i + 1][0], route.points[i + 1][1])
			if position.distance_to(Geometry2D.get_closest_point_to_segment(position, a, b)) <= route.width / 2.0:
				return route.surface
	if location == "farm":
		return "grass"
	if location == "dock":
		if Rect2(176, 204, 160, 63).has_point(position) or Rect2(328, 132, 204, 169).has_point(position):
			return "wood"
		return "dirt" if position.y >= 222 or position.x >= 159 else "grass"
	if location == "field":
		return "dirt" if Geometry2D.is_point_in_polygon(position, PackedVector2Array(FIELD_PATH)) else "grass"
	for rect in town_paths:
		if rect.has_point(position):
			return "stone"
	if not town_routes.is_empty():
		for plaza in town_plazas:
			var polygon := PackedVector2Array()
			for point in plaza.points:
				polygon.append(Vector2(point[0], point[1]))
			if Geometry2D.is_point_in_polygon(position, polygon):
				return plaza.surface
		for surface in ["wood", "stone", "dirt"]:
			for route in town_routes:
				if route.surface != surface:
					continue
				for i in range(route.points.size() - 1):
					var a := Vector2(route.points[i][0], route.points[i][1])
					var b := Vector2(route.points[i + 1][0], route.points[i + 1][1])
					if position.distance_to(Geometry2D.get_closest_point_to_segment(position, a, b)) <= route.width / 2.0:
						return surface
		for rect in town_plots:
			if rect.has_point(position):
				return "dirt"
		return "grass"
	for rect in town_plots:
		if rect.has_point(position):
			return "dirt"
	for rect in TOWN_ROADS:
		if rect.has_point(position):
			return "stone"
	return "grass"
