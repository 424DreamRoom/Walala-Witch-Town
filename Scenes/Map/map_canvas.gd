extends Control
## Read-only cartography shares the gameplay layouts, crops and furniture.
signal region_selected(region: String)
const ART := "res://Art/Environment/Hearthwood/"
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const Furniture = preload("res://Scenes/Building/furniture_catalog.gd")
const FarmTerrain = preload("res://Scenes/Farm/farm_terrain.gd")
const PLACES := {"town": "哗啦啦魔女镇", "farm": "月芽农场", "field": "微光采集地", "dock": "潮汐码头", "home": "小女巫的家", "restaurant": "小镇餐厅", "store": "橡果杂货店", "blacksmith": "余烬铁匠铺", "furniture_store": "榛木家具店"}
const WORLD_RECTS := {"town": Rect2(166, 58, 148, 142), "farm": Rect2(4, 64, 126, 94), "field": Rect2(205, 1, 100, 56), "dock": Rect2(344, 138, 44, 25)}
const REGION_SIZES := {"farm": Vector2(1440, 960), "field": Vector2(640, 360), "dock": Vector2(640, 360), "home": Vector2(640, 480), "restaurant": Vector2(640, 360), "store": Vector2(640, 480), "blacksmith": Vector2(640, 480), "furniture_store": Vector2(640, 480)}
var loop
var view := "world"
var layouts := {}
var textures := {}
var markers: Array[Dictionary] = []
var hit_regions: Array[Dictionary] = []
var player_point := Vector2.INF
var map_rect := Rect2()
var hovered := ""
var elapsed := 0.0

const MAP_INK := Color("4b392f")
const MAP_EDGE := Color("6d523b")
const MAP_HIGHLIGHT := Color("efd39a")
const MAP_ROUTE := Color("6a573d")
const MAP_ROUTE_HIGHLIGHT := Color("d6b276")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	for region in PLACES:
		if region != "restaurant":
			layouts[region] = JSON.parse_string(FileAccess.get_file_as_string(ART + region + "_layout.json"))
		texture_for("store_ground" if region == "furniture_store" else region + ("_background" if region in ["field", "restaurant"] else "_ground"))
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(func(): hovered = ""; tooltip_text = "")

func texture_for(kind: String) -> Texture2D:
	if not textures.has(kind):
		var ground_kind := "restaurant_ground" if kind == "restaurant_background" else kind
		if FileAccess.file_exists(ART + ground_kind + ".tiles.json"):
			var compact_scene := ART + ground_kind.trim_suffix("_ground") + "_compact_ground.tilemap.tscn" if ground_kind in ["store_ground", "blacksmith_ground", "restaurant_ground"] else ""
			textures[kind] = preload("res://Art/Source/tile_ground.gd").preview(ART + ground_kind + ".aseprite", compact_scene)
		else:
			textures[kind] = Furniture.texture(kind.trim_prefix("built_")) if kind.begins_with("built_") else Furniture.texture("chest") if kind == "home_chest" else load(ART + kind + ".aseprite")
	return textures[kind]

func region_items(region: String) -> Array:
	if region == "restaurant": return []
	var layout: Dictionary = layouts[region]
	var items: Array = layout.get("buildings", []).duplicate(true)
	items.append_array(layout.get("props", []))
	for item in layout.get("furniture", []):
		if region == "home" and (not loop.state.furniture.legacy_fixtures or item.kind.trim_prefix("home_") in Furniture.IDS): continue
		items.append(item)
	if region in ["home", "farm"]:
		for item in loop.state.furniture.placed:
			if Furniture.area_of(item) == region:
				items.append({"kind": ("home_" if region == "home" and item.kind in Furniture.LEGACY_IDS else "built_") + item.kind, "x": item.x, "y": item.y, "ground": not Furniture.RECIPES[item.kind].solid})
		if region == "farm": items.append({"kind": "built_workbench", "x": Furniture.STARTER_BENCH.x, "y": Furniture.STARTER_BENCH.y})
	items.sort_custom(func(a, b): return a.get("ground", false) if a.get("ground", false) != b.get("ground", false) else a.y < b.y)
	return items

