extends StaticBody2D
## A feet-sorted lantern keeper, separate from the ten gift/story residents.
const Guide = preload("res://Scenes/Campaign/guide_profile.gd")
const ActorCollision = preload("res://Scenes/Gameplay/actor_collision.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
var sprite: Sprite2D
var walk_elapsed := 0.0

func pose_walk(delta: float, moving: bool) -> void:
	walk_elapsed = walk_elapsed + delta if moving else 0.0
	var bob := -1.0 if moving and int(walk_elapsed * 8.0) % 2 else 0.0
	sprite.position = position.round() - position + Vector2(0,bob)

func _init() -> void:
	name = "Guide_Yingluo"
	ActorCollision.attach(self)
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-8,-3), Vector2(-5,-5), Vector2(5,-5), Vector2(8,-3), Vector2(5,0), Vector2(-5,0)])
	shadow.color = Color(0.12, 0.2, 0.18, 0.3)
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = load(Guide.SPRITE)
	Depth.feet_sprite(sprite, Vector2.ZERO, 32)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func sync(daytime: bool) -> void:
	visible = daytime
	ActorCollision.set_active(self, daytime)
