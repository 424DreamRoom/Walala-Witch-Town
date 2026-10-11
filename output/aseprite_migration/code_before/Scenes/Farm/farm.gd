extends Node2D
## Outdoor farm shares movement, weather and saved state with the town.
const ART := "res://Art/Environment/Hearthwood/"
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const Furniture = preload("res://Scenes/Building/furniture_catalog.gd")
const Placed = preload("res://Scenes/Building/placed_construction.gd")
const Terrain = preload("res://Scenes/Farm/farm_terrain.gd")
const ResourceNode = preload("res://Scenes/Gameplay/resource_node.gd")
const FIELD := Terrain.FIELD
const TILE := 32
const COLUMNS := Terrain.COLUMNS
var loop
var solids: Array[Rect2] = []
var roof_rects: Array[Rect2] = []
var stations := {"exit": Vector2(1432, 364), "home": Vector2(270, 276), "refill": Vector2(366, 276)}
var spawn := Vector2(1398, 364)
var world_size := Terrain.WORLD_SIZE
var resource_nodes: Array[ResourceNode] = []
var furniture_bodies: Array[StaticBody2D] = []
var fixed_solids: Array[Rect2] = []
var terrain: Node2D
var prompt: Label
var selected := -1
var action_left := 0.0
var sparkle_position := Vector2.ZERO
var sparkle_left := 0.0
var crop_textures := {}
var crop_nodes := {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "farm_layout.json"))
	spawn = Vector2(layout.spawn[0], layout.spawn[1])
	stations.exit = Vector2(layout.exit[0], layout.exit[1])
	stations.refill = Vector2(layout.refill[0], layout.refill[1])
	var ground := Sprite2D.new()
	ground.texture = load(ART + "farm_ground.png")
	ground.centered = false
	ground.z_index = -2
	add_child(ground)
	for item in layout.buildings:
		_add_object(item)
	for values in layout.water:
		_add_solid(Rect2(values[0], values[1], values[2], values[3]))
	for rect in [Rect2(-16, -16, world_size.x + 32, 32), Rect2(-16, world_size.y - 16, world_size.x + 32, 32), Rect2(-16, 0, 32, world_size.y), Rect2(world_size.x, 0, 16, world_size.y)]:
		_add_solid(rect)
	var bench := StaticBody2D.new()
	bench.name = "StarterWorkbench"
	bench.position = Furniture.STARTER_BENCH
	add_child(bench)
	var picture := Sprite2D.new()
	picture.texture = Furniture.texture("workbench")
	picture.position.y = -picture.texture.get_height() / 2.0
	bench.add_child(picture)
	var dimensions: Vector2 = Furniture.RECIPES.workbench.size
	loop.lane._collision(bench, dimensions, Vector2(0, -dimensions.y / 2.0))
	solids.append(Furniture.footprint("workbench", Furniture.STARTER_BENCH))
	fixed_solids = solids.duplicate()
	for item in layout.props:
		# Existing farmland takes precedence over newly generated vegetation.
		if item.tiles.any(func(index): return loop.state.farm.plots.has(str(int(index)))):
			loop.state.resource_damage[item.resource_id] = loop.state.RESOURCE_HITS
		var resource := ResourceNode.new()
		resource.configure(item, loop)
		add_child(resource)
		resource_nodes.append(resource)
	refresh_resources()
	terrain = Node2D.new()
	terrain.name = "FarmPlots"
	terrain.z_index = -1
	terrain.draw.connect(_draw_plots)
	add_child(terrain)
	var hints := Node2D.new()
	hints.z_index = 10
	add_child(hints)
	prompt = Label.new()
	UIFont.apply_control(prompt)
	prompt.add_theme_color_override("font_color", Color("fff0c2"))
	prompt.add_theme_color_override("font_shadow_color", Color("30251f"))
	prompt.add_theme_constant_override("shadow_offset_x", 1)
	prompt.add_theme_constant_override("shadow_offset_y", 1)
	hints.add_child(prompt)

