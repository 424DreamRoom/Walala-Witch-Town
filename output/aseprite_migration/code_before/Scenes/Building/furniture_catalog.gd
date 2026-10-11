extends RefCounted
## Stable recipe IDs and collision geometry shared by gameplay and save validation.
const ART := "res://Art/Environment/Hearthwood/"
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const House = preload("res://Scenes/Building/house_catalog.gd")
const Data = preload("res://Scenes/Building/construction_recipes.gd")
const FarmTerrain = preload("res://Scenes/Farm/farm_terrain.gd")
const IDS := Data.IDS
const RECIPES := Data.RECIPES
const CATEGORIES := Data.CATEGORIES
const LEGACY_IDS := ["stool", "table", "bookcase", "sofa", "desk", "bed", "chest"]
const STARTER_BENCH := Vector2(416, 288)
const WORKBENCH_REACH := 32.0
const FLOOR := Rect2(64, 128, 512, 288)
const ENTRY := Rect2(296, 368, 48, 56)
const GRID := 16
const MAX_PLACED := 256
const MAX_STOCK := 999

static func texture(kind: String) -> Texture2D:
	if kind == "chest": return load("res://Art/Props/KarsioriChest/closed.png")
	if kind not in LEGACY_IDS: return load("res://Art/Building/objects/" + kind + ".svg")
	return load(ART + "home_" + kind + ".png")

static func icon(kind: String) -> Texture2D:
	return load("res://Art/Building/icons/" + kind + ".svg")

static func area_of(item: Dictionary) -> String:
	return item.get("area", "home")

static func blocking(kind: String) -> bool:
	return RECIPES[kind].solid and kind not in ["wood_gate", "iron_gate", "rose_arch"]

static func floor_for(data: Dictionary, area: String) -> Rect2:
	return FarmTerrain.FIELD if area == "farm" else House.floor_for(data)

static func bench_at(data: Dictionary, area: String, player: Vector2) -> bool:
	return bench_distance(data, area, player) <= WORKBENCH_REACH

static func bench_distance(data: Dictionary, area: String, player: Vector2) -> float:
	if area not in ["home", "farm"] or not player.is_finite(): return INF
	var benches: Array[Vector2] = []
	if area == "farm": benches.append(STARTER_BENCH)
	for item in data.placed:
		if item.kind == "workbench" and area_of(item) == area: benches.append(position_of(item))
	var distance := INF
	for anchor in benches:
		var rect := footprint("workbench", anchor)
		distance = minf(distance, player.distance_to(player.clamp(rect.position, rect.end)))
	return distance

static func costs(kind: String) -> Dictionary:
	var result := {}
	for id in ["wood", "iron", "ore"]:
		if RECIPES[kind][id] > 0: result[id] = -RECIPES[kind][id]
	return result

static func initial_data() -> Dictionary:
	var result := {"stock": {}, "placed": [], "next_id": 1, "house_level": 0, "legacy_fixtures": false}
	for kind in IDS: result.stock[kind] = 0
	return result

static func legacy_data() -> Dictionary:
	var result := initial_data()
	result.house_level = House.MAX_LEVEL
	result.legacy_fixtures = true
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "home_layout.json"))
	for item in layout.furniture:
		var kind: String = item.kind.trim_prefix("home_")
		if kind not in IDS: continue
		result.placed.append({"id": result.next_id, "kind": kind, "x": int(item.x), "y": int(item.y)})
		result.next_id += 1
	return result

static func position_of(item: Dictionary) -> Vector2:
	return Vector2(item.x, item.y)

static func footprint(kind: String, point: Vector2) -> Rect2:
	var dimensions: Vector2 = RECIPES[kind].size
	return Rect2(point - Vector2(dimensions.x / 2.0, dimensions.y), dimensions)

static func fixed_solids(data: Dictionary = {}) -> Array[Rect2]:
	# These fixtures remain part of the house; the other furnishings are movable.
	var result: Array[Rect2] = []
	if data.get("legacy_fixtures", true):
		result.assign([Rect2(221, 163, 112, 42), Rect2(406, 165, 92, 42)])
	return result

