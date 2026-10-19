extends Node2D
## Pixel environments and contextual interaction labels.
var kind = "field"
var spawn := Vector2(60, 280)
var exit_direction := Vector2.LEFT
var loop
var points: Array[Vector2] = []
var stations = {"exit": Vector2(24, 280), "prep": Vector2(110, 130), "kitchen": Vector2(270, 130)}
var seats: Array[Vector2] = [Vector2(110, 225), Vector2(245, 225), Vector2(375, 225), Vector2(110, 285), Vector2(245, 285), Vector2(375, 285)]
var solids: Array[Rect2] = []
var font: Font
var background: Texture2D
var gather_textures: Array[Texture2D] = []
const ART := "res://Art/Environment/Hearthwood/"
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
const ActorCollision = preload("res://Scenes/Gameplay/actor_collision.gd")
const FoodIcons = preload("res://Scenes/UI/food_icons.gd")
const CUSTOMER_PATHS = ["green_braids", "blue_blonde", "burgundy_curls", "orange_short", "cyan_gray", "pink_longblue"]
# Guests enter from the bottom-left town door; the walk is cosmetic only.
const GUEST_DOOR := Vector2(32, 262)
const GUEST_WALK_SECONDS := 1.6
var customer_sheets: Array[Texture2D] = []
var field_labels: Node2D
var dish_textures := {}
var resource_nodes: Array = []
var gather_sprites: Array[Sprite2D] = []
var customer_sprites: Array[Sprite2D] = []
var customer_walkers: Array[Sprite2D] = []
# Purely visual arrival clock, keyed by seat; customer data keeps its saved shape.
var arrival_clock := {}
var customer_bodies: Array[StaticBody2D] = []
var npc_sheets := {}
var tables: Array[StaticBody2D] = []
var walkable_regions: Array[Rect2] = []
var restaurant_fixed_solids: Array[Rect2] = []
# The whole front edge of each counter is usable, not a single central point.
var prep_rect := Rect2(65, 96, 100, 17)
var kitchen_rect := Rect2(185, 96, 100, 17)
const COUNTER_REACH := 30.0
var table_count := -1
var held_visual: Node2D

