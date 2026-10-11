extends RefCounted
## World objects share z=0 and sort at their ground contact, never their image centre.
const GROUND := -10
const SOIL := -9
const FLOOR_DECOR := -8
const ACTOR := 0
const LABEL := 10

static func feet_sprite(sprite: Sprite2D, feet: Vector2, height: float) -> void:
	sprite.position = feet
	sprite.offset = Vector2(0, -height / 2.0)
	sprite.z_index = ACTOR

static func sortable_group(group: Node2D) -> void:
	group.y_sort_enabled = true
	group.z_index = ACTOR
