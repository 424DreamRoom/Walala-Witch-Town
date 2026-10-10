extends Node2D

const ART := "res://Art/Environment/Hearthwood/"
var loop
var solids: Array[Rect2] = []
var stations := {"exit": Vector2(320, 449)}
var spawn := Vector2(320, 405)
var world_size := Vector2i(640, 480)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "home_layout.json"))
	world_size = Vector2i(layout.size[0], layout.size[1])
	spawn = Vector2(layout.spawn[0], layout.spawn[1])
	stations.exit = Vector2(layout.exit[0], layout.exit[1])
	var ground := Sprite2D.new()
	ground.texture = preload("res://Art/Environment/Hearthwood/home_ground.png")
	ground.centered = false
	add_child(ground)
	for values in layout.walls:
		_add_solid(Rect2(values[0], values[1], values[2], values[3]))
	for item in layout.furniture:
		var body := StaticBody2D.new()
		body.position = Vector2(item.x, item.y)
		add_child(body)
		var sprite := Sprite2D.new()
		sprite.texture = load(ART + item.kind + ".png")
		sprite.position.y = -sprite.texture.get_height() / 2.0
		body.add_child(sprite)
		preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, item.kind)
		var size := Vector2(item.w, item.h)
		loop.lane._collision(body, size, Vector2(0, -size.y / 2))
		solids.append(Rect2(body.position - Vector2(size.x / 2, size.y), size))

func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	add_child(body)
	loop.lane._collision(body, rect.size, Vector2.ZERO)
	solids.append(rect)
