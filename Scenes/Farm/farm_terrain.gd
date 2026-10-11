extends RefCounted
## Stable tile IDs preserve the original 96 plots while opening the whole farm.
const WORLD_SIZE := Vector2i(1440, 960)
const TILE := 32
const FIELD := Rect2(32, 16, 1376, 928)
const COLUMNS := 43
const ROWS := 29
const TILE_COUNT := COLUMNS * ROWS
const LEGACY_ORIGIN := Vector2i(5, 11)
static var cells: Array[Vector2i] = _make_cells()
static var indices: Dictionary = _make_indices()
static var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Environment/Hearthwood/farm_layout.json"))
static var obstacles: Dictionary = _make_obstacles()

static func _make_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in range(96):
		result.append(LEGACY_ORIGIN + Vector2i(index % 12, index / 12))
	for y in range(ROWS):
		for x in range(COLUMNS):
			if x >= 5 and x < 17 and y >= 11 and y < 19: continue
			result.append(Vector2i(x, y))
	return result

static func _make_indices() -> Dictionary:
	var result := {}
	for index in range(cells.size()): result[cells[index]] = index
	return result

static func tile_center(index: int) -> Vector2:
	return FIELD.position + Vector2(cells[index]) * TILE + Vector2.ONE * TILE / 2.0

static func index_at(point: Vector2) -> int:
	if not FIELD.has_point(point): return -1
	return indices.get(Vector2i((point - FIELD.position) / TILE), -1)

static func _make_obstacles() -> Dictionary:
	var result := {}
	for index in range(TILE_COUNT):
		var rect := Rect2(tile_center(index) - Vector2(15, 15), Vector2(30, 30))
		for building in layout.unplantable:
			if rect.intersects(Rect2(building[0], building[1], building[2], building[3])):
				result[index] = "house"
	for item in layout.props:
		for index in item.get("tiles", []): result[int(index)] = item.resource_id
	return result

static func can_till(state, index: int) -> bool:
	if index < 0 or index >= TILE_COUNT: return false
	var cell := Rect2(tile_center(index) - Vector2(15, 15), Vector2(30, 30))
	if cell.intersects(state.Furniture.footprint("workbench", state.Furniture.STARTER_BENCH)): return false
	for item in state.furniture.placed:
		if state.Furniture.area_of(item) == "farm" and cell.intersects(state.Furniture.footprint(item.kind, state.Furniture.position_of(item))): return false
	# Existing crops remain usable when opening an older save.
	if state.farm.plots.has(str(index)): return true
	var obstacle: String = obstacles.get(index, "")
	return obstacle.is_empty() or (obstacle != "house" and state.resource_left(obstacle) <= 0)