func _ready() -> void:
	font = loop.font
	y_sort_enabled = true
	for recipe in loop.state.Content.DATA.recipes:
		dish_textures[recipe.id] = FoodIcons.texture("dish_" + recipe.id)
	background = load(ART + ("restaurant_ground.aseprite" if kind == "restaurant" else "field_background.aseprite"))
	var ground := preload("res://Art/Source/tile_ground.gd").create(ART + ("restaurant_ground.aseprite" if kind == "restaurant" else "field_background.aseprite"), ART + "restaurant_compact_ground.tilemap.tscn" if kind == "restaurant" else "")
	ground.z_index = Depth.GROUND
	add_child(ground)
	for slug in ["mushroom", "berry", "herb", "depleted"]:
		gather_textures.append(load(ART + "gather_" + slug + ".aseprite"))
	for slug in CUSTOMER_PATHS:
		customer_sheets.append(load("res://Art/Characters/NPC32/customers/" + slug + ".aseprite"))
	for y in range(3):
		for x in range(3):
			points.append(Vector2(105 + x * 135, 115 + y * 66))
	if kind == "restaurant":
		spawn = Vector2(60, 248)
		stations.exit = Vector2(24, 248)
		stations.kitchen = Vector2(230, 130)
		seats.assign([Vector2(96, 201), Vector2(208, 201), Vector2(304, 201), Vector2(96, 251), Vector2(208, 251), Vector2(304, 251)])
		walkable_regions.assign([Rect2(8, 72, 328, 198)])
		for rect in [Rect2(0, 64, 344, 8), Rect2(0, 64, 8, 214), Rect2(336, 64, 8, 214), Rect2(0, 270, 344, 8)]:
			add_solid(rect)
		add_solid(Rect2(65, 96, 100, 17))
		add_solid(Rect2(185, 96, 100, 17))
		restaurant_fixed_solids = solids.duplicate()
		for index in range(2):
			var counter := Sprite2D.new()
			counter.name = "PrepCounter" if index==0 else "KitchenCounter"
			counter.texture = load(ART+("restaurant_prep.aseprite" if index==0 else "restaurant_kitchen.aseprite"))
			counter.position = Vector2(115+index*120,113)
			counter.centered = false
			counter.offset = Vector2(-50,-35)
			add_child(counter)
		for npc in loop.state.Content.DATA.npcs:
			npc_sheets[npc.id] = load("res://Art/Characters/NPC32/residents/"+npc.id+".aseprite")
		for i in range(seats.size()):
			var table := StaticBody2D.new()
			table.name = "Table_"+str(i)
			table.position = seats[i]+Vector2(0,-15)
			add_child(table)
			loop.lane._collision(table,Vector2(40,20),Vector2(0,-10))
			var sprite := Sprite2D.new()
			sprite.texture = load(ART+"restaurant_table.aseprite")
			sprite.centered = false
			sprite.offset = Vector2(-24,-20)
			table.add_child(sprite)
			tables.append(table)
			var guest := Sprite2D.new()
			guest.name = "Guest_"+str(i)
			Depth.feet_sprite(guest,seats[i],32)
			add_child(guest)
			customer_sprites.append(guest)
			# A walking copy covers the doorway approach; the seated sprite stays put.
			var walker := Sprite2D.new()
			walker.name = "GuestWalk_"+str(i)
			Depth.feet_sprite(walker,seats[i],32)
			walker.visible = false
			walker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(walker)
			customer_walkers.append(walker)
			var body := StaticBody2D.new()
			body.name = "GuestBody_" + str(i)
			ActorCollision.attach(body)
			ActorCollision.set_active(body, false)
			guest.add_child(body)
			customer_bodies.append(body)
		_sync_tables()
		held_visual = Node2D.new()
		held_visual.name = "HeldDish"
		held_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		held_visual.draw.connect(_draw_held)
		loop.lane.player.add_child(held_visual)
	else:
		y_sort_enabled = true
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "field_layout.json"))
		spawn = Vector2(layout.spawn[0], layout.spawn[1])
		stations.exit = Vector2(layout.exit[0], layout.exit[1])
		exit_direction = Vector2.DOWN
		for rect in [Rect2(0, 64, 440, 8), Rect2(0, 64, 8, 296), Rect2(432, 64, 8, 296), Rect2(0, 360, 440, 8)]:
			add_solid(rect)
		for entry in layout.props:
			if entry.has("resource_id"):
				var resource = preload("res://Scenes/Gameplay/resource_node.gd").new()
				resource.configure(entry, loop)
				add_child(resource)
				resource_nodes.append(resource)
				solids.append(resource.footprint)
				continue
			var solid: bool = entry.get("solid", true)
			var object: Node2D = StaticBody2D.new() if solid else Node2D.new()
			object.set_meta("outdoor_kind", entry.kind)
			object.position = Vector2(entry.x, entry.y)
			add_child(object)
			var sprite := Sprite2D.new()
			sprite.texture = load(ART + entry.kind + ".aseprite")
			sprite.position.y = -sprite.texture.get_height() / 2.0
			object.add_child(sprite)
			preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, entry.kind, loop.lane.weather)
			if solid:
				var size := Vector2(entry.w, entry.h)
				loop.lane._collision(object, size, Vector2(0, -size.y / 2))
				solids.append(Rect2(object.position - Vector2(size.x / 2, size.y), size))
		for i in range(points.size()):
			var sprite := Sprite2D.new()
			sprite.name = "Gather_"+str(i)
			Depth.feet_sprite(sprite,points[i]+Vector2(0,4),32)
			add_child(sprite)
			gather_sprites.append(sprite)
	field_labels = Node2D.new()
	field_labels.name = "RestaurantLabels" if kind=="restaurant" else "GatherLabels"
	field_labels.z_index = Depth.LABEL
	field_labels.draw.connect(_draw_restaurant_labels if kind=="restaurant" else _draw_field_labels)
	add_child(field_labels)

