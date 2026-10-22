extends RefCounted
## One geometry source for play, collision, footsteps and the paused atlas.
const ROOT := "res://Art/WorldPolish/"
const Source = preload("res://Art/Source/aseprite_source.gd")
static var layouts := {}
static var terrain_sets := {}

static func get_region(id: String) -> Dictionary:
	if not layouts.has(id):
		layouts[id] = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + ".json"))
	return layouts[id]

static func ground(id: String) -> TileMapLayer:
	var layout := get_region(id)
	if not terrain_sets.has(id):
		var set := TileSet.new()
		set.tile_size = Vector2i(16, 16)
		var atlas := TileSetAtlasSource.new()
		atlas.texture = Source.texture(layout.ground)
		atlas.texture_region_size = Vector2i(16, 16)
		for y in range(23):
			for x in range(40): atlas.create_tile(Vector2i(x, y))
		set.add_source(atlas, 0)
		terrain_sets[id] = set
	var result := TileMapLayer.new()
	result.name = "RegionTerrain"
	result.tile_set = terrain_sets[id]
	for y in range(23):
		for x in range(40): result.set_cell(Vector2i(x, y), 0, Vector2i(x, y))
	return result

static func surface(id: String, point: Vector2) -> String:
	var layout := get_region(id)
	for route in layout.routes:
		for index in range(1, route.size()):
			var a := Vector2(route[index - 1][0], route[index - 1][1])
			var b := Vector2(route[index][0], route[index][1])
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) <= 14.0:
				return "wood" if id == "marsh" else "stone" if id in ["quarry", "ruins", "ridge", "observatory"] else "dirt"
	return "grass"