func region_markers(region: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if region == "field" and loop.state.campaign.region != "field":
		var area: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Campaign/maps/"+loop.state.campaign.region+".json"))
		var definition: Dictionary = loop.state.Campaign.entry(loop.state.Content.DATA.regions,loop.state.campaign.region)
		for index in range(area.gather_points.size()):
			var point: Array = area.gather_points[index]
			var id: String = definition.items[index%definition.items.size()]
			result.append({"point":Vector2(point[0],point[1]),"label":loop.state.Content.DATA.items[id].name,"target":"","type":"field"})
		result.append({"point":Vector2(500,232),"label":"钓鱼点","target":"","type":"field"})
		return result
	if region == "town":
		for key in layouts.town.gates:
			var point: Array = layouts.town.gates[key]
			result.append({"point": Vector2(point[0], point[1]), "label": PLACES[key], "target": key})
		if loop.property_service != null:
			result.append({"point": loop.property_service.actor.position, "label": "房地产魔女", "target": "town", "type": "property"})
	elif region == "farm":
		result.append({"point": Furniture.STARTER_BENCH, "label": "建造工作台", "target": ""})
		for key in ["home", "exit", "refill"]:
			var point: Array = layouts.farm[key]
			result.append({"point": Vector2(point[0], point[1]), "label": {"home": "小女巫的家", "exit": "前往小镇", "refill": "房屋水源"}[key], "target": "home" if key == "home" else "town" if key == "exit" else ""})
	elif region == "restaurant":
		for spec in [[Vector2(24, 248), "前往小镇"], [Vector2(110, 130), "备料台"], [Vector2(230, 130), "料理台"]]:
			result.append({"point": spec[0], "label": spec[1], "target": "town" if spec[0].x == 24 else ""})
	else:
		var point: Array = layouts[region].get("exit", [24, 280])
		result.append({"point": Vector2(point[0], point[1]), "label": "前往农场" if region == "home" else "前往小镇", "target": "farm" if region == "home" else "town"})
		if region in ["store", "blacksmith", "furniture_store"]:
			var service: Array = layouts[region].service
			result.append({"point": Vector2(service[0], service[1]), "label": "柜台服务", "target": ""})
		if region in ["field", "dock"]:
			for item in layouts[region].props:
				if item.get("resource_type", "") != "fish": continue
				var anchor: Array = item.get("anchor", [item.x, item.y + 28])
				result.append({"point": Vector2(anchor[0], anchor[1]), "label": "钓鱼点", "target": "", "type": "field"})
	return result

func outdoor_region() -> String:
	if loop.location == "home": return "farm"
	if loop.location in ["restaurant", "store", "blacksmith", "furniture_store"]: return "town"
	return loop.location

func player_anchor(region: String) -> Vector2:
	if region == loop.location: return loop.lane.player.position
	if region != outdoor_region(): return Vector2.INF
	var point: Array = layouts.farm.home if loop.location == "home" else layouts.town.gates[loop.location]
	return Vector2(point[0], point[1])

func region_size(region: String) -> Vector2:
	if region == "farm": return Vector2(FarmTerrain.WORLD_SIZE)
	if region == "town":
		return Vector2(layouts.town.size[0], layouts.town.size[1])
	return Vector2(Furniture.House.world_size(loop.state.furniture)) if region == "home" else REGION_SIZES[region]

func project(point: Vector2, region: String, rect: Rect2) -> Vector2:
	return (rect.position + point / region_size(region) * rect.size).round()

func detail_rect(region: String) -> Rect2:
	var available := size - Vector2(16, 16)
	var dimensions: Vector2 = region_size(region)
	var scale_factor := minf(available.x / dimensions.x, available.y / dimensions.y)
	var displayed := (dimensions * scale_factor).floor()
	return Rect2(((size - displayed) / 2.0).floor(), displayed)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw_route(start: Vector2, finish: Vector2, width: float = 6.0) -> void:
	# Two-tone hand-inked routes keep the stitched regional thumbnails readable
	# while making the world connections feel like a single town plan.
	draw_line(start, finish, Color(MAP_ROUTE, 0.85), width + 2.0, true)
	draw_line(start, finish, Color(MAP_ROUTE_HIGHLIGHT, 0.92), width - 1.0, true)
	var steps := 6
	for index in range(1, steps):
		var point := start.lerp(finish, float(index) / float(steps))
		draw_circle(point, 1.5, Color(MAP_INK, 0.75))

func _draw_compass(center: Vector2, radius: float = 11.0) -> void:
	draw_circle(center, radius + 3.0, Color("c2a975"))
	draw_arc(center, radius + 3.0, 0.0, TAU, 24, Color(MAP_EDGE, 0.85), 1.0, true)
	var north := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.30, 0),
		center + Vector2(0, radius * 0.28),
	])
	var south := PackedVector2Array([
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.30, 0),
		center + Vector2(0, -radius * 0.28),
	])
	draw_colored_polygon(north, Color("76523f"))
	draw_colored_polygon(south, Color("ead39b"))
	draw_line(center + Vector2(-radius * 0.72, 0), center + Vector2(radius * 0.72, 0), Color(MAP_INK, 0.8), 1.0)
	draw_circle(center, 2.0, Color(MAP_INK))

