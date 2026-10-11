extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const OUT := "res://output/resident_verification/"
var failures := 0
var checks := 0
var lane
var loop
var routines
var capture := false

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	C.pending_intro = false
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("RESIDENT TEST ", title, ": ", "PASS" if passed else "FAIL")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func at_time(minutes: float) -> void:
	loop.state.phase = "day"
	loop.state.remaining = State.DAY_SECONDS * (1080.0 - minutes) / 720.0

func positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for actor in routines.actors: result.append(actor.position)
	return result

func shot(title: String) -> void:
	if not capture: return
	await frames()
	await RenderingServer.frame_post_draw
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)

func simulate(seconds: float, tick_clock: bool = false) -> Dictionary:
	var hit := 0
	var jump := 0
	var invalid_frame := 0
	var overlap := 0
	var walked: Array[float] = []
	walked.resize(routines.actors.size())
	walked.fill(0.0)
	var dt := 1.0 / 12.0
	for frame in range(ceili(seconds / dt)):
		var before := positions()
		if tick_clock: loop.state.tick(dt)
		routines.advance(dt)
		for i in range(routines.actors.size()):
			var actor = routines.actors[i]
			var distance: float = before[i].distance_to(actor.position)
			walked[i] += distance
			if distance > actor.speed * dt + 0.01: jump += 1
			if actor.sprite.frame < 0 or actor.sprite.frame >= 22: invalid_frame += 1
			var feet := Rect2(actor.position - Vector2(5,6), Vector2(10,6))
			for obstacle in routines.obstacles:
				if obstacle.intersects(feet): hit += 1; break
			if actor.visible:
				for j in range(i):
					var gap: Vector2 = (actor.position - routines.actors[j].position) / Vector2(10, 6)
					if gap.length_squared() < 0.99: overlap += 1
	return {"hit": hit, "jump": jump, "frames": invalid_frame, "walked": walked, "overlap": overlap}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	loop = lane.get_node("GameLoop")
	loop.enter("town")
	loop.set_process(false)
	loop.campaign_controller.set_process(false)
	lane.set_physics_process(false)
	routines = loop.campaign_controller.routines
	check("all ten residents installed with feet origins", routines.actors.size() == 10 and routines.actors[0].sprite.offset == Vector2(0,-16) and lane.actors.y_sort_enabled)
	var no_nameplates := true
	for i in range(routines.actors.size()):
		no_nameplates = no_nameplates and not routines.actors[i].has_node("ResidentName")
	check("all residents have no overhead names", no_nameplates)
	var reachable := true
	for points in routines.places.values():
		for point in points:
			if routines.route(lane.SPAWN, point).is_empty(): reachable = false
	for point in routines.shelters:
		if routines.route(lane.SPAWN, point).is_empty(): reachable = false
	check("every activity and shelter reachable from town", reachable)
	await shot("opening_00")
	var first := simulate(5.0)
	var moved := 0
	for distance in first.walked:
		if distance > 8.0: moved += 1
	check("all residents act within first five seconds", moved == 10)
	check("opening movement avoids buildings and gates", first.hit == 0 and first.jump == 0 and first.frames == 0)
	await shot("opening_05")

	# A full accelerated day exercises transitions and the real phase timer.
	at_time(360.0)
	var full_day := simulate(State.DAY_SECONDS + 0.25, true)
	check("whole day has no wall crossings or teleportation", full_day.hit == 0 and full_day.jump == 0)
	check("whole day keeps resident feet separated", full_day.overlap == 0)
	check("whole day uses valid authored frames", full_day.frames == 0)
	var active := true
	for i in range(full_day.walked.size()):
		if full_day.walked[i] < 300.0:
			active = false
			print("RESIDENT DIAGNOSTIC low distance ", routines.actors[i].resident_id, " ", full_day.walked[i])
	check("every resident has sustained daily activity", active)
	# Sunset now waits for the existing service confirmation. Residents remain
	# solid until that confirmation actually changes the phase to night.
	check("sunset keeps residents until service confirmation", loop.state.phase == "day" and loop.state.remaining == 0.0 and routines.actors[0].visible and routines.actors[0].collision_layer == 2)
	loop.state.menu.fill(false)
	loop.state.menu[0] = true
	loop.state.end_phase()
	routines.advance(0.0)
	var hidden := true
	for actor in routines.actors:
		if actor.visible: hidden = false
	check("night hands residents to existing restaurant loop", loop.state.phase == "night" and hidden)
	loop.state.phase = "result"
	loop.state.next_day()
	var next_day := simulate(5.0)
	check("next morning resumes without position jumps", next_day.hit == 0 and next_day.jump == 0 and routines.actors[0].visible)

	at_time(600.0)
	routines.advance(0.0)
	check("work destinations match resident roles", routines.actors[1].activity == "work" and routines.actors[1].destination.distance_to(Vector2(1020,576)) < 100.0 and routines.actors[2].destination.x > 1100.0)
	var boundary := positions()
	at_time(720.0)
	routines.advance(0.0)
	check("schedule change replans without teleporting", boundary == positions() and routines.actors[1].activity == "lunch")
	for weather in ["rain", "snow"]:
		lane.weather.set_weather(weather)
		var before := positions()
		routines.advance(0.0)
		check(weather + " changes destination without teleporting", before == positions() and routines.actors[0].activity == "shelter")
		var weather_run := simulate(120.0)
		var arrived := true
		var distinct: Array[Vector2] = []
		for actor in routines.actors:
			if actor.position.distance_to(actor.destination) > 1.0:
				arrived = false
				print("RESIDENT DIAGNOSTIC shelter ", actor.resident_id, " at ", actor.position, " target ", actor.destination, " path ", actor.path_index, "/", actor.path.size())
			if actor.destination in distinct: arrived = false
			distinct.append(actor.destination)
		check(weather + " residents reach separate shelters safely", arrived and weather_run.hit == 0 and weather_run.jump == 0)
		if weather_run.hit > 0 or weather_run.jump > 0: print("RESIDENT DIAGNOSTIC weather ", weather_run)
	lane.weather.clear_weather()
	routines.advance(0.0)
	check("clear weather restores daily activities", routines.actors[0].activity == "lunch")
	var restored := State.new()
	check("existing save schema remains compatible", restored.restore_save_data(loop.state.to_save_data()) and is_equal_approx(restored.get_time_minutes(), loop.state.get_time_minutes()))

	# Inactive town is detached by the game; residents still follow the clock.
	loop.enter("store")
	check("town detached in interior", not lane.world.is_inside_tree())
	at_time(900.0)
	var offscreen := simulate(90.0)
	var background_active := false
	for distance in offscreen.walked:
		if distance > 50.0: background_active = true
	check("offscreen residents keep their routines", background_active and offscreen.hit == 0 and offscreen.jump == 0)
	check("offscreen residents keep solid feet separated", offscreen.overlap == 0)
	loop.enter("town")
	check("return restores same resident nodes", lane.world.is_inside_tree() and routines.actors[0].is_inside_tree())
	await shot("workday")

	# Actual moving actor is selected by feet distance and pauses with dialogue.
	var actor = routines.actors[0]
	lane.player.position = actor.position + Vector2(0,24)
	check("nearest visible resident selected", routines.nearest(lane.player.position) == actor)
	check("moving resident interaction succeeds", loop.campaign_controller.try_interact() and loop.hud.mode == "dialogue" and paused)
	var frozen := positions()
	routines.advance(2.0)
	await frames(3)
	check("dialogue freezes all resident positions", frozen == positions() and not actor.moving)
	await shot("conversation")
	loop.hud.close_modal()
	lane.player.position = lane.SPAWN
	var resumed := simulate(20.0)
	check("dialogue close resumes activities", not paused and resumed.walked[0] > 5.0)
	# Genuine frame callbacks still update the routines after deterministic checks.
	var elapsed_before: float = routines.actors[0].elapsed
	loop.campaign_controller.set_process(true)
	await frames(10)
	check("controller keeps real frame updates", not is_equal_approx(routines.actors[0].elapsed, elapsed_before))
	Saves.end_session()
	print("RESIDENT VERIFY END checks=", checks, " failures=", failures)
	lane.queue_free()
	await frames(4)
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
