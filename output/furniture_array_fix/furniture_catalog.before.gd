extends RefCounted
## Stable recipe IDs and collision geometry shared by gameplay and save validation.
const ART := "res://Art/Environment/Hearthwood/"
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const House = preload("res://Scenes/Building/house_catalog.gd")
const IDS := ["stool", "table", "bookcase", "sofa", "desk", "bed", "chest"]
const RECIPES := {
	"stool": {"title": "木凳", "wood": 2, "iron": 0, "size": Vector2(18, 10)},
	"table": {"title": "圆木桌", "wood": 6, "iron": 0, "size": Vector2(76, 36)},
	"bookcase": {"title": "魔女书柜", "wood": 10, "iron": 1, "size": Vector2(104, 46)},
	"sofa": {"title": "软垫沙发", "wood": 8, "iron": 1, "size": Vector2(88, 38)},
	"desk": {"title": "书写桌", "wood": 6, "iron": 1, "size": Vector2(80, 30)},
	"bed": {"title": "星纹小床", "wood": 12, "iron": 2, "size": Vector2(82, 70)},
	"chest": {"title": "木箱", "wood": 8, "iron": 0, "size": Vector2(40, 20)},
}
const FLOOR := Rect2(64, 128, 512, 288)
const ENTRY := Rect2(296, 368, 48, 56)
const GRID := 16
const MAX_PLACED := 64
const MAX_STOCK := 999

static func texture(kind: String) -> Texture2D:
	return load(ART + "home_" + kind + (".svg" if kind == "chest" else ".png"))

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

static func placement_error(data: Dictionary, kind: String, point: Vector2, ignored_id: int = -1, player: Vector2 = Vector2.INF) -> String:
	if kind not in IDS or not point.is_finite(): return "无法摆放家具。"
	var rect := footprint(kind, point)
	var floor := House.floor_for(data)
	if not floor.encloses(rect): return "超出房间地板范围。"
	if rect.intersects(ENTRY): return "门口通道被占用。"
	for solid in fixed_solids(data):
		if rect.intersects(solid): return "这里已有家具。"
	var obstacles := fixed_solids(data)
	for item in data.placed:
		if item.id == ignored_id: continue
		var other := footprint(item.kind, position_of(item))
		if rect.intersects(other): return "这里已有家具。"
		obstacles.append(other)
	if player.is_finite():
		if rect.intersects(Rect2(player - Vector2(5, 6), Vector2(10, 6))): return "这里站着小女巫。"
		obstacles.append(rect)
		if not _exit_reachable(obstacles, player, floor): return "通往门口的道路被阻塞。"
	return ""

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
		var amount: Variant = value.stock.get(kind, 0 if kind == "chest" else null)
		if not _integer(amount, 0, MAX_STOCK): return {}
		result.stock[kind] = int(amount)
	var used := {}
	for item in value.placed:
		if not item is Dictionary or item.get("kind") not in IDS: return {}
		if not _integer(item.get("id"), 1, int(value.next_id) - 1) or item.id in used: return {}
		if not _integer(item.get("x"), 0, 640) or not _integer(item.get("y"), 0, 480): return {}
		if not placement_error(result, item.kind, position_of(item)).is_empty(): return {}
		used[item.id] = true
		var placed := {"id": int(item.id), "kind": item.kind, "x": int(item.x), "y": int(item.y)}
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
