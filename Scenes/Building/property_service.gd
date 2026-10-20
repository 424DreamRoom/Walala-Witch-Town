extends Node
## A persistent town service; transactions still belong to the saved loop state.
const NAME := "绮屋 · 房地产魔女"
const POSITION := Vector2(456, 744)
const ActorCollision = preload("res://Scenes/Gameplay/actor_collision.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
var loop
var actor: StaticBody2D
var sprite: Sprite2D
var caption: Label
var elapsed := 0.0

func _ready() -> void:
	actor = StaticBody2D.new()
	actor.name = "PropertyWitch"
	actor.position = loop.campaign_controller.routines.safe_point(POSITION)
	ActorCollision.attach(actor)
	sprite = Sprite2D.new()
	# Reuse an existing native witch atlas without changing any source pixels.
	sprite.texture = load("res://Art/Characters/NPC32/customers/pink_longblue.aseprite")
	sprite.hframes = 6
	preload("res://Scenes/Gameplay/world_depth.gd").feet_sprite(sprite, Vector2.ZERO, 32)
	actor.add_child(sprite)
	caption = Label.new()
	UIFont.apply_control(caption)
	caption.position = Vector2(-72, -53)
	caption.size = Vector2(144, 18)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_shadow_color", Color("30251f"))
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 1)
	actor.add_child(caption)
	loop.lane.actors.add_child(actor)
	loop.campaign_controller.routines.visitors.append(actor)

func _process(delta: float) -> void:
	elapsed += delta
	var active: bool = loop.state.phase == "day"
	actor.visible = active
	ActorCollision.set_active(actor, active)
	sprite.frame = int(elapsed / 0.9) % 2
	caption.text = tr("房地产魔女")
	caption.visible = loop.location == "town" and loop.lane.player.position.distance_to(actor.position) < 90.0

func available() -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and loop.location == "town" and loop.state.phase == "day" and loop.near(actor.position) and not loop.save_menu.open and not loop.save_menu.leaving

func try_interact() -> bool:
	if not available(): return false
	var other = loop.campaign_controller.routines.nearest(loop.lane.player.position)
	if other != null and loop.lane.player.position.distance_to(other.position) < loop.lane.player.position.distance_to(actor.position): return false
	var guide = loop.campaign_controller.guide
	if guide.visible and loop.lane.player.position.distance_to(guide.position) < loop.lane.player.position.distance_to(actor.position): return false
	open()
	return true

func open() -> void:
	if not available() or not loop.hud._begin_modal("property"): return
	var panel := preload("res://Scenes/Building/property_panel.gd").new()
	panel.loop = loop
	panel.provider = weakref(self)
	loop.hud.modal.add_child(panel)

func _exit_tree() -> void:
	if is_instance_valid(actor): actor.queue_free()
