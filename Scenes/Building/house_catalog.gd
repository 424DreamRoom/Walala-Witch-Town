extends RefCounted
## Room geometry and expansion costs are shared by art, placement and saves.
const FLOORS := [Rect2(224, 288, 192, 128), Rect2(160, 208, 320, 208), Rect2(64, 128, 512, 288)]
const TITLES := ["小空屋", "舒适小屋", "宽敞之家"]
const COSTS := [{"coins": 120, "wood": 30, "iron": 3}, {"coins": 400, "wood": 80, "iron": 8}]
const MAX_LEVEL := 2

static func floor_for(data: Dictionary) -> Rect2:
	return FLOORS[int(data.get("house_level", MAX_LEVEL))]

static func world_size(data: Dictionary) -> Vector2i:
	if data.get("legacy_fixtures", true): return Vector2i(640, 480)
	return Vector2i(640, maxi(480, int(floor_for(data).get_center().y) + 180))

static func ground_path(data: Dictionary) -> String:
	return "res://Art/Environment/Hearthwood/home_ground.aseprite" if data.get("legacy_fixtures", true) else "res://Art/Environment/Hearthwood/home_empty_%d.aseprite" % int(data.house_level)

static func walls(data: Dictionary) -> Array[Rect2]:
	var floor := floor_for(data)
	var left := floor.position.x - 12
	var right := floor.end.x
	return [
		Rect2(left, floor.position.y - 48, floor.size.x + 24, 48),
		Rect2(left, floor.position.y, 12, floor.size.y + 12),
		Rect2(right, floor.position.y, 12, floor.size.y + 12),
		Rect2(left, 416, 296 - left, 12), Rect2(344, 416, right + 12 - 344, 12),
		Rect2(284, 428, 12, 52), Rect2(344, 428, 12, 52), Rect2(284, 476, 72, 8)
	]
