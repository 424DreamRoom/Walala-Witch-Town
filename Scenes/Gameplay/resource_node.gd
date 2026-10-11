extends StaticBody2D

const ART := "res://Art/Environment/Hearthwood/"
var loop
var resource_id := ""
var resource_kind := "wood"
var anchor := Vector2.ZERO
var water := Vector2.ZERO
var sprite: Sprite2D
var original: Texture2D
var depleted: Texture2D
var shake_left := 0.0
var footprint := Rect2()
var ambient: AmbientAnimation
var status_layer: Node2D
var permanent_clear := false

func configure(entry: Dictionary, game) -> void:
	loop = game
	resource_id = entry.resource_id
	permanent_clear = resource_id.begins_with("farm_")
	resource_kind = entry.resource_type
	position = Vector2(entry.x, entry.y)
	anchor = position + Vector2(0, 30 if resource_kind == "ore" else 28 if resource_kind == "fish" else 18)
	water = position + Vector2(0, -38)
	if entry.has("anchor"):
		anchor = Vector2(entry.anchor[0], entry.anchor[1])
	if entry.has("water"):
		water = Vector2(entry.water[0], entry.water[1])
	set_meta("outdoor_kind", entry.kind)
	original = load(ART + entry.kind + ".aseprite")
	if resource_kind != "fish":
		depleted = load(ART + ("harvest_stump.aseprite" if resource_kind == "wood" else "harvest_rubble.aseprite"))
	sprite = Sprite2D.new()
	add_child(sprite)
	var size := Vector2(entry.w, entry.h)
	loop.lane._collision(self, size, Vector2(0, -size.y / 2.0))
	footprint = Rect2(position - Vector2(size.x / 2.0, size.y), size)
	refresh()
	ambient = preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, entry.kind, loop.lane.weather)
	status_layer = Node2D.new()
	status_layer.z_index = preload("res://Scenes/Gameplay/world_depth.gd").LABEL
	status_layer.draw.connect(_draw_status)
	add_child(status_layer)

func available() -> bool:
	if resource_kind == "fish" and ":" in resource_id and loop.state.Campaign.eligible_fish(loop.state,resource_id.get_slice(":",0)).is_empty(): return false
	return loop.state.fish_left(resource_id) > 0 if resource_kind == "fish" else loop.state.resource_left(resource_id) > 0

func refresh() -> void:
	if permanent_clear:
		visible = available()
		collision_layer = 1 if visible else 0
		set_process(visible)
	var displayed: Texture2D = original if available() or resource_kind == "fish" else depleted
	sprite.texture = displayed
	sprite.position = Vector2(0, -displayed.get_height() / 2.0)
	if ambient != null:
		ambient.set_enabled(displayed == original)
	queue_redraw()
	if is_instance_valid(status_layer): status_layer.queue_redraw()

func hit() -> void:
	shake_left = 0.24
	refresh()
	if permanent_clear and loop.location == "farm": loop.area.refresh_resources()

func _process(delta: float) -> void:
	shake_left = maxf(0.0, shake_left - delta)
	sprite.position.x = roundf(sin(shake_left * 70.0) * 2.0) if shake_left > 0.0 else 0.0
	queue_redraw()
	status_layer.queue_redraw()

func _draw_status() -> void:
	if resource_kind == "fish" or not available():
		return
	var left: int = loop.state.resource_left(resource_id)
	if left == loop.state.RESOURCE_HITS:
		return
	var top := -24
	status_layer.draw_rect(Rect2(-12, top, 24, 4), Color("3e473e"))
	status_layer.draw_rect(Rect2(-11, top + 1, 22.0 * left / loop.state.RESOURCE_HITS, 2), Color("d9bd82"))
