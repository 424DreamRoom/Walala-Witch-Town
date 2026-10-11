extends SceneTree
const OUT := "res://Art/Environment/Hearthwood/Verification/TownPlan/"
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
var lane
var loop
var failures := 0
var capture := "--town-capture" in OS.get_cmdline_user_args()

func _initialize() -> void:
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("TOWN PLAN ", title, ": PASS" if ok else ": FAIL")
	if not ok:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame
		await physics_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()

func shot(title: String) -> void:
	if not capture:
		return
	loop.state.message = ""
	loop.last_message = ""
	loop.message_left = 0.0
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)
	check("capture window " + title, root.get_texture().get_image().save_png(OUT + title + "_window.png") == OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lane.ART + "town_layout.json"))
	check("farm layout revision", plan.revision == 3)
	check("home relocated leaving eight town buildings", plan.buildings.size() == 8)
	check("public square and sixteen lanes", plan.plazas.size() == 1 and plan.paths.size() == 16)
	check("all functional entrances retained", plan.gates.size() == 7 and loop.GATES.size() == 7)
	var expected_solids: int = plan.barriers.size() + plan.buildings.size() + 4
	for prop in plan.props:
		if prop.get("solid", true):
			expected_solids += 1
	check("river has physical banks and an open bridge", plan.barriers.size() == 113 and lane.solid_rects.size() == expected_solids)
	check("building Y sorting retained", lane.actors.y_sort_enabled and lane.player.get_parent() == lane.actors)
	check("stone plaza footsteps", loop.footstep_surfaces.resolve("town", Vector2(620, 470), "clear") == "stone")
	check("wood landing footsteps", loop.footstep_surfaces.resolve("town", Vector2(1190, 652), "clear") == "wood")
	check("forest lane dirt footsteps", loop.footstep_surfaces.resolve("town", Vector2(408, 250), "clear") == "dirt")
	check("snow covers exterior surfaces", loop.footstep_surfaces.resolve("town", Vector2(620, 470), "snow") == "snow")
	check("old saved position in moved building resets safely", loop._safe_town_position(Vector2(620, 330)) == lane.SPAWN)
	check("valid saved doorway is retained", loop._safe_town_position(loop.STORE_GATE) == loop.STORE_GATE)
	await shot("west_arrival")
	check("walk to public square", await Navigation.walk(lane, Vector2(620, 510)))
	for running in [false, true]:
		lane.test_running = running
		for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var start := Vector2(620, 510)
			var end: Vector2 = await lane._walk(start, direction, 12)
			var expected: Vector2 = start + direction.normalized() * (140.0 if running else 90.0) * 0.2
			check("diagonal %s %s keeps speed" % ["run" if running else "walk", direction], end.distance_to(expected) < 2.5)
	lane.test_running = true
	lane.player.position = Vector2(620, 510)
	await shot("moonwell_square")
	var keys := ["store", "blacksmith", "dock", "restaurant", "farm", "field"]
	for kind in keys:
		var gate := Vector2(plan.gates[kind][0], plan.gates[kind][1])
		var before: Vector2 = gate + (Vector2(-34, 0) if kind == "dock" else Vector2(34, 0) if kind == "farm" else Vector2(0, 34))
		check("real route to approach " + kind, await Navigation.walk(lane, before))
		await shot(kind + "_door")
		check("real route to " + kind, await Navigation.walk(lane, gate))
		if kind in ["restaurant", "blacksmith", "store"]:
			check("walking to door stays outside " + kind, loop.location == "town")
			await key(KEY_E)
		check("entrance reaches " + kind, loop.location == kind)
		if loop.location != kind:
			continue
		check("town physics detaches in " + kind, not lane.world.is_inside_tree())
		if kind in ["home", "blacksmith", "store"]:
			check("indoor weather hidden in " + kind, not lane.weather.visible)
		check("walk to " + kind + " exit", await Navigation.walk(lane, loop.area.stations.exit))
		if kind in ["restaurant", "blacksmith", "store"]:
			check("walking to exit stays inside " + kind, loop.location == kind)
			await key(KEY_E)
		check("exit returns from " + kind, loop.location == "town")
		check("restores moved doorway " + kind, lane.player.position.distance_to(before) < 0.1)
		check("town bounds restored " + kind, lane.camera.limit_right == 1280 and lane.camera.limit_bottom == 960)
	for building in plan.buildings:
		check("walk to every house " + building.role, await Navigation.walk(lane, Vector2(building.x, building.y + 60)))
	check("walk onto river landing", await Navigation.walk(lane, Vector2(1190, 652)))
	await shot("riverside_landing")
	var end: Vector2 = await lane._walk(Vector2(1144, 730), Vector2.RIGHT, 70)
	check("river bank blocks entering water", end.x > 1150 and end.x < 1180)
	lane.player.position = Vector2(620, 510)
	lane.camera.force_update_scroll()
	lane.weather.set_weather("rain")
	await shot("square_rain")
	check("rain still works", lane.weather.get_weather() == "rain" and lane.weather.visible)
	lane.weather.set_weather("snow")
	await shot("square_snow")
	check("snow still works", lane.weather.get_weather() == "snow")
	lane.weather.clear_weather()
	await key(KEY_R)
	check("R remains safe town arrival", lane.player.position == lane.SPAWN)
	lane.queue_free()
	await frames()
	print("TOWN PLAN VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
