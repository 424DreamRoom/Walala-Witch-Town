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
var soil_tiles: TileMapLayer
var soil_state: Dictionary = {}
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
	var ground := preload("res://Art/Source/tile_ground.gd").create(ART + "farm_ground.aseprite")
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
	var piano := StaticBody2D.new()
	piano.name = "StarterPiano"
	piano.position = Furniture.STARTER_PIANO
	add_child(piano)
	var piano_picture := Sprite2D.new()
	piano_picture.texture = Furniture.texture("piano")
	piano_picture.position.y = -piano_picture.texture.get_height() / 2.0
	piano.add_child(piano_picture)
	var piano_dimensions: Vector2 = Furniture.RECIPES.piano.size
	loop.lane._collision(piano, piano_dimensions, Vector2(0, -piano_dimensions.y / 2.0))
	solids.append(Furniture.footprint("piano", Furniture.STARTER_PIANO))
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
	soil_tiles = TileMapLayer.new()
	soil_tiles.name = "CultivatedTiles"
	soil_tiles.position = FIELD.position
	soil_tiles.z_index = -1
	soil_tiles.tile_set = TileSet.new()
	soil_tiles.tile_set.tile_size = Vector2i(32, 32)
	var soil_atlas := TileSetAtlasSource.new()
	soil_atlas.texture = preload("res://Art/Source/aseprite_source.gd").texture(ART + "Tiles/farm_soil.aseprite")
	soil_atlas.texture_region_size = Vector2i(32, 32)
	soil_atlas.create_tile(Vector2i.ZERO)
	soil_atlas.create_tile(Vector2i(1, 0))
	soil_tiles.tile_set.add_source(soil_atlas, 0)
	add_child(soil_tiles)
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
	var home: bool = item.get("role", "") == "witch_home"
	sprite.texture = Furniture.House.exterior_texture(loop.state.furniture) if home else load(ART + item.kind + ".aseprite")
	if home: object.name = "WitchHomeExterior"
	sprite.position.y = -sprite.texture.get_height() / 2.0
	object.add_child(sprite)
	preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, item.kind, loop.lane.weather)
	if solid:
		var size := Furniture.House.outdoor_footprint(loop.state.furniture).size if home else Vector2(item.w, item.h)
		loop.lane._collision(object, size, Vector2(0, -size.y / 2.0))
		solids.append(Rect2(object.position - Vector2(size.x / 2.0, size.y), size))
	if home:
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

func nearest_instrument() -> Dictionary:
	var result := Placed.nearest_instrument(self, "farm")
	var player: Vector2 = loop.lane.player.position
	var rect := Furniture.footprint("piano", Furniture.STARTER_PIANO)
	var distance := player.distance_to(player.clamp(rect.position, rect.end))
	var result_distance := INF
	if not result.is_empty():
		var result_rect := Furniture.footprint(result.kind, Furniture.position_of(result))
		result_distance = player.distance_to(player.clamp(result_rect.position, result_rect.end))
	if distance < 27.0 and (result.is_empty() or distance < result_distance):
		result = {"kind": "piano", "area": "farm", "id": 0, "fixed": true}
	return result

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
	if not nearest_instrument().is_empty():
		loop.hud.open_instrument("piano")
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
	elif not nearest_instrument().is_empty():
		text = "钢琴"
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
	for key in soil_state.keys():
		if not loop.state.farm.plots.has(key):
			soil_tiles.erase_cell(Terrain.cells[int(key)])
			soil_state.erase(key)
	for key in loop.state.farm.plots:
		var wet: bool = loop.state.farm.plots[key].watered
		if soil_state.get(key) != wet:
			soil_tiles.set_cell(Terrain.cells[int(key)], 0, Vector2i(1 if wet else 0, 0))
			soil_state[key] = wet
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
	var crop_tint := Color("fff0c4") if plot.get("fertilized", false) else Color("eef7ff") if plot.get("watered", false) else Color.WHITE
	if plot.get("crop", "herb") != "herb":
		var crop: Dictionary = s.Campaign.entry(s.Content.DATA.crops, plot.crop)
		if not crop_textures.has(plot.crop): crop_textures[plot.crop] = load("res://Art/Campaign/crops/"+plot.crop+".aseprite")
		var texture: Texture2D = crop_textures[plot.crop]
		var stage: int = mini(3, floori(3.0*plot.growth/crop.days))
		painter.draw_texture_rect_region(texture,Rect2(Vector2(-16,-31),Vector2(32,32)),Rect2(stage*32,0,32,32),crop_tint)
		return
	if not crop_textures.has("herb"):
		crop_textures.herb = load(ART + "Tiles/herb_lifecycle.aseprite")
	painter.draw_texture_rect_region(crop_textures.herb, Rect2(-16, -31, 32, 32), Rect2(clampi(int(plot.growth), 0, 3) * 32, 0, 32, 32), crop_tint)

func _draw_plots() -> void:
	var s = loop.state
	if selected >= 0 and s.is_item_selected("wand") and s.wand_mode == "blue":
		terrain.draw_rect(Rect2(tile_center(selected) - Vector2(15, 15), Vector2(30, 30)), Color("73baff"), false, 1)
	if sparkle_left > 0.0:
		for offset in [Vector2(-8, -9), Vector2(8, -6), Vector2(0, -16)]:
			terrain.draw_rect(Rect2(sparkle_position + offset - Vector2(0, (0.35 - sparkle_left) * 14), Vector2(2, 2)), Color("a7d8ff"))
