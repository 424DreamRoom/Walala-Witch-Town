extends Node2D
## TileMapLayer, real collision, daily resources and the existing tool/fishing actions.
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const ResourceNode = preload("res://Scenes/Gameplay/resource_node.gd")
const FoodIcons = preload("res://Scenes/UI/food_icons.gd")
const Layout = preload("res://Scenes/Campaign/region_layout.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
var layout: Dictionary
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
	layout = Layout.get_region(region_id)
	spawn = Vector2(layout.spawn[0], layout.spawn[1])
	stations.exit = Vector2(layout.exit[0], layout.exit[1])
	tiles = Layout.ground(region_id)
	tiles.z_index = Depth.GROUND
	add_child(tiles)
	for rect in [Rect2(0,48,640,8),Rect2(0,48,8,312),Rect2(632,48,8,312),Rect2(0,352,640,8)]:
		add_solid(rect)
	for rect in layout.solids: add_solid(Rect2(rect[0], rect[1], rect[2], rect[3]))
	for p in layout.gather_points: points.append(Vector2(p[0],p[1]))
	var region := C.entry(C.D.regions, region_id)
	for id in region.items: icon_textures[id] = FoodIcons.from_path("res://Art/Campaign/icons/"+id+".aseprite")
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
		var at: Array = layout.resources[i]
		node.configure({"resource_id":region_id+":"+str(i),"resource_type":kind_name,"x":at[0],"y":at[1],"w":24,"h":12,"kind":"outdoor_pine" if kind_name=="wood" else "outdoor_ore"},loop)
		add_child(node)
		resource_nodes.append(node)
		solids.append(node.footprint)
	var fish := ResourceNode.new()
	fish.configure({"resource_id":region_id+":fish","resource_type":"fish","x":layout.fishing.position[0],"y":layout.fishing.position[1],"w":16,"h":6,"kind":"dock_fishing_post","anchor":layout.fishing.anchor,"water":layout.fishing.water},loop)
	add_child(fish)
	resource_nodes.append(fish)
	for prop in layout.props:
		var body: Node2D = StaticBody2D.new() if prop.solid else Node2D.new()
		body.position = Vector2(prop.x, prop.y)
		add_child(body)
		var sprite := Sprite2D.new()
		sprite.texture = load(ResourceNode.ART + prop.kind + ".aseprite")
		Depth.feet_sprite(sprite, Vector2.ZERO, sprite.texture.get_height())
		body.add_child(sprite)
		preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, prop.kind, loop.lane.weather)
		if prop.solid:
			loop.lane._collision(body, Vector2(prop.w, prop.h), Vector2(0, -prop.h / 2.0))
			solids.append(Rect2(prop.x - prop.w / 2.0, prop.y - prop.h, prop.w, prop.h))
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

func safe_position(point: Vector2) -> Vector2:
	# Old saves can occupy a newly restored river bank. Search locally, then use
	# the protected entrance. Never relocate an already valid saved position.
	if _clear(point): return point
	for radius in range(8, 97, 8):
		for offset in [Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
			if _clear(point + offset): return point + offset
	return spawn

func _clear(point: Vector2) -> bool:
	if not point.is_finite() or not Rect2(8,56,624,296).has_point(point): return false
	var feet := Rect2(point - Vector2(5,6),Vector2(10,6))
	return not solids.any(func(rect): return rect.intersects(feet))

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
