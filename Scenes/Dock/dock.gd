extends Node2D
## Shore, wooden pier and fishing spots share the existing harvest state machine.
const ART := "res://Art/Environment/Hearthwood/"
const ResourceNode = preload("res://Scenes/Gameplay/resource_node.gd")
var loop
var spawn := Vector2(42, 238)
var world_size := Vector2i(640, 360)
var stations := {"exit": Vector2(8, 238)}
var solids: Array[Rect2] = []
var resource_nodes: Array = []
var labels: Node2D
var water_surface: Node2D
var boat: Node2D
var elapsed := 0.0
var waves: Array[Vector2] = []

func _ready() -> void:
	y_sort_enabled = true
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "dock_layout.json"))
	spawn = Vector2(layout.spawn[0], layout.spawn[1])
	stations.exit = Vector2(layout.exit[0], layout.exit[1])
	var ground := preload("res://Art/Source/tile_ground.gd").create(ART + "dock_ground.aseprite")
	ground.z_index = -2
	add_child(ground)
	for values in layout.walls:
		var rect := Rect2(values[0], values[1], values[2], values[3])
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		add_child(body)
		loop.lane._collision(body, rect.size, Vector2.ZERO)
		solids.append(rect)
	for entry in layout.props:
		if entry.has("resource_id"):
			var resource := ResourceNode.new()
			resource.configure(entry, loop)
			add_child(resource)
			resource_nodes.append(resource)
			solids.append(resource.footprint)
			continue
		var solid: bool = entry.get("solid", true)
		var object: Node2D = StaticBody2D.new() if solid else Node2D.new()
		object.position = Vector2(entry.x, entry.y)
		add_child(object)
		var sprite := Sprite2D.new()
		sprite.texture = load(ART + entry.kind + ".aseprite")
		sprite.position.y = -sprite.texture.get_height() / 2.0
		object.add_child(sprite)
		preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, entry.kind, loop.lane.weather)
		if solid:
			var size := Vector2(entry.w, entry.h)
			loop.lane._collision(object, size, Vector2(0, -size.y / 2.0))
			solids.append(Rect2(object.position - Vector2(size.x / 2.0, size.y), size))
		if entry.kind == "dock_boat":
			boat = object
	water_surface = Node2D.new()
	water_surface.z_index = -1
	water_surface.draw.connect(_draw_water)
	add_child(water_surface)
	for values in layout.waves:
		waves.append(Vector2(values[0], values[1]))
	labels = Node2D.new()
	labels.z_index = 5
	labels.draw.connect(_draw_labels)
	add_child(labels)

func nearest_interaction() -> Dictionary:
	var best := 27.01
	var selected := {}
	for node in resource_nodes:
		var distance: float = loop.lane.player.position.distance_to(node.anchor)
		if distance < best:
			best = distance
			selected = {"type": "resource", "node": node}
	return selected

func _process(delta: float) -> void:
	elapsed += delta
	if boat != null:
		boat.position.y = 184 + roundf(sin(elapsed * 1.5))
	water_surface.queue_redraw()
	labels.queue_redraw()

func _draw_water() -> void:
	for i in range(waves.size()):
		var p := waves[i] + Vector2(roundf(sin(elapsed * 0.8 + i) * 3), roundf(sin(elapsed + i * 0.7)))
		water_surface.draw_line(p, p + Vector2(7 + i % 7, 0), Color("8bb4ac") if i % 3 == 0 else Color("638e8c"), 1.0)
		if i % 3 == 0:
			water_surface.draw_line(p + Vector2(3, 2), p + Vector2(8, 2), Color("709d96"), 1.0)
	for node in resource_nodes:
		if node.available():
			var p: Vector2 = node.water + Vector2(roundf(sin(elapsed * 1.2 + node.position.x) * 4), 3)
			water_surface.draw_line(p + Vector2(-9, 0), p + Vector2(9, 0), Color("a3c4b5"), 1.0)
			water_surface.draw_line(p + Vector2(-5, 3), p + Vector2(5, 3), Color("709d96"), 1.0)

func _label(pos: Vector2, text: String, ceiling: float = INF) -> void:
	text = tr(text)
	var width: float = loop.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var baseline: float = minf(pos.y - 34, loop.lane.player.position.y - loop.lane.CHARACTER_SIZE.y - 6)
	baseline = minf(baseline, ceiling)
	labels.draw_string(loop.font, Vector2(pos.x - width / 2.0, baseline).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff0c2"))

func _draw_labels() -> void:
	if loop.near(stations.exit):
		_label(stations.exit, "小镇")
	var selected := nearest_interaction()
	if selected.is_empty():
		return
	var node = selected.node
	var text := tr("鱼群 · %d/3") % loop.state.fish_left(node.resource_id)
	if not node.available():
		text = "鱼儿散去 · 次日刷新"
	elif loop.harvest.busy():
		text = loop.harvest.prompt()
	# Keep the prompt above the rod, bobber, bite indicator and fish plaque.
	_label(node.anchor, text, minf(loop.lane.player.position.y - 70, node.water.y - 12))