static func placement_error(data: Dictionary, kind: String, point: Vector2, ignored_id: int = -1, player: Vector2 = Vector2.INF, area: String = "home", world: Dictionary = {}) -> String:
	if kind not in IDS or not point.is_finite(): return "无法摆放家具。"
	if area not in ["home", "farm"]: return "无法摆放家具。"
	if RECIPES[kind].area not in ["both", area]: return "建造物与场地不符。"
	var rect := footprint(kind, point)
	var floor := floor_for(data, area)
	if not floor.encloses(rect): return "超出建造范围。"
	if area == "home" and rect.intersects(ENTRY): return "门口通道被占用。"
	if area == "farm":
		var farm_error := farm_placement_error(kind, rect, world)
		if not farm_error.is_empty(): return farm_error
	var obstacles: Array[Rect2] = []
	if area == "home": obstacles = fixed_solids(data)
	for solid in obstacles:
		if rect.intersects(solid): return "这里已有家具。"
	for item in data.placed:
		if item.id == ignored_id or area_of(item) != area: continue
		var other := footprint(item.kind, position_of(item))
		if RECIPES[kind].solid == RECIPES[item.kind].solid and rect.intersects(other): return "这里已有家具。"
		if blocking(item.kind): obstacles.append(other)
	if player.is_finite() and blocking(kind):
		if rect.intersects(Rect2(player - Vector2(5, 6), Vector2(10, 6))): return "这里站着小女巫。"
		obstacles.append(rect)
		if area == "home" and not _exit_reachable(obstacles, player, floor): return "通往门口的道路被阻塞。"
		if area == "farm" and not farm_exit_reachable(obstacles, player, world): return "通往门口的道路被阻塞。"
	return ""

static func farm_placement_error(kind: String, rect: Rect2, world: Dictionary) -> String:
	var layout := FarmTerrain.layout
	for building in layout.buildings:
		var size := Vector2(building.w, building.h)
		if rect.intersects(Rect2(Vector2(building.x - size.x / 2, building.y - size.y), size)): return "土地被占用。"
	if rect.intersects(footprint("workbench", STARTER_BENCH)): return "土地被占用。"
	for water in layout.water:
		if rect.intersects(Rect2(water[0], water[1], water[2], water[3])): return "土地被占用。"
	# Keep the authored route from the front door to town open even with long fences.
	if blocking(kind):
		for route in layout.get("clearance_routes", []):
			for index in range(1, route.points.size()):
				var a := Vector2(route.points[index - 1][0], route.points[index - 1][1])
				var b := Vector2(route.points[index][0], route.points[index][1])
				var corridor := Rect2(a.min(b), (a - b).abs()).grow(route.width / 2.0)
				if rect.intersects(corridor): return "门口通道被占用。"
	if world.is_empty(): return ""
	for item in layout.props:
		if world.resource_damage.get(item.resource_id, 0) >= 3: continue
		# Existing cultivated land takes precedence over vegetation in old saves.
		if item.tiles.any(func(index): return world.farm.plots.has(str(int(index)))): continue
		if rect.intersects(Rect2(item.x - item.w / 2.0, item.y - item.h, item.w, item.h)): return "土地被占用。"
	for key in world.farm.plots:
		if rect.intersects(Rect2(FarmTerrain.tile_center(int(key)) - Vector2(15, 15), Vector2(30, 30))): return "土地被占用。"
	return ""

static func farm_exit_reachable(obstacles: Array[Rect2], player: Vector2, world: Dictionary = {}) -> bool:
	# Flood-fill coarse farm cells; the protected front-door road is the destination.
	var floor := FarmTerrain.FIELD
	var origin := floor.position + Vector2(8, 8)
	var columns := int(floor.size.x / 16)
	var rows := int(floor.size.y / 16)
	var blocked := {}
	for building in FarmTerrain.layout.buildings:
		obstacles.append(Rect2(building.x - building.w / 2.0, building.y - building.h, building.w, building.h))
	obstacles.append(footprint("workbench", STARTER_BENCH))
	if not world.is_empty():
		for item in FarmTerrain.layout.props:
			if world.resource_damage.get(item.resource_id, 0) < 3 and not item.tiles.any(func(index): return world.farm.plots.has(str(int(index)))):
				obstacles.append(Rect2(item.x - item.w / 2.0, item.y - item.h, item.w, item.h))
	for obstacle in obstacles:
		var expanded := obstacle.grow(6)
		for y in range(maxi(0, floori((expanded.position.y - origin.y) / 16)), mini(rows, ceili((expanded.end.y - origin.y) / 16) + 1)):
			for x in range(maxi(0, floori((expanded.position.x - origin.x) / 16)), mini(columns, ceili((expanded.end.x - origin.x) / 16) + 1)):
				if expanded.has_point(origin + Vector2(x, y) * 16): blocked[Vector2i(x, y)] = true
	var start := Vector2i(clampi(roundi((player.x - origin.x) / 16), 0, columns - 1), clampi(roundi((player.y - origin.y) / 16), 0, rows - 1))
	if start in blocked: return false
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var point := origin + Vector2(cell) * 16
		if point.y >= 300 and point.y <= 344 and point.x >= 270: return true
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + delta
			if next.x < 0 or next.x >= columns or next.y < 0 or next.y >= rows or next in seen or next in blocked: continue
			seen[next] = true
			queue.append(next)
	return false