func add_solid(rect: Rect2) -> void:
	var body = StaticBody2D.new()
	body.position = rect.get_center()
	add_child(body)
	loop.lane._collision(body, rect.size, Vector2.ZERO)
	solids.append(rect)

func label_at(pos: Vector2, text: String, color = Color("fff0c2"), painter: Node2D = null) -> void:
	text = tr(text)
	if painter != null:
		painter.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	else:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func interaction_label(pos: Vector2, text: String, painter: Node2D = null) -> void:
	text = tr(text)
	if not loop.near(pos):
		return
	var player_pos: Vector2 = loop.lane.player.position
	var top: float = player_pos.y - loop.lane.CHARACTER_SIZE.y
	var baseline: float = minf(pos.y - 34, top - 4)
	if baseline < loop.backgrounds[0].size.y + 16:
		baseline = maxf(pos.y + 18, player_pos.y + 18)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	label_at(Vector2(pos.x - width / 2.0, baseline).round(), text, Color("fff0c2"), painter)

func _process(delta: float) -> void:
	if kind == "restaurant":
		_sync_tables()
		for i in range(customer_sprites.size()):
			var guest: Sprite2D = customer_sprites[i]
			var walker: Sprite2D = customer_walkers[i]
			var customer = loop.state.customer_at(i)
			var present: bool = customer != null and i < table_count
			# Arrival is cosmetic; the order stays live from the moment it exists.
			if not present:
				arrival_clock.erase(i)
			else:
				arrival_clock[i] = maxf(0.0, float(arrival_clock.get(i, GUEST_WALK_SECONDS)) - delta) if arrival_clock.has(i) else GUEST_WALK_SECONDS
			var walking: bool = present and arrival_clock.get(i, 0.0) > 0.0
			guest.visible = present and not walking
			ActorCollision.set_active(customer_bodies[i], guest.visible)
			walker.visible = walking
			if walking:
				_paint_guest(walker, customer)
				var progress: float = clampf(arrival_clock.get(i, 0.0) / GUEST_WALK_SECONDS, 0.0, 1.0)
				walker.position = GUEST_DOOR.lerp(seats[i] + Vector2(0, 6), 1.0 - progress).round()
				# Visitor sheets have no walk cycle (6 frames); only residents animate in.
				walker.frame = _walk_frame(seats[i] + Vector2(0, 6) - GUEST_DOOR) if customer.has("npc") else 0
			if present and not walking:
				_paint_guest(guest, customer)
				# Residents author eating at 18-21; town customers at 2-5.
				var eat_base: int = 18 if customer.has("npc") else 2
				guest.frame = eat_base + int(floor((3.0 - customer.eating_left) * 2.0)) % 4 if customer.get("status", "waiting") == "eating" else _idle_frame(customer)
		held_visual.visible = loop.state.held>=0
		held_visual.queue_redraw()
	else:
		for i in range(gather_sprites.size()): gather_sprites[i].texture = gather_textures[i%3 if loop.state.nodes[i]>0 else 3]
	if field_labels != null:
		field_labels.queue_redraw()

func _paint_guest(sprite: Sprite2D, customer: Dictionary) -> void:
	sprite.texture = npc_sheets[loop.state.Content.DATA.npcs[customer.npc].id] if customer.has("npc") else customer_sheets[int(customer.get("variant",0))%customer_sheets.size()]
	sprite.hframes = 22 if customer.has("npc") else 6

func _walk_frame(direction: Vector2) -> int:
	var row: int = (2 if direction.x > 0.0 else 3) if absf(direction.x) > absf(direction.y) else (0 if direction.y > 0.0 else 1)
	return row * 4 + int(Time.get_ticks_msec() / 130.0) % 4

func _idle_frame(customer: Dictionary) -> int:
	# Residents keep their two-frame front idle at 16-17; visitors stand on frame 0.
	return 16 + int(Time.get_ticks_msec() / 650.0) % 2 if customer.has("npc") else 0

