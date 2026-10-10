extends Node2D
## Pixel environments and contextual interaction labels.
var kind = "field"
var loop
var points: Array[Vector2] = []
var stations = {"exit": Vector2(60, 280), "prep": Vector2(110, 130), "kitchen": Vector2(270, 130)}
var seats: Array[Vector2] = [Vector2(110, 225), Vector2(245, 225), Vector2(375, 225)]
var solids: Array[Rect2] = []
var font: Font
var background: Texture2D
var gather_textures: Array[Texture2D] = []
const ART := "res://Art/Environment/Hearthwood/"
const CUSTOMER_PATHS = ["green_braids", "blue_blonde", "burgundy_curls", "orange_short", "cyan_gray", "pink_longblue"]
var customer_sheets: Array[Texture2D] = []
var field_labels: Node2D
var resource_nodes: Array = []

func _ready() -> void:
	font = loop.font
	background = load(ART + kind + "_background.png")
	for slug in ["mushroom", "berry", "herb", "depleted"]:
		gather_textures.append(load(ART + "gather_" + slug + ".png"))
	for slug in CUSTOMER_PATHS:
		var image = Image.new()
		if image.load(ProjectSettings.globalize_path("res://Art/Character/Storybook/WitchCustomers/" + slug + "/" + slug + ".png")) == OK:
			customer_sheets.append(ImageTexture.create_from_image(image))
	for y in range(3):
		for x in range(3):
			points.append(Vector2(105 + x * 135, 115 + y * 66))
	for rect in [Rect2(0, 64, 440, 8), Rect2(0, 64, 8, 246), Rect2(432, 64, 8, 246), Rect2(0, 302, 440, 8)]:
		add_solid(rect)
	if kind == "restaurant":
		add_solid(Rect2(65, 96, 100, 17))
		add_solid(Rect2(225, 96, 100, 17))
		for seat in seats:
			add_solid(Rect2(seat + Vector2(-20, -35), Vector2(40, 20)))
	else:
		y_sort_enabled = true
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "field_layout.json"))
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
			sprite.texture = load(ART + entry.kind + ".png")
			sprite.position.y = -sprite.texture.get_height() / 2.0
			object.add_child(sprite)
			preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, entry.kind, loop.lane.weather)
			if solid:
				var size := Vector2(entry.w, entry.h)
				loop.lane._collision(object, size, Vector2(0, -size.y / 2))
				solids.append(Rect2(object.position - Vector2(size.x / 2, size.y), size))
		field_labels = Node2D.new()
		field_labels.name = "GatherLabels"
		field_labels.z_index = 5
		field_labels.draw.connect(_draw_field_labels)
		add_child(field_labels)

func add_solid(rect: Rect2) -> void:
	var body = StaticBody2D.new()
	body.position = rect.get_center()
	add_child(body)
	loop.lane._collision(body, rect.size, Vector2.ZERO)
	solids.append(rect)

func label_at(pos: Vector2, text: String, color = Color("fff0c2"), painter: Node2D = null) -> void:
	if painter != null:
		painter.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	else:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func interaction_label(pos: Vector2, text: String, painter: Node2D = null) -> void:
	if not loop.near(pos):
		return
	var player_pos: Vector2 = loop.lane.player.position
	var top: float = player_pos.y - loop.lane.CHARACTER_SIZE.y
	var baseline: float = minf(pos.y - 34, top - 4)
	if baseline < loop.backgrounds[0].size.y + 16:
		baseline = maxf(pos.y + 18, player_pos.y + 18)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	label_at(Vector2(pos.x - width / 2.0, baseline).round(), text, Color("fff0c2"), painter)

func _process(_delta: float) -> void:
	queue_redraw()
	if field_labels != null:
		field_labels.queue_redraw()

func _draw_field_labels() -> void:
	var selected := nearest_interaction()
	if not selected.is_empty():
		if selected.type == "gather":
			var i: int = selected.index
			interaction_label(points[i], loop.state.INGREDIENTS[i % 3] + " " + str(loop.state.nodes[i]) + " E", field_labels)
		else:
			var node = selected.node
			var title: String = {"wood": "砍树 E", "ore": "挖矿 E", "fish": "钓鱼 E"}[node.resource_kind]
			if not node.available():
				title = "次日刷新"
			elif loop.harvest.busy():
				title = loop.harvest.prompt()
			if loop.harvest.action == "bite":
				var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				label_at((loop.lane.player.position + Vector2(-width / 2.0, -70)).round(), title, Color("fff0c2"), field_labels)
			else:
				interaction_label(node.anchor, title, field_labels)
	interaction_label(stations.exit, "小镇 E", field_labels)

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

func _draw() -> void:
	draw_texture(background, Vector2.ZERO)
	if kind == "field":
		for i in range(points.size()):
			var p = points[i]
			var texture_index: int = i % 3 if loop.state.nodes[i] > 0 else 3
			draw_texture(gather_textures[texture_index], p + Vector2(-16, -28))
	else:
		interaction_label(stations.prep, "备料 E")
		for i in range(3):
			var p = seats[i]
			var customer = loop.state.customer_at(i)
			if customer != null:
				var variant = int(customer.get("variant", i)) % customer_sheets.size()
				var frame = 0
				if customer.get("status", "waiting") == "eating":
					frame = 2 + int(floor((3.0 - customer.eating_left) * 2.0)) % 4
				var customer_size: Vector2 = loop.lane.CHARACTER_SIZE
				var source = Rect2(Vector2(frame * customer_size.x, 0), customer_size)
				draw_texture_rect_region(customer_sheets[variant], Rect2(p - Vector2(customer_size.x / 2.0, customer_size.y), customer_size), source)
				if customer.get("status", "waiting") == "waiting":
					label_at(p + Vector2(-39, -customer_size.y - 10), loop.state.DISHES[customer.dish])
					draw_rect(Rect2(p + Vector2(-24, 13), Vector2(48, 3)), Color("513744"))
					draw_rect(Rect2(p + Vector2(-24, 13), Vector2(48 * maxf(0, customer.patience) / 25, 3)), Color("b5dc89"))
	if loop.state.held >= 0:
		var plate: Vector2 = loop.lane.player.position + Vector2(26, -28)
		draw_circle(plate, 12, Color("fff0d2"))
		draw_circle(plate, 6, [Color("be9e69"), Color("c86f93"), Color("93b66b")][loop.state.held])
	if kind == "restaurant":
		interaction_label(stations.exit, "小镇 E")