func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	add_child(body)
	loop.lane._collision(body, rect.size, Vector2.ZERO)
	solids.append(rect)

func _add_object(item: Dictionary) -> void:
	var solid: bool = item.get("solid", true)
	var object: Node2D = StaticBody2D.new() if solid else Node2D.new()
	object.position = Vector2(item.x, item.y)
	add_child(object)
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + item.kind + ".png")
	sprite.position.y = -sprite.texture.get_height() / 2.0
	object.add_child(sprite)
	preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, item.kind, loop.lane.weather)
	if solid:
		var size := Vector2(item.w, item.h)
		loop.lane._collision(object, size, Vector2(0, -size.y / 2.0))
		solids.append(Rect2(object.position - Vector2(size.x / 2.0, size.y), size))
	if item.get("role", "") == "witch_home":
		roof_rects.append(Rect2(Vector2(item.x - sprite.texture.get_width() / 2.0, item.y - sprite.texture.get_height()), sprite.texture.get_size()))

func tile_center(index: int) -> Vector2:
	return Terrain.tile_center(index)

func refresh_resources() -> void:
	solids = fixed_solids.duplicate()
	for resource in resource_nodes:
		if resource.available(): solids.append(resource.footprint)
	Placed.rebuild(self, "farm")
	loop.lane.solid_rects = solids.duplicate()

func refresh_furniture() -> void:
	refresh_resources()

func nearest_chest() -> Dictionary:
	return Placed.nearest_chest(self, "farm")

func nearest_resource() -> ResourceNode:
	var best := 27.01
	var result: ResourceNode
	for resource in resource_nodes:
		if not resource.available(): continue
		var distance: float = loop.lane.player.position.distance_to(resource.anchor)
		if distance < best:
			best = distance
			result = resource
	return result

func selected_tile() -> int:
	# Aim one tile ahead, with a short reach; never act on a distant tile.
	var facing: Vector2 = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT][loop.lane.facing]
	var aim: Vector2 = loop.lane.player.position + facing * 24.0
	if not FIELD.has_point(aim):
		return -1
	var index := Terrain.index_at(aim)
	return index if index >= 0 and Terrain.can_till(loop.state, index) and loop.lane.player.position.distance_to(tile_center(index)) <= 46.0 else -1

func interact() -> void:
	if loop.near(stations.refill):
		if loop.state.refill_farm_water():
			loop.audio.play_event("cast")
			loop.harvest.show_farm_cast()
		loop._show_feedback()
		return
	if Placed.bench_preferred(self, "farm"):
		loop.builder.open_catalog()
		return
	var chest := nearest_chest()
	if not chest.is_empty():
		loop.hud.open_chest(chest.id)
		return
	if action_left > 0.0:
		return
	var resource := nearest_resource()
	if resource != null:
		loop.harvest.start(resource)
		return
	var index := selected_tile()
	if index < 0:
		return
	if loop.state.work_farm_tile(index):
		loop.audio.play_event("gather")
		if loop.state.is_item_selected("wand"): loop.harvest.show_farm_cast()
		sparkle_position = tile_center(index)
		sparkle_left = 0.35
	action_left = 0.25
	loop._show_feedback()