func _draw_leaf_mark(center: Vector2, scale_factor: float = 1.0) -> void:
	var stem := PackedVector2Array([center + Vector2(-10, 8) * scale_factor, center + Vector2(2, -2) * scale_factor, center + Vector2(10, -9) * scale_factor])
	draw_polyline(stem, Color("6c7550"), 1.0, true)
	for point in [center + Vector2(-4, 3) * scale_factor, center + Vector2(2, -2) * scale_factor, center + Vector2(7, -7) * scale_factor]:
		draw_circle(point, 2.5 * scale_factor, Color("879566"))
		draw_circle(point + Vector2(1, -1) * scale_factor, 1.0 * scale_factor, Color("b6bd7b"))

func _draw_world_decorations() -> void:
	# The spare parchment around the four regions becomes a small cartographer's
	# margin instead of an empty block of color.
	var center := Vector2(143, 194)
	for radius in [18.0, 27.0, 36.0]:
		draw_arc(center, radius, PI * 0.18, PI * 1.22, 18, Color("8e8768", 0.34), 1.0, true)
	_draw_compass(Vector2(32, 204), 9.0)
	_draw_leaf_mark(Vector2(143, 206), 0.8)
	_draw_leaf_mark(Vector2(158, 214), 0.55)
	# Small ink nodes make the route junctions legible at the overview scale.
	for point in [Vector2(145, 178), Vector2(158, 188), Vector2(132, 211)]:
		draw_circle(point, 3.0, Color("7c6247"))
		draw_circle(point, 1.2, Color("e5c583"))

func _draw_detail_decorations(region: String, rect: Rect2) -> void:
	var ratio := rect.size / region_size(region)
	if region == "town":
		# A faint ring around Moonwell Square clarifies the civic center and the
		# branching streets without hiding the original pixel buildings.
		var square := project(Vector2(682, 482), region, rect)
		for radius in [18.0, 24.0]:
			draw_arc(square, radius, 0.0, TAU, 28, Color("eed294", 0.42), 1.0, true)
		var route := PackedVector2Array([
			project(Vector2(92, 364), region, rect),
			project(Vector2(682, 482), region, rect),
			project(Vector2(1120, 650), region, rect),
			project(Vector2(1592, 652), region, rect),
		])
		draw_polyline(route, Color("f1d597", 0.28), maxf(1.0, 2.0 * ratio.x), true)
	elif region == "farm":
		# The farm's cultivated center is framed as a soft field terrace, matching
		# the hand-drawn routes used by the town overview.
		var terrace := Rect2(project(Vector2(174, 360), region, rect), Vector2(850, 420) * ratio)
		draw_rect(terrace, Color("f0d6a0", 0.15), true)
		draw_rect(terrace, Color("7a6547", 0.42), false, 1.0)
	elif region == "field":
		for index in range(9):
			var point := project(Vector2(105 + (index % 3) * 135, 115 + (index / 3) * 66), region, rect)
			draw_arc(point, 5.0, 0.0, TAU, 12, Color("d8c687", 0.42), 1.0, true)
	elif region == "dock":
		# A few quiet wave strokes reinforce the shoreline in the compact dock map.
		for row in range(3):
			var y := rect.position.y + rect.size.y * (0.25 + float(row) * 0.23)
			var wave := PackedVector2Array([
				Vector2(rect.position.x + rect.size.x * 0.56, y),
				Vector2(rect.position.x + rect.size.x * 0.68, y - 2),
				Vector2(rect.position.x + rect.size.x * 0.80, y),
				Vector2(rect.position.x + rect.size.x * 0.92, y - 2),
			])
			draw_polyline(wave, Color("d0d9c1", 0.42), 1.0, true)

