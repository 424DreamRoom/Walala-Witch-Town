extends RefCounted
## Only the ground footprint is solid; the upper sprite remains free to overlap.
const WORLD_LAYER := 1
const ACTOR_LAYER := 2
const FOOT_SIZE := Vector2(10, 6)
const FOOT_OFFSET := Vector2(0, -3)

static func attach(body: CollisionObject2D) -> CollisionShape2D:
	var collision := CollisionShape2D.new()
	collision.name = "FeetCollision"
	var shape := CapsuleShape2D.new()
	shape.radius = FOOT_SIZE.y * 0.5
	shape.height = FOOT_SIZE.x
	collision.shape = shape
	collision.rotation = PI * 0.5
	collision.position = FOOT_OFFSET
	body.add_child(collision)
	if body is CharacterBody2D:
		body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	set_active(body, true)
	return collision

static func set_active(body: CollisionObject2D, active: bool) -> void:
	body.collision_layer = ACTOR_LAYER if active else 0
	body.collision_mask = WORLD_LAYER | ACTOR_LAYER if active and body is CharacterBody2D else 0

static func footprint(feet: Vector2) -> Rect2:
	return Rect2(feet + FOOT_OFFSET - FOOT_SIZE * 0.5, FOOT_SIZE)

static func blocks_motion(start: Vector2, finish: Vector2, other: Vector2) -> bool:
	# Enclose both rounded feet in an ellipse with a little breathing room.
	# Sweep the complete step so large deltas cannot pass through a resident,
	# including while the town is detached.
	var radii := FOOT_SIZE + Vector2(2, 2)
	var first := (start - other) / radii
	var last := (finish - other) / radii
	if first.length_squared() < 1.0 and last.length_squared() > first.length_squared():
		return false
	return Geometry2D.get_closest_point_to_segment(Vector2.ZERO, first, last).length_squared() < 1.0