func _process(delta: float) -> void:
	action_left = maxf(0.0, action_left - delta)
	sparkle_left = maxf(0.0, sparkle_left - delta)
	selected = selected_tile()
	var s = loop.state
	var text := ""
	if loop.near(stations.home):
		text = "小女巫的家"
	elif loop.near(stations.exit):
		text = "哗啦啦魔女镇 →"
	elif loop.near(stations.refill):
		text = "房屋水源"
	elif Placed.bench_preferred(self, "farm"):
		text = "建造工作台"
	elif not nearest_chest().is_empty():
		text = "木箱"
	elif nearest_resource() != null:
		text = loop.harvest.prompt() if loop.harvest.busy() else {"wood": "树木", "ore": "石块", "weed": "杂草"}[nearest_resource().resource_kind]
	elif selected >= 0:
		text = s.farm_tile_prompt(selected)
	prompt.text = tr(text)
	prompt.visible = not text.is_empty() and s.phase != "result"
	var pos: Vector2 = loop.lane.player.position
	prompt.position = (pos + Vector2(-prompt.get_theme_font("font").get_string_size(prompt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x / 2.0, -68)).round()
	terrain.queue_redraw()
	_sync_crops()

func _sync_crops() -> void:
	for key in crop_nodes.keys():
		if not loop.state.farm.plots.has(key) or loop.state.farm.plots[key].growth < 0:
			crop_nodes[key].queue_free()
			crop_nodes.erase(key)
	for key in loop.state.farm.plots:
		if loop.state.farm.plots[key].growth < 0: continue
		if not crop_nodes.has(key):
			var crop := Node2D.new()
			crop.name = "Crop_"+key
			crop.position = tile_center(int(key))+Vector2(0,7)
			crop.draw.connect(_draw_crop.bind(crop,key))
			add_child(crop)
			crop_nodes[key] = crop
		crop_nodes[key].queue_redraw()

func _draw_crop(painter: Node2D, key: String) -> void:
	var s = loop.state
	if not s.farm.plots.has(key): return
	var plot: Dictionary = s.farm.plots[key]
	if plot.growth < 0: return
	if plot.get("crop", "herb") != "herb":
		var crop: Dictionary = s.Campaign.entry(s.Content.DATA.crops, plot.crop)
		if not crop_textures.has(plot.crop): crop_textures[plot.crop] = load("res://Art/Campaign/crops/"+plot.crop+".png")
		var texture: Texture2D = crop_textures[plot.crop]
		var stage: int = mini(3, floori(3.0*plot.growth/crop.days))
		painter.draw_texture_rect_region(texture,Rect2(Vector2(-16,-31),Vector2(32,32)),Rect2(stage*32,0,32,32))
		return
	var height: int = 4 + int(plot.growth) * 4
	painter.draw_line(Vector2.ZERO,Vector2(0,-height),Color("36533e"),2)
	for side in [-1,1]:
		painter.draw_rect(Rect2(Vector2(side*5-3,-height+2),Vector2(6,3)),Color("9fb36f") if plot.growth>=2 else Color("72985b"))
	if plot.growth>=1:
		painter.draw_rect(Rect2(-7,-7,6,3),Color("557c4c"))
		painter.draw_rect(Rect2(2,-10,6,3),Color("8da760"))
	if plot.growth==s.FARM_GROWTH_DAYS:
		for offset in [Vector2(-4,-17),Vector2(2,-20),Vector2(5,-15)]:
			painter.draw_rect(Rect2(offset,Vector2(3,4)),Color("dab9cb"))

func _draw_plots() -> void:
	var s = loop.state
	for key in s.farm.plots:
		var index := int(key)
		var plot: Dictionary = s.farm.plots[key]
		var center := tile_center(index)
		var rect := Rect2(center - Vector2(15, 15), Vector2(30, 30))
		var wet: bool = plot.watered
		terrain.draw_rect(rect, Color("68503b") if wet else Color("8e6240"))
		terrain.draw_rect(rect.grow(-1), Color("775941") if wet else Color("a4764e"))
		for offset in [-9, -2, 5, 12]:
			terrain.draw_line(center + Vector2(-12, offset), center + Vector2(12, offset), Color("594734") if wet else Color("795638"), 1)
	if selected >= 0 and s.is_item_selected("wand"):
		terrain.draw_rect(Rect2(tile_center(selected) - Vector2(15, 15), Vector2(30, 30)), Color("f3dba0"), false, 1)
	if sparkle_left > 0.0:
		for offset in [Vector2(-8, -9), Vector2(8, -6), Vector2(0, -16)]:
			terrain.draw_rect(Rect2(sparkle_position + offset - Vector2(0, (0.35 - sparkle_left) * 14), Vector2(2, 2)), Color("f3dba0"))
