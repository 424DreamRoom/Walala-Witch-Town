extends RefCounted
## Room geometry and expansion costs are shared by art, placement and saves.
const FLOORS := [Rect2(224, 288, 192, 128), Rect2(160, 208, 320, 208), Rect2(64, 128, 512, 288)]
const TITLES := ["小空屋", "舒适小屋", "宽敞之家"]
const COSTS := [{"coins": 120, "wood": 30, "iron": 3}, {"coins": 400, "wood": 80, "iron": 8}]
const MAX_LEVEL := 2
const OUTDOOR_SIZES := [Vector2(160, 96), Vector2(208, 112), Vector2(256, 128)]
const OUTDOOR_ANCHOR := Vector2(270, 250)
static var exterior_textures := {}

static func upgrade_for(data: Dictionary) -> Dictionary:
	var inside := int(data.get("house_level", MAX_LEVEL))
	var outside := int(data.get("exterior_level", 0))
	if outside < inside:
		# Existing large interiors can buy the new land extensions independently.
		return {"house_level": inside, "exterior_level": outside + 1, "price": COSTS[outside]}
	if inside >= MAX_LEVEL: return {}
	return {"house_level": inside + 1, "exterior_level": outside + 1, "price": COSTS[inside]}

static func outdoor_footprint(data: Dictionary) -> Rect2:
	# Old furnished saves retain the original exterior until a new expansion.
	var level := int(data.get("exterior_level", 0))
	var dimensions: Vector2 = OUTDOOR_SIZES[level]
	return Rect2(OUTDOOR_ANCHOR - Vector2(dimensions.x / 2.0, dimensions.y), dimensions)

static func exterior_texture(data: Dictionary) -> Texture2D:
	var level := int(data.get("exterior_level", 0))
	if not exterior_textures.has(level):
		var original := preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Environment/Hearthwood/shop_0.aseprite")
		if level == 0: exterior_textures[level] = original
		else:
			# Native tiles form side wings; the original house is composited whole.
			var source := original.get_image()
			var extra := level * 24
			var wide := Image.create(source.get_width() + extra * 2, source.get_height(), false, Image.FORMAT_RGBA8)
			for left in [0, extra + source.get_width() - 8]:
				_tile(wide, source, Rect2i(16, 40, 16, 16), Rect2i(left, 40, extra + 8, 80))
				_tile(wide, source, Rect2i(16, 116, 16, 12), Rect2i(left, 120, extra + 8, 12))
				_tile(wide, source, Rect2i(64, 144, 16, 16), Rect2i(left, 132, extra + 8, 52))
				_tile(wide, source, Rect2i(64, 176, 16, 8), Rect2i(left, 184, extra + 8, 8))
				_tile(wide, source, Rect2i(8, 128, 4, 32), Rect2i(left, 132, 4, 52))
				if level == 2: wide.blend_rect(source, Rect2i(56, 56, 48, 56), Vector2i(left + 2, 60))
			wide.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(extra, 0))
			exterior_textures[level] = ImageTexture.create_from_image(wide)
	return exterior_textures[level]

static func _tile(destination: Image, source: Image, sample: Rect2i, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y, sample.size.y):
		for x in range(area.position.x, area.end.x, sample.size.x):
			var piece := Rect2i(sample.position, Vector2i(mini(sample.size.x, area.end.x - x), mini(sample.size.y, area.end.y - y)))
			destination.blit_rect(source, piece, Vector2i(x, y))

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
