extends SceneTree
## Exercise road crossings and explicit doorway interactions with real input.
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/road_connections/"
var lane
var loop
var failures := 0
var capture := "--road-capture" in OS.get_cmdline_user_args()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = OUT + "preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = OUT + "saves_%d" % OS.get_process_id()
	Saves.end_session()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("SCENE EXIT ", title, ": PASS" if ok else ": FAIL")
	if not ok:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame
		await physics_frame

func interact_event(pressed: bool, echo: bool = false, code: Key = KEY_E) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await frames()
	if root.get_node("SceneTransition").active:
		await root.get_node("SceneTransition").finished

func interact_key(code: Key = KEY_E) -> void:
	for pressed in [true, false]:
		await interact_event(pressed, false, code)

func use_door(exit: Dictionary) -> bool:
	var source: String = loop.location
	var title := source + " to " + str(exit.target)
	check("walk to door approach " + title, await Navigation.walk(lane, exit.door - exit.direction * 40.0))
	# A key already held before reaching the door must not open it.
	await interact_event(true)
	check("distant interaction stays in scene " + title, loop.location == source)
	check("walk to doorway " + title, await Navigation.walk(lane, exit.door))
	lane.test_direction = exit.direction
	await frames(8)
	lane.test_direction = Vector2.ZERO
	await frames(5)
	check("walking and idling at door stays in scene " + title, loop.location == source)
	await interact_event(true, true)
	check("held interaction at door stays in scene " + title, loop.location == source)
	await interact_event(false)
	paused = true
	await interact_key()
	check("paused interaction cannot use door " + title, loop.location == source)
	paused = false
	await interact_event(true)
	check("fresh stationary interaction uses door " + title, loop.location == exit.target)
	await interact_event(true, true)
	check("held interaction after travel stays in destination " + title, loop.location == exit.target)
	await interact_event(false)
	return loop.location == exit.target

func cross(direction: Vector2, target: String) -> bool:
	lane.test_direction = direction
	for i in range(90):
		await frames(1)
		if loop.location == target:
			lane.test_direction = Vector2.ZERO
			if root.get_node("SceneTransition").active:
				await root.get_node("SceneTransition").finished
			return true
	lane.test_direction = Vector2.ZERO
	return false