func _draw_field_labels() -> void:
	var selected := nearest_interaction()
	if not selected.is_empty():
		if selected.type == "gather":
			var i: int = selected.index
			interaction_label(points[i], tr(loop.state.INGREDIENTS[i % 3]) + " " + str(loop.state.nodes[i]), field_labels)
		else:
			var node = selected.node
			var title: String = tr({"wood": "树木", "ore": "矿石", "fish": "鱼群"}[node.resource_kind])
			if not node.available():
				title = tr("次日刷新")
			elif loop.harvest.busy():
				title = loop.harvest.prompt()
			if loop.harvest.action == "bite":
				title = tr(title)
				var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				label_at((loop.lane.player.position + Vector2(-width / 2.0, -70)).round(), title, Color("fff0c2"), field_labels)
			else:
				interaction_label(node.anchor, title, field_labels)
	interaction_label(stations.exit, "小镇", field_labels)

func nearest_interaction() -> Dictionary:
	var best := 27.01
	var selected := {}
	for i in range(points.size()):
		var distance: float = loop.lane.player.position.distance_to(points[i])
		if distance < best:
			best = distance
			selected = {"type": "gather", "index": i}
	for node in resource_nodes:
		var distance: float = loop.lane.player.position.distance_to(node.anchor)
		if distance < best:
			best = distance
			selected = {"type": "resource", "node": node}
	return selected

func at_counter(which: String) -> bool:
	if kind != "restaurant": return false
	var rect: Rect2 = prep_rect if which == "prep" else kitchen_rect
	var point: Vector2 = loop.lane.player.position
	# Standing in front of the counter, anywhere along it; reach runs from the front edge.
	if point.y < rect.end.y: return false
	var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), rect.end.y)
	return point.distance_to(nearest) <= COUNTER_REACH

func _sync_tables() -> void:
	var count: int = loop.state.Campaign.restaurant(loop.state).seats
	if table_count==count: return
	table_count = count
	solids = restaurant_fixed_solids.duplicate()
	for i in range(tables.size()):
		tables[i].visible = i<count
		tables[i].collision_layer = 1 if i<count else 0
		if i<count: solids.append(Rect2(seats[i]+Vector2(-20,-35),Vector2(40,20)))
	if loop.location=="restaurant": loop.lane.solid_rects = solids.duplicate()

func _draw_restaurant_labels() -> void:
	interaction_label(stations.prep,"备料台",field_labels)
	interaction_label(stations.exit,"小镇",field_labels)
	for i in range(table_count):
		var customer = loop.state.customer_at(i)
		if customer==null or customer.get("status","waiting")!="waiting": continue
		var p: Vector2 = seats[i]
		var dish := tr(loop.state.DISHES[customer.dish])
		var width := font.get_string_size(dish,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		# Keep the order readable against the floor instead of raw text over wood.
		var box := Rect2(p+Vector2(-width/2.0,-12),Vector2(width,13)).grow_individual(3,1,3,1)
		field_labels.draw_rect(box,Color(0.16,0.12,0.16,0.55))
		label_at(p+Vector2(-width/2.0,-11),dish,Color("fff0c2"),field_labels)
		var cap: float = loop.state.Campaign.restaurant(loop.state).patience + loop.state.Campaign.comfort(loop.state)
		var ratio: float = clampf(customer.patience / maxf(1.0, cap), 0.0, 1.0)
		field_labels.draw_rect(Rect2(p+Vector2(-24,13),Vector2(48,3)),Color("513744"))
		field_labels.draw_rect(Rect2(p+Vector2(-24,13),Vector2(48*ratio,3)),Color("b5dc89") if ratio > 0.35 else Color("d98a72"))

func _draw_held() -> void:
	if loop.state.held<0: return
	var plate := Vector2(26,-28)
	held_visual.draw_circle(plate,12,Color("fff0d2"))
	var recipe: Dictionary = loop.state.Content.DATA.recipes[loop.state.held]
	var food: Texture2D = dish_textures[recipe.id]
	var pixel_scale := maxf(1.0, floorf(32.0 / maxf(food.get_width(), food.get_height())))
	var dimensions := food.get_size() * pixel_scale
	held_visual.draw_texture_rect(food, Rect2(plate - (dimensions / 2.0).floor(), dimensions), false)

func _exit_tree() -> void:
	if is_instance_valid(held_visual): held_visual.queue_free()
