extends StaticBody2D
## A feet-sorted lantern keeper, separate from the ten gift/story residents.
const Guide = preload("res://Scenes/Campaign/guide_profile.gd")
const ActorCollision = preload("res://Scenes/Gameplay/actor_collision.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
var sprite: Sprite2D
var walk_elapsed := 0.0
var facing := 0
var walking := false

func face(direction: Vector2) -> void:
	if direction.is_zero_approx(): return
	if absf(direction.x) > absf(direction.y):
		facing = 2 if direction.x > 0.0 else 3
	else:
		facing = 0 if direction.y > 0.0 else 1

func pose_walk(delta: float, moving: bool) -> void:
	if walking != moving: walk_elapsed = 0.0
	walking = moving
	walk_elapsed += maxf(0.0, delta) if moving else 0.0
	# Native 140 ms walk cels contain the stride and bob; keep feet on the grid.
	sprite.frame = facing * 4 + int(walk_elapsed / 0.14) % 4 if moving else [16,18,19,20][facing]
	sprite.position = position.round() - position

func _init() -> void:
	name = "Guide_Yingluo"
	ActorCollision.attach(self)
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-8,-3), Vector2(-5,-5), Vector2(5,-5), Vector2(8,-3), Vector2(5,0), Vector2(-5,0)])
	shadow.color = Color(0.12, 0.2, 0.18, 0.3)
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = load(Guide.SPRITE)
	sprite.hframes = 21
	sprite.frame = 16
	Depth.feet_sprite(sprite, Vector2.ZERO, 32)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func sync(daytime: bool) -> void:
	visible = daytime
	ActorCollision.set_active(self, daytime)
