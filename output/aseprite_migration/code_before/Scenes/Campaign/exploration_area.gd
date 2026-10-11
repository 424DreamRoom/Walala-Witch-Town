extends Node2D
## TileMapLayer, real collision, daily resources and the existing tool/fishing actions.
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const ResourceNode = preload("res://Scenes/Gameplay/resource_node.gd")
const FoodIcons = preload("res://Scenes/UI/food_icons.gd")
var loop
var kind := "field"
var spawn := Vector2(60, 280)
var exit_direction := Vector2.LEFT
var region_id := "grove"
var stations := {"exit": Vector2(24,280)}
var solids: Array[Rect2] = []
var points: Array[Vector2] = []
var resource_nodes: Array = []
var tiles: TileMapLayer
var marker: Label
var icon_textures := {}
var gather_sprites: Array[Sprite2D] = []
var labels: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Campaign/maps/" + region_id + ".json"))
	tiles = TileMapLayer.new()
	tiles.tile_set = load("res://Art/Campaign/tiles/terrain.tres")
	tiles.z_index = -3
	add_child(tiles)
	for y in range(layout.tiles.size()):
		for x in range(layout.tiles[y].size()):
			var id: int = layout.tiles[y][x]
			tiles.set_cell(Vector2i(x,y),0,Vector2i(id%8,id/8))
	for rect in [Rect2(0,48,640,8),Rect2(0,48,8,260),Rect2(632,48,8,260),Rect2(0,352,640,8),Rect2(432,96,160,112)]:
		add_solid(rect)
	for p in layout.gather_points: points.append(Vector2(p[0],p[1]))
	var region := C.entry(C.D.regions, region_id)
	for id in region.items: icon_textures[id] = FoodIcons.from_path("res://Art/Campaign/icons/"+id+".png")
	for i in range(points.size()):
		var sprite := Sprite2D.new()
		sprite.name = "Gather_"+str(i)
		sprite.texture = icon_textures[region.items[i%region.items.size()]]
		var native_height: float = sprite.texture.get_height()
		sprite.scale = Vector2.ONE * maxf(1.0, floorf(32.0 / native_height))
		preload("res://Scenes/Gameplay/world_depth.gd").feet_sprite(sprite,points[i]+Vector2(0,4),native_height)
		add_child(sprite)
		gather_sprites.append(sprite)
	for i in range(2):
		var node := ResourceNode.new()
		var kind_name: String = region.resource
		node.configure({"resource_id":region_id+":"+str(i),"resource_type":kind_name,"x":190+i*140,"y":278,"w":24,"h":12,"kind":"outdoor_pine" if kind_name=="wood" else "outdoor_ore"},loop)
		add_child(node)
		resource_nodes.append(node)
		solids.append(node.footprint)
	var fish := ResourceNode.new()
	fish.configure({"resource_id":region_id+":fish","resource_type":"fish","x":500,"y":210,"w":16,"h":6,"kind":"dock_fishing_post","anchor":[500,232],"water":[500,170]},loop)
	add_child(fish)
	resource_nodes.append(fish)
	# Native props frame the walkable field without blocking gathering routes.
	for x in [28,76,590,620]:
		var tree := Sprite2D.new()
		tree.texture = load("res://Art/Environment/Hearthwood/outdoor_pine.png")
		preload("res://Scenes/Gameplay/world_depth.gd").feet_sprite(tree,Vector2(x,142),112)
		add_child(tree)
	labels = Node2D.new()
	labels.name = "ExplorationLabels"
	labels.z_index = preload("res://Scenes/Gameplay/world_depth.gd").LABEL
	labels.draw.connect(_draw_labels)
	add_child(labels)
	marker = Label.new()
	marker.position = Vector2(12,58)
	marker.text = region.name
	preload("res://Scenes/Gameplay/ui_font.gd").apply_control(marker)
	labels.add_child(marker)

func add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	add_child(body)
	loop.lane._collision(body,rect.size,Vector2.ZERO)
	solids.append(rect)

func nearest_interaction() -> Dictionary:
	var best := 27.01
	var result := {}
	for i in range(points.size()):
		var distance: float = loop.lane.player.position.distance_to(points[i])
		if distance < best:
			best = distance
			result = {"type":"campaign", "index":i}
	for node in resource_nodes:
		var distance: float = loop.lane.player.position.distance_to(node.anchor)
		if distance < best:
			best = distance
			result = {"type":"resource", "node":node}
	return result

func _process(_delta: float) -> void:
	for i in range(gather_sprites.size()):
		gather_sprites[i].visible = loop.state.campaign.gathered.get(region_id+":"+str(i),0)<2
	labels.queue_redraw()

func _draw_labels() -> void:
	var region := C.entry(C.D.regions,region_id)
	var selected := nearest_interaction()
	if selected.get("type", "") == "campaign":
		var id: String = region.items[selected.index%region.items.size()]
		labels.draw_string(loop.font,points[selected.index]+Vector2(-16,-34),tr(C.D.items[id].name),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff0d5"))
	elif selected.get("type", "") == "resource":
		labels.draw_string(loop.font,selected.node.anchor+Vector2(-16,-58),loop.harvest.prompt() if loop.harvest.busy() else tr("鱼群" if selected.node.resource_kind=="fish" else "木材" if selected.node.resource_kind=="wood" else "矿石"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff0d5"))