func shot(title: String) -> void:
	if not capture:
		return
	loop.state.message = ""
	loop.last_message = ""
	loop.message_left = 0.0
	lane.camera.force_update_scroll()
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	# Verify scene crossings independently of resident routes and conversations.
	loop.campaign_controller.set_process(false)
	for actor in loop.campaign_controller.actors:
		actor.visible = false
		preload("res://Scenes/Gameplay/actor_collision.gd").set_active(actor, false)
	check("scene preview starts outside home", loop.location == "farm" and lane.player.position == loop.HOME_EXIT_POSITION and lane.player.get_parent() == loop.area)
	loop.enter("home")
	await use_door(loop._scene_exits()[0])
	check("home start exits to farm", loop.location == "farm")
	check("first home exit matches front doorstep", lane.player.position == Vector2(270, 258) and lane.facing == 0)
	var feet := preload("res://Scenes/Gameplay/actor_collision.gd").footprint(lane.player.position)
	check("home exit arrival has no solid overlap", not loop.area.solids.any(func(rect): return rect.intersects(feet)))
	await frames(8)
	check("home exit arrival stays on farm while idle", loop.location == "farm")
	check("home exit arrival rearms town crossing", not loop.exit_latched)
	await shot("home_exit")
	check("walk from doorstep to town road", await Navigation.walk(lane, loop.area.stations.exit - Vector2(36, 0)))
	check("walking right from farm road enters town", await cross(Vector2.RIGHT, "town"))
	check("farm arrives at marked town entrance", lane.player.position == Vector2(8, 364))
	await frames(8)
	check("marked town entrance stays in town while idle", loop.location == "town")
	feet = preload("res://Scenes/Gameplay/actor_collision.gd").footprint(lane.player.position)
	check("marked town entrance has no solid overlap", not lane.solid_rects.any(func(rect): return rect.intersects(feet)))
	loop._restore_world({"location": "farm", "position": [938, 364], "town_position": [408, 364], "farm_position": [938, 364], "weather": "clear", "facing": 2})
	await frames()
	# A valid legacy point remains on the enlarged farm; cross from its current exit.
	var legacy_farm_exit: Dictionary = loop._scene_exits()[0]
	check("legacy farm position reaches current exit", await Navigation.walk(lane, legacy_farm_exit.rect.get_center() - legacy_farm_exit.direction * 34.0))
	check("legacy farm save arrives at marked town entrance", await cross(Vector2.RIGHT, "town") and lane.player.position == Vector2(8, 364))
	loop.enter("town")
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	check("forest connection reaches north edge", loop.FIELD_GATE == Vector2(454, 10))
	check("dock connection reaches east edge", loop.DOCK_GATE == Vector2(lane.world_size.x - 8, 652))
	check("farm connection reaches west edge", loop.FARM_GATE == Vector2(8, 364))
	for label in loop.gate_labels:
		check("gate prompt has no interaction key", not label.text.contains(" E"))
	var exits: Array = loop._scene_exits()
	for exit in exits:
		var target: String = exit.target
		var approach: Vector2 = exit["return"] if exit.has("door") else exit.rect.get_center() - exit.direction * 34.0
		check("walk actual town route to " + target, await Navigation.walk(lane, approach))
		if target in ["field", "farm", "dock"]:
			await shot("town_to_" + target)
		if exit.has("door"):
			await use_door(exit)
		else:
			await interact_key()
			check("E at road approach stays in town " + target, loop.location == "town")
			check("walking automatically enters " + target, await cross(exit.direction, target))
		if loop.location != target:
			continue
		check("town collision bodies detached " + target, not lane.world.is_inside_tree())
		if target in ["field", "farm", "dock"]:
			var return_exit: Dictionary = loop._scene_exits()[0]
			check("matching return direction " + target, return_exit.direction == -exit.direction)
			check("arrival is on matching road surface " + target, loop.footstep_surfaces.resolve(target, lane.player.position, "clear") == {"field": "dirt", "farm": "stone", "dock": "wood"}[target])
			await shot(target + "_arrival")
		lane.test_direction = exit.direction
		await frames(5)
		lane.test_direction = Vector2.ZERO
		check("held entry direction does not bounce " + target, loop.location == target)
		if target == "farm":
			var house: Dictionary = loop._scene_exits()[1]
			await use_door(house)
			if loop.location == "home":
				await use_door(loop._scene_exits()[0])
				check("house returns to front doorstep", loop.location == "farm" and lane.player.position.distance_to(house["return"]) < 0.1)
		var back: Dictionary = loop._scene_exits()[0]
		if back.has("door"):
			await use_door(back)
		else:
			var return_approach: Vector2 = back.rect.get_center() - back.direction * 36.0
			check("walk actual road route to exit " + target, await Navigation.walk(lane, return_approach))
			await interact_key()
			check("E at road exit approach stays inside " + target, loop.location == target)
			var before: Vector2 = lane.player.position
			paused = true
			lane.test_direction = back.direction
			await frames(5)
			check("pause freezes crossing " + target, loop.location == target and lane.player.position == before)
			lane.test_direction = Vector2.ZERO
			paused = false
			check("walking automatically returns " + target, await cross(back.direction, "town"))
		check("safe town arrival " + target, lane.player.position.distance_to(exit["return"]) < 0.1)
		if target in ["field", "farm", "dock"]:
			await shot(target + "_return")
		lane.test_direction = back.direction
		await frames(5)
		lane.test_direction = Vector2.ZERO
		check("held return direction does not reenter " + target, loop.location == "town")
		check("town camera restored " + target, lane.camera.limit_right == lane.world_size.x and lane.camera.limit_bottom == lane.world_size.y)
		await frames(20)
		check("idle arrival remains stable " + target, loop.location == "town")
	# Standing in a restored trigger cannot travel until the player walks out.
	loop._restore_world({"location": "town", "position": [loop.FIELD_GATE.x, loop.FIELD_GATE.y], "town_position": [loop.FIELD_GATE.x, loop.FIELD_GATE.y], "weather": "clear", "facing": 1})
	await frames()
	await interact_key()
	lane.test_direction = Vector2.UP
	await frames(10)
	lane.test_direction = Vector2.ZERO
	check("restored trigger does not auto travel", loop.location == "town")
	check("leave restored trigger", await Navigation.walk(lane, loop.FIELD_GATE + Vector2(0, 50)))
	check("restored trigger rearms after leaving", await cross(Vector2.UP, "field"))
	loop.enter("town")
	await frames()
	# Walking parallel to a doorway should not count as entering the door.
	lane.player.position = loop.STORE_GATE + Vector2(-30, 0)
	await frames()
	lane.test_direction = Vector2.RIGHT
	await frames(23)
	lane.test_direction = Vector2.ZERO
	check("passing a doorway sideways stays in town", loop.location == "town")
	# Loaded doorways stay put until a fresh press, then work without walking out.
	for kind in ["restaurant", "blacksmith", "store", "home"]:
		loop.enter("farm" if kind == "home" else "town")
		var door: Dictionary
		for candidate in loop._scene_exits():
			if candidate.target == kind: door = candidate
		var position: Vector2 = door.door
		var source: String = loop.location
		loop._restore_world({"location": source, "position": [position.x, position.y], "town_position": [loop.town_position.x, loop.town_position.y], "weather": "clear", "facing": 1})
		await frames(8)
		check("restored exterior door stays outside " + kind, loop.location == source)
		await interact_key()
		check("restored exterior door accepts interaction " + kind, loop.location == kind)
		if loop.location != kind: continue
		position = loop.area.stations.exit
		loop._restore_world({"location": kind, "position": [position.x, position.y], "town_position": [loop.town_position.x, loop.town_position.y], "farm_position": [270, 310], "weather": "clear", "facing": 0})
		await frames(8)
		check("restored interior door stays inside " + kind, loop.location == kind)
		await interact_key()
		check("restored interior door accepts interaction " + kind, loop.location == source)
		if kind == "home":
			check("legacy home save exits at front doorstep", lane.player.position == Vector2(270, 258) and lane.facing == 0)
	# Door input follows the saved interaction binding rather than a hardcoded E.
	loop.enter("town")
	var bindings = root.get_node("InputBindings")
	check("rebind interaction in isolated preferences", bindings.assign_key("interact", 0, KEY_F).ok)
	lane.player.position = loop.STORE_GATE
	await frames()
	await interact_key()
	check("old interaction key cannot open door", loop.location == "town")
	await interact_key(KEY_F)
	check("rebound interaction key opens door", loop.location == "store")
	check("restore default test binding", bindings.reset_defaults().ok)
	loop.enter("town")
	# Keep the existing night closure and suppress repeated feedback while held.
	loop.state.phase = "night"
	loop.last_phase = "night"
	for pair in [[loop.FIELD_GATE + Vector2(0, 50), Vector2.UP, "野外"], [loop.DOCK_GATE + Vector2(-50, 0), Vector2.RIGHT, "码头"]]:
		lane.player.position = pair[0]
		await frames()
		lane.test_direction = pair[1]
		await frames(35)
		check("night entrance remains closed " + pair[2], loop.location == "town" and loop.state.message == "夜间关闭")
		var feedback: float = loop.message_left
		await frames(15)
		check("closed entrance does not repeat feedback " + pair[2], loop.message_left < feedback)
		lane.test_direction = Vector2.ZERO
	loop.state.phase = "day"
	loop.last_phase = "day"
	lane.player.position = loop.STORE_GATE
	await frames()
	loop.state.phase = "result"
	loop.last_phase = "result"
	await interact_key()
	check("settlement blocks door interaction", loop.location == "town")
	lane.test_direction = Vector2.UP
	await frames(30)
	lane.test_direction = Vector2.ZERO
	check("settlement blocks automatic travel", loop.location == "town")
	lane.queue_free()
	await frames()
	loop = null
	lane = null
	await create_timer(0.2).timeout
	print("SCENE EXIT VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
