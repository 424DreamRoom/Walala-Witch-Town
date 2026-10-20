extends CharacterBody2D
## Feet are the actor origin, so the existing town Y sort handles occlusion.
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
const ActorCollision = preload("res://Scenes/Gameplay/actor_collision.gd")
var resident_id := ""
var index := 0
var speed := 30.0
var sprite: Sprite2D
var path := PackedVector2Array()
var path_index := 0
var destination := Vector2.ZERO
var activity := ""
var place := ""
var routine_key := ""
var stop_index := 0
var pause_left := 0.0
var blocked_left := 0.0
var facing := 0
var elapsed := 0.0
var moving := false
var shadow: Polygon2D

func configure(id: String, ordinal: int) -> void:
	resident_id = id
	index = ordinal
	name = "Resident_" + id
	speed = 27.0 + float(ordinal % 4) * 3.0
	elapsed = ordinal * 0.37
	ActorCollision.attach(self)
	shadow = Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-8,-3), Vector2(-5,-6), Vector2(5,-6), Vector2(8,-3), Vector2(5,0), Vector2(-5,0)])
	shadow.color = Color(0.12, 0.2, 0.18, 0.3)
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = load("res://Art/Characters/NPC32/residents/" + id + ".aseprite")
	sprite.hframes = 22
	Depth.feet_sprite(sprite, Vector2.ZERO, 32)
	sprite.frame = 16
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func face(direction: Vector2) -> void:
	if direction.length_squared() < 0.01: return
	if absf(direction.x) > absf(direction.y):
		facing = 2 if direction.x > 0.0 else 3
	else:
		facing = 0 if direction.y > 0.0 else 1

func pose(delta: float, walking: bool) -> void:
	if moving != walking: elapsed = 0.0
	moving = walking
	elapsed += delta
	# Authored atlas: four walk frames per direction, then front idle 16..17.
	sprite.frame = facing * 4 + int(elapsed * 7.0) % 4 if moving else (16 + int(elapsed * 0.65) % 2 if facing == 0 else facing * 4)
	var bob := 0.0
	if moving:
		bob = -1.0 if int(elapsed * 7.0) % 2 == 0 else 0.0
	sprite.position = position.round() - position + Vector2(0, bob)
	shadow.scale = Vector2(1.0 + (0.06 if moving else 0.0), 1.0 - (0.08 if moving else 0.0))