func _draw_map_frame(rect: Rect2) -> void:
	draw_rect(rect.grow(3), Color(MAP_EDGE, 0.95), false, 2.0)
	draw_rect(rect.grow(1), Color(MAP_HIGHLIGHT, 0.85), false, 1.0)
	var corner := 4.0
	for point in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var direction := Vector2(1, 1)
		if point.x > rect.get_center().x: direction.x = -1
		if point.y > rect.get_center().y: direction.y = -1
		draw_line(point, point + Vector2(corner * direction.x, 0), Color(MAP_INK, 0.8), 1.0)
		draw_line(point, point + Vector2(0, corner * direction.y), Color(MAP_INK, 0.8), 1.0)

func _draw_region(region: String, rect: Rect2) -> void:
	draw_rect(rect.grow(3), Color("715c41"))
	draw_rect(rect.grow(1), Color("d4b779"), false, 1.0)
	if region == "field" and loop.state.campaign.region != "field":
		var key: String = "campaign_"+loop.state.campaign.region
		if not textures.has(key): textures[key] = load("res://Art/Campaign/maps/"+loop.state.campaign.region+".aseprite")
		var ground: Texture2D = textures[key]
		draw_texture_rect(ground,rect,false)
		_draw_detail_decorations(region, rect)
		_draw_map_frame(rect)
		return
	var ground: Texture2D = texture_for(Furniture.House.ground_path(loop.state.furniture).get_file().get_basename()) if region == "home" else texture_for("store_ground" if region == "furniture_store" else region + ("_background" if region in ["field", "restaurant"] else "_ground"))
	draw_texture_rect(ground, rect, false)
	var ratio: Vector2 = rect.size / region_size(region)
	_draw_detail_decorations(region, rect)
	if region == "farm":
		var season_colors := [Color("d5a6b7"), Color("91b87b"), Color("d6a36d"), Color("a9c4d5")]
		var season_index := int(loop.state.daily_pulse.get("season", 0))
		draw_rect(rect.grow(-1), season_colors[clampi(season_index, 0, season_colors.size() - 1)], false, 2.0)
		for key in loop.state.farm.plots:
			var index := int(key)
			var plot: Dictionary = loop.state.farm.plots[key]
			var cell := FarmTerrain.tile_center(index) - Vector2(16, 16)
			var soil_color := Color("68503b") if plot.watered else Color("8e6240")
			if plot.get("fertilized", false): soil_color = soil_color.lightened(0.16)
			draw_rect(Rect2(rect.position + cell * ratio, Vector2(30, 30) * ratio), soil_color)
			if plot.growth >= 0:
				draw_rect(Rect2(project(cell + Vector2(10, 9), region, rect), Vector2(12, 14) * ratio), Color("dab9cb") if plot.growth >= 3 else Color("89a66c"))
	for item in region_items(region):
		var kind: String = item.kind
		if region == "farm" and item.has("resource_id") and (loop.state.resource_left(item.resource_id) <= 0 or item.tiles.any(func(index): return loop.state.farm.plots.has(str(int(index))))): continue
		if item.has("resource_id") and item.resource_type in ["wood", "ore"] and loop.state.resource_left(item.resource_id) <= 0:
			kind = "harvest_stump" if item.resource_type == "wood" else "harvest_rubble"
		var sprite := Furniture.House.exterior_texture(loop.state.furniture) if region == "farm" and item.get("role", "") == "witch_home" else texture_for(kind)
		var source_size := Vector2(sprite.get_size())
		var position := rect.position + (Vector2(item.x, item.y) - Vector2(source_size.x / 2.0, source_size.y)) * ratio
		var sprite_rect := Rect2(position.round(), (source_size * ratio).ceil())
		var clipped := sprite_rect.intersection(rect)
		if clipped.has_area():
			var source_rect := Rect2((clipped.position - sprite_rect.position) / sprite_rect.size * source_size, clipped.size / sprite_rect.size * source_size)
			draw_texture_rect_region(sprite, clipped, source_rect)
	if region == "field":
		for index in range(9):
			var point := Vector2(105 + (index % 3) * 135, 115 + (index / 3) * 66)
			draw_rect(Rect2(project(point, region, rect) - Vector2(2, 2), Vector2(4, 4)), Color("a8bd80") if loop.state.nodes[index] > 0 else Color("756d56"))
	_draw_map_frame(rect)

