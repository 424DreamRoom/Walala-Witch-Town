extends SceneTree
## Real movement plus accelerated schedules, with isolated settings and saves.
const Collision = preload("res://Scenes/Gameplay/actor_collision.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Campaign = preload("res://Scenes/Campaign/campaign_state.gd")
const OUT := "res://output/actor_collision/"
const CENTER := Vector2(580, 456)
var lane
var loop
var routines
var checks := 0
var failures := 0

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	Campaign.pending_intro = false
	# Start in town so this audit is independent of new-home art and furniture.
	var state := State.new()
	Saves.pending = {"state": state.to_save_data(), "world": {"location": "town", "position": [408, 364], "town_position": [408, 364], "weather": "clear", "facing": 0}}
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("ACTOR COLLISION ", title, ": ", "PASS" if passed else "FAIL")

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func walk(start: Vector2, direction: Vector2, running: bool = false, ticks: int = 30) -> Vector2:
	lane.test_direction = Vector2.ZERO
	lane.player.position = start
	lane.player.force_update_transform()
	lane.test_running = running
	lane.set_physics_process(true)
	await frames()
	lane.test_direction = direction
	for i in range(ticks): await physics_frame
	lane.test_direction = Vector2.ZERO
	await frames()
	lane.set_physics_process(false)
	return lane.player.position

func reset_actor(actor, start: Vector2, finish: Vector2) -> void:
	actor.position = start
	if actor.is_inside_tree(): actor.force_update_transform()
	actor.destination = finish
	actor.path = PackedVector2Array([finish])
	actor.path_index = 0
	actor.pause_left = 0.0
	actor.blocked_left = 0.0
	actor.activity = "work"
	actor.place = "square"

func encounter(offscreen: bool = false) -> void:
	var first = routines.actors[0]
	var second = routines.actors[1]
	for actor in routines.actors:
		actor.visible = actor == first or actor == second
		Collision.set_active(actor, actor.visible)
	lane.player.position = Vector2(408, 364)
	reset_actor(first, CENTER + Vector2(-40, 0), CENTER + Vector2(40, 0))
	reset_actor(second, CENTER + Vector2(40, 0), CENTER + Vector2(-40, 0))
	var overlap := false
	var jumped := false
	for tick in range(720):
		for actor in [first, second]:
			var before: Vector2 = actor.position
			if actor.position.distance_to(actor.destination) > 0.1:
				routines._step(actor, [actor.destination], 1.0 / 60.0)
			if actor.position.distance_to(before) > actor.speed / 60.0 + 0.01: jumped = true
		var gap: Vector2 = (first.position - second.position) / Collision.FOOT_SIZE
		if gap.length_squared() < 0.99: overlap = true
	var context := "offscreen" if offscreen else "town"
	check(context + " oncoming residents never overlap or jump", not overlap and not jumped)
	check(context + " oncoming residents pass each other", first.position.x > CENTER.x + 25 and second.position.x < CENTER.x - 25)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(4)
	loop = lane.get_node("GameLoop")
	if loop.campaign_controller == null:
		check("gameplay initialized", false)
		quit(1)
		return
	loop.paused_for_test = true
	loop.set_process(false)
	loop.campaign_controller.set_process(false)
	lane.set_physics_process(false)
	lane.automation = true
	routines = loop.campaign_controller.routines
	var all_bodies := true
	for actor in routines.actors:
		all_bodies = all_bodies and actor is CharacterBody2D and actor.has_node("FeetCollision")
		actor.position = Vector2(800 + actor.index * 20, 840)
		actor.force_update_transform()
	check("all ten residents have real collision bodies", all_bodies)
	var feet: CollisionShape2D = lane.player.get_node("FeetCollision")
	check("player has a rounded 10 by 6 ground footprint", feet.shape is CapsuleShape2D and feet.shape.radius == 3 and feet.shape.height == 10 and is_equal_approx(feet.rotation, PI * 0.5) and feet.position == Vector2(0, -3))
	check("player detects both scenery and people", lane.player.collision_layer == Collision.ACTOR_LAYER and lane.player.collision_mask == (Collision.WORLD_LAYER | Collision.ACTOR_LAYER))
	var resident = routines.actors[0]
	resident.position = CENTER
	resident.force_update_transform()
	for running in [false, true]:
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			var end := await walk(CENTER - direction * 30, direction, running)
			var gap: Vector2 = (end - CENTER) / Collision.FOOT_SIZE
			if gap.length() < 0.99 or gap.length() >= 1.1: print("COLLISION DIAGNOSTIC end=", end, " gap=", gap)
			check(("run" if running else "walk") + " stops at resident " + str(direction), gap.length() >= 0.99 and gap.length() < 1.1)
	var behind := await walk(CENTER + Vector2(-24, -12), Vector2.RIGHT)
	check("upper sprites can overlap while feet pass behind", behind.x > CENTER.x + 15 and absf(behind.y - CENTER.y + 12) < 0.2)
	var diagonal := await walk(CENTER + Vector2(-24, -18), Vector2.ONE, false, 60)
	var diagonal_gap: Vector2 = (diagonal - CENTER) / Collision.FOOT_SIZE
	if diagonal.x <= CENTER.x + 8: print("COLLISION DIAGNOSTIC diagonal=", diagonal)
	check("diagonal contact slides around rounded feet", diagonal.x > CENTER.x + 8 and diagonal_gap.length() >= 0.99)
	lane.player.position = CENTER
	lane.player.force_update_transform()
	resident.position = CENTER + Vector2(-30, 0)
	resident.force_update_transform()
	await frames()
	var contact: KinematicCollision2D = resident.move_and_collide(Vector2(60, 0))
	check("resident body also stops against player", contact != null and contact.get_collider() == lane.player and resident.position.x < CENTER.x - 9.9)
	# A standing player is a temporary route obstacle, not a permanent deadlock.
	reset_actor(resident, CENTER + Vector2(-40, 0), CENTER + Vector2(40, 0))
	for tick in range(600):
		if resident.position.x < CENTER.x + 30: routines._step(resident, [resident.destination], 1.0 / 60.0)
	check("resident detours around a stationary player", resident.position.x > CENTER.x + 25)
	encounter()
	loop.enter("store")
	lane.set_physics_process(false)
	encounter(true)
	check("detached town removes resident bodies from active space", not routines.actors[0].is_inside_tree())
	for target in ["store", "blacksmith", "furniture_store"]:
		loop.enter(target)
		lane.set_physics_process(false)
		await frames()
		var staff = loop.area.staff
		var position: Vector2 = staff.global_position
		lane.player.global_position = position + Vector2(20, 0)
		lane.player.force_update_transform()
		contact = lane.player.move_and_collide(Vector2(-40, 0))
		check(target + " staff has one solid feet body", staff.has_node("FeetCollision") and not staff.get_parent() is CollisionObject2D and contact != null and contact.get_collider() == staff)
	loop.enter("town")
	lane.set_physics_process(false)
	loop.state.phase = "night"
	routines.advance(0.0)
	var hidden := true
	for actor in routines.actors:
		hidden = hidden and not actor.visible and actor.collision_layer == 0 and actor.collision_mask == 0
	check("night residents leave no invisible blockers", hidden)
	loop.state.phase = "day"
	routines.advance(0.0)
	check("next morning restores resident collision", routines.actors[0].visible and routines.actors[0].collision_layer == Collision.ACTOR_LAYER)
	loop.enter("restaurant")
	lane.set_physics_process(false)
	loop.area.set_process(false)
	loop.state.customers = [{"seat": 0, "dish": 0, "patience": 25.0, "variant": 0, "status": "waiting", "eating_left": 0.0}]
	loop.area._process(0.0)
	await frames()
	var guest: StaticBody2D = loop.area.customer_bodies[0]
	var seat: Vector2 = loop.area.seats[0]
	lane.player.position = seat + Vector2(30, 0)
	lane.player.force_update_transform()
	contact = lane.player.move_and_collide(Vector2(-60, 0))
	check("occupied restaurant seat blocks at guest feet", contact != null and contact.get_collider() == guest and lane.player.position.x > seat.x + 9.9)
	loop.state.customers[0].status = "eating"
	loop.state.customers[0].eating_left = 1.0
	loop.area._process(0.0)
	check("eating guest keeps collision", guest.collision_layer == Collision.ACTOR_LAYER)
	loop.state.customers.clear()
	loop.area._process(0.0)
	await frames()
	lane.player.position = seat + Vector2(30, 0)
	lane.player.force_update_transform()
	contact = lane.player.move_and_collide(Vector2(-60, 0))
	check("departed guest leaves seat walkable", guest.collision_layer == 0 and contact == null and lane.player.position.x < seat.x - 25)
	loop.state.customers = [{"seat": 5, "dish": 0, "variant": 0}]
	loop.state.campaign.restaurant = 0
	loop.area._process(0.0)
	check("locked tables leave no guest collision", not loop.area.customer_sprites[5].visible and loop.area.customer_bodies[5].collision_layer == 0)
	loop.enter("field")
	lane.set_physics_process(false)
	await frames()
	check("scene change frees old guest collision", not is_instance_valid(guest))
	contact = null
	Saves.end_session()
	lane.queue_free()
	await frames()
	print("ACTOR COLLISION VERIFY END checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
