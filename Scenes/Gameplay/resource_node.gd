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

func configure(entry: Dictionary, game) -> void:
	loop = game
	resource_id = entry.resource_id
	resource_kind = entry.resource_type
	position = Vector2(entry.x, entry.y)
	anchor = position + Vector2(0, 30 if resource_kind == "ore" else 28 if resource_kind == "fish" else 18)
	water = position + Vector2(0, -38)
	set_meta("outdoor_kind", entry.kind)
	original = load(ART + entry.kind + ".png")
	if resource_kind != "fish":
		depleted = load(ART + ("harvest_stump.png" if resource_kind == "wood" else "harvest_rubble.png"))
	sprite = Sprite2D.new()
	add_child(sprite)
	var size := Vector2(entry.w, entry.h)
	loop.lane._collision(self, size, Vector2(0, -size.y / 2.0))
	footprint = Rect2(position - Vector2(size.x / 2.0, size.y), size)
	refresh()
	ambient = preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, entry.kind, loop.lane.weather)

func available() -> bool:
	return loop.state.fish_left(resource_id) > 0 if resource_kind == "fish" else loop.state.resource_left(resource_id) > 0

func refresh() -> void:
	var displayed: Texture2D = original if available() or resource_kind == "fish" else depleted
	sprite.texture = displayed
	sprite.position = Vector2(0, -displayed.get_height() / 2.0)
	if ambient != null:
		ambient.set_enabled(displayed == original)
	queue_redraw()

func hit() -> void:
	shake_left = 0.24
	refresh()

func _process(delta: float) -> void:
	shake_left = maxf(0.0, shake_left - delta)
	sprite.position.x = roundf(sin(shake_left * 70.0) * 2.0) if shake_left > 0.0 else 0.0
	queue_redraw()

func _draw() -> void:
	if resource_kind == "fish" or not available():
		return
	var left: int = loop.state.resource_left(resource_id)
	if left == loop.state.RESOURCE_HITS:
		return
	var top := -24
	draw_rect(Rect2(-12, top, 24, 4), Color("3e473e"))
	draw_rect(Rect2(-11, top + 1, 22.0 * left / loop.state.RESOURCE_HITS, 2), Color("d9bd82"))