func _caption(text: String, position: Vector2, color: Color = Color("f4e5bf")) -> void:
	var caption := tr(text)
	var width := UIFont.get_font().get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var left := clampf(position.x - width / 2.0, 3, maxf(3, size.x - width - 3))
	var top := clampf(position.y - 15, 1, size.y - 18)
	draw_rect(Rect2(left - 2, top, width + 4, 17), Color("453a2ae8"))
	draw_string(UIFont.get_font(), Vector2(left, top + 13), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _pin(marker: Dictionary, region: String, rect: Rect2, show_label: bool = true) -> void:
	var point := project(marker.point, region, rect)
	var color := Color("a8bd80") if marker.get("type", "") == "field" else Color("f2c476")
	draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), Color("49352b"))
	draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), color)
	markers.append({"position": point, "label": marker.label, "target": marker.target})
	if show_label: _caption(marker.label, point + Vector2(0, -7))

func _draw() -> void:
	markers.clear()
	hit_regions.clear()
	player_point = Vector2.INF
	draw_rect(Rect2(Vector2.ZERO, size), Color("a6a27a"))
	for x in range(8, int(size.x), 16):
		for y in range(8, int(size.y), 16): draw_rect(Rect2(x, y, 1, 1), Color("bab18b"))
	if view == "world":
		var town_rect: Rect2 = WORLD_RECTS.town
		for key in ["farm", "field", "dock"]:
			var gate: Array = layouts.town.gates[key]
			var destination: Array = layouts[key].get("exit", [24, 280])
			_draw_route(project(Vector2(gate[0], gate[1]), "town", town_rect), project(Vector2(destination[0], destination[1]), key, WORLD_RECTS[key]), 5.0)
		for region in WORLD_RECTS:
			var rect: Rect2 = WORLD_RECTS[region]
			_draw_region(region, rect)
			hit_regions.append({"rect": rect, "target": region})
			_caption(PLACES[region] if region != "dock" else "码头", Vector2(rect.get_center().x, rect.position.y + 16))
		_draw_world_decorations()
		for marker in region_markers("town"):
			if marker.target in ["restaurant", "store", "blacksmith", "furniture_store"] or marker.get("type", "") == "property": _pin(marker, "town", town_rect, false)
		_pin({"point": Vector2(layouts.farm.home[0], layouts.farm.home[1]), "label": PLACES.home, "target": "home"}, "farm", WORLD_RECTS.farm, false)
		var region := outdoor_region()
		player_point = project(player_anchor(region), region, WORLD_RECTS[region])
	else:
		map_rect = detail_rect(view)
		_draw_region(view, map_rect)
		for marker in region_markers(view): _pin(marker, view, map_rect)
		var anchor := player_anchor(view)
		if anchor.is_finite(): player_point = project(anchor, view, map_rect)
	if player_point.is_finite():
		var radius := 5.0 + floorf((sin(elapsed * 4.0) + 1.0) * 1.5)
		draw_circle(player_point, radius + 1, Color("f6e9c8"))
		draw_circle(player_point, 4, Color("3e8194"))
		draw_rect(Rect2(player_point - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
	if not hovered.is_empty(): _caption(hovered, get_local_mouse_position() + Vector2(0, -12))

func target_at(point: Vector2) -> Dictionary:
	for marker in markers:
		if point.distance_to(marker.position) <= 9.0: return marker
	for entry in hit_regions:
		if entry.rect.has_point(point): return {"target": entry.target, "label": PLACES[entry.target]}
	return {}

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := target_at(event.position)
		hovered = hit.get("label", "")
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hit.get("target", "").is_empty() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit := target_at(event.position)
		if not hit.get("target", "").is_empty(): region_selected.emit(hit.target)
		accept_event()