static func _exit_reachable(obstacles: Array[Rect2], player: Vector2, floor: Rect2 = FLOOR) -> bool:
	# Flood-fill an 8-pixel walking grid, using the same feet clearance as the avatar.
	var origin := floor.position + Vector2(4, 4)
	var columns := int(floor.size.x / 8)
	var rows := int(floor.size.y / 8)
	var blocked := {}
	for obstacle in obstacles:
		var expanded := obstacle.grow(6.0)
		for y in range(maxi(0, floori((expanded.position.y - origin.y) / 8.0)), mini(rows, ceili((expanded.end.y - origin.y) / 8.0) + 1)):
			for x in range(maxi(0, floori((expanded.position.x - origin.x) / 8.0)), mini(columns, ceili((expanded.end.x - origin.x) / 8.0) + 1)):
				if expanded.has_point(origin + Vector2(x, y) * 8): blocked[Vector2i(x, y)] = true
	var start := Vector2i(clampi(roundi((player.x - origin.x) / 8.0), 0, columns - 1), clampi(roundi((player.y - origin.y) / 8.0), 0, rows - 1))
	if start in blocked: return false
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell.y >= rows - 2 and ENTRY.has_point(origin + Vector2(cell) * 8): return true
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + delta
			if next.x < 0 or next.x >= columns or next.y < 0 or next.y >= rows or next in blocked or next in seen: continue
			seen[next] = true
			queue.append(next)
	return false

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and float(value) == floorf(float(value))

static func normalize(value: Variant, legacy_inventory: bool = false) -> Dictionary:
	if not value is Dictionary or not value.get("stock") is Dictionary or not value.get("placed") is Array: return {}
	if value.placed.size() > MAX_PLACED or not _integer(value.get("next_id"), 1, 1000000000): return {}
	var level: Variant = value.get("house_level", House.MAX_LEVEL)
	var fixtures: Variant = value.get("legacy_fixtures", not value.has("house_level"))
	if not _integer(level, 0, House.MAX_LEVEL) or not fixtures is bool: return {}
	if fixtures and int(level) != House.MAX_LEVEL: return {}
	for kind in value.stock:
		if kind not in IDS: return {}
	var result := {"stock": {}, "placed": [], "next_id": int(value.next_id), "house_level": int(level), "legacy_fixtures": fixtures}
	for kind in IDS:
		var amount: Variant = value.stock.get(kind, null if kind in LEGACY_IDS and kind != "chest" else 0)
		if not _integer(amount, 0, MAX_STOCK): return {}
		result.stock[kind] = int(amount)
	var used := {}
	for item in value.placed:
		if not item is Dictionary or item.get("kind") not in IDS: return {}
		if not _integer(item.get("id"), 1, int(value.next_id) - 1) or item.id in used: return {}
		var area: Variant = item.get("area", "home")
		if area not in ["home", "farm"]: return {}
		if not _integer(item.get("x"), 0, 1440 if area == "farm" else 640) or not _integer(item.get("y"), 0, 960 if area == "farm" else 480): return {}
		if not placement_error(result, item.kind, position_of(item), -1, Vector2.INF, area).is_empty(): return {}
		used[item.id] = true
		var placed := {"id": int(item.id), "kind": item.kind, "x": int(item.x), "y": int(item.y)}
		if area == "farm": placed.area = area
		if item.kind == "chest":
			if item.has("slots"):
				var grid := Items.normalize_slots(item.slots, Items.CHEST_SLOTS, legacy_inventory)
				if not grid.ok: return {}
				placed["slots"] = grid.slots
				placed["items"] = Items.totals(grid.slots)
				if item.has("items"):
					var counts := Items.normalize_contents(item.items, Items.CHEST_SLOTS * Items.STACK_SIZE, legacy_inventory)
					if not counts.ok or counts.items != placed.items: return {}
			else:
				var contents := Items.normalize_contents(item.get("items", {}), Items.STACK_SIZE, legacy_inventory)
				if not contents.ok: return {}
				placed["items"] = contents.items
				Items.chest_slots(placed)
		elif item.has("items") or item.has("slots"): return {}
		result.placed.append(placed)
	return result
