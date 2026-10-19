extends SceneTree

const OUT := "res://Scenes/Gameplay/Verification/Harvest/"
var lane
var loop
var harvest
var failures := 0
var capture := false
var capture_output := OUT

func _initialize() -> void:
	capture = "--harvest-capture" in OS.get_cmdline_user_args()
	if "--wand-capture" in OS.get_cmdline_user_args(): capture_output = "res://output/wand/harvest/"
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("HARVEST TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func cast() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = root.get_visible_rect().size / 2.0
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func walk_to(target: Vector2) -> void:
	var arrived: bool = await preload("res://Scenes/LanternLane/verification_navigation.gd").walk(lane, target)
	check("real walk to " + str(target), arrived)

func resource(id: String):
	for node in loop.area.resource_nodes:
		if node.resource_id == id:
			return node
	return null

func shot(title: String) -> void:
	if not capture:
		return
	await frames()
	RenderingServer.force_draw(false)
	var image: Image = lane.viewport.get_texture().get_image()
	check("capture " + title, image.save_png(capture_output + title + ".png") == OK)
	check("window " + title, root.get_texture().get_image().save_png(capture_output + title + "_window.png") == OK)
	var colors := {}
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			colors[image.get_pixel(x, y)] = true
	check("nonblank " + title, colors.size() > 40)
	if harvest.actor.visible:
		var index: int = harvest.actor.frame
		var cell := Vector2i(lane.CHARACTER_SIZE)
		var columns: int = harvest.actor.hframes
		var source: Image = harvest.actor.texture.get_image().get_region(Rect2i(Vector2i(index % columns * cell.x, index / columns * cell.y), cell))
		var corner: Vector2i = Vector2i((harvest.actor.get_global_transform_with_canvas() * (-lane.CHARACTER_SIZE / 2)).round())
		var opaque := 0
		var matching := 0
		for y in range(cell.y):
			for x in range(cell.x):
				var color := source.get_pixel(x, y)
				if color.a == 1.0:
					opaque += 1
					if image.get_pixel(corner.x + x, corner.y + y) == color:
						matching += 1
		check("action pixels visible " + title, matching > opaque * 0.85)

func wait_action(expected: String, seconds: float = 6.0) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while harvest.action != expected and Time.get_ticks_msec() < deadline:
		await process_frame
	check("reached action " + expected, harvest.action == expected)

func swing(node, name: String) -> void:
	var before: int = loop.state.resource_left(node.resource_id)
	await cast()
	check(name + " starts via left mouse", harvest.busy())
	var start: Vector2 = lane.player.position
	lane.test_direction = Vector2.LEFT
	await create_timer(0.12).timeout
	lane.test_direction = Vector2.ZERO
	check(name + " swing locks movement", lane.player.position.distance_to(start) < 0.01)
	await cast()
	check(name + " repeated mouse press does not restart", harvest.elapsed > 0.1)
	if capture:
		harvest.paused_for_test = true
		harvest.elapsed = 0.38
		harvest.update_pose()
		await shot(name)
		harvest.paused_for_test = false
	await wait_action("", 2.0)
	check(name + " one hit only", loop.state.resource_left(node.resource_id) == before - 1)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_output))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.state.wand_mode = "red"
	loop.enter("town")
	# Neutral noon light keeps the sprite pixel comparison independent of dawn tint.
	loop.state.remaining = loop.state.DAY_SECONDS * 0.5
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	harvest = loop.harvest
	await walk_to(loop.FIELD_GATE)
	check("enter field", loop.location == "field")
	check("resource count", loop.area.resource_nodes.size() == 9)
	check("native action sheet", harvest.actor.texture.get_size() == lane.CHARACTER_SIZE * Vector2(8, 19) and harvest.actor.get_rect().size == lane.CHARACTER_SIZE)
	check("tool foot anchor", harvest.actor.position == lane.WITCH_FOOT_OFFSET)
	await shot("field_resources")
	await walk_to(Vector2(60, 256))
	await walk_to(Vector2(423, 256))
	var tree = resource("field_tree_7")
	await walk_to(tree.anchor)
	loop.state.tools.wand = 0
	await cast()
	check("missing wand blocks chopping before animation", not harvest.busy() and loop.state.resource_left(tree.resource_id) == 3 and loop.state.resources.wood == 0)
	check("missing wand blocks direct resource mutation", loop.state.strike_resource(tree.resource_id, "wood") == -1 and loop.state.resource_left(tree.resource_id) == 3)
	loop.state.tools.wand = 1
	await swing(tree, "chop")
	check("partial tree gives no wood", loop.state.resources.wood == 0)
	loop.enter("town")
	loop.enter("field")
	await frames()
	tree = resource("field_tree_7")
	check("partial tree persists across areas", loop.state.resource_left(tree.resource_id) == 2)
	await walk_to(Vector2(60, 256))
	await walk_to(Vector2(423, 256))
	await walk_to(tree.anchor)
	await swing(tree, "chop_second")
	await swing(tree, "chop_finish")
	check("tree rewards three wood", loop.state.resources.wood == 3)
	check("chopping keeps starter tools", loop.state.tools == loop.state.STARTING_TOOLS)
	check("tree changes to stump", not tree.available() and tree.sprite.texture == tree.depleted)
	await shot("stump")
	await cast()
	check("stump cannot give duplicate reward", not harvest.busy() and loop.state.resources.wood == 3)
	var ore = resource("field_ore_0")
	await walk_to(ore.anchor)
	loop.state.tools.wand = 0
	await cast()
	check("missing wand blocks mining before animation", not harvest.busy() and loop.state.resource_left(ore.resource_id) == 3 and loop.state.resources.ore == 0)
	loop.state.tools.wand = 1
	for i in range(3):
		await swing(ore, "mine_" + str(i))
	check("ore rewards two minerals", loop.state.resources.ore == 2)
	check("mining keeps starter tools", loop.state.tools == loop.state.STARTING_TOOLS)
	check("ore changes to rubble", not ore.available() and ore.sprite.texture == ore.depleted)
	await cast()
	check("rubble cannot give duplicate reward", not harvest.busy() and loop.state.resources.ore == 2)
	var pond = resource("field_pond")
	await walk_to(Vector2(350, 256))
	await walk_to(pond.anchor)
	await cast()
	await wait_action("wait")
	await cast()
	check("early reel fails without reward", not harvest.busy() and loop.state.resources.fish == 0)
	await cast()
	await wait_action("wait")
	await shot("fishing_wait")
	await wait_action("bite")
	if capture:
		harvest.paused_for_test = true
		await shot("fishing_bite")
	await cast()
	check("bite mouse press begins reel", harvest.action == "reel")
	if capture:
		harvest.elapsed = 0.25
		harvest.update_pose()
		await shot("fishing_reel")
		harvest.paused_for_test = false
	await wait_action("")
	check("successful reel rewards one fish", loop.state.resources.fish == 1 and loop.state.fish_left(pond.resource_id) == 2)
	check("collected resources appear in UI", loop.inventory.text.contains("木材3") and loop.inventory.text.contains("矿石2") and loop.inventory.text.contains("鱼1"))
	await shot("resources_collected")
	await cast()
	await wait_action("bite")
	await wait_action("")
	check("missed bite gives no fish", loop.state.resources.fish == 1 and loop.state.fish_left(pond.resource_id) == 2)
	await cast()
	await key(KEY_ESCAPE)
	check("Escape cancels", not harvest.busy() and lane.avatar.visible)
	await cast()
	lane.test_direction = Vector2.LEFT
	await physics_frame
	await physics_frame
	lane.test_direction = Vector2.ZERO
	check("movement cancels fishing", not harvest.busy() and lane.avatar.visible)
	await walk_to(pond.anchor)
	await cast()
	await key(KEY_R)
	check("reset cancels action", not harvest.busy() and lane.player.position.distance_to(loop.area.spawn) < 1)
	# Isolate day/scene boundaries before the first tool impact.
	var ore2 = resource("field_ore_1")
	lane.player.position = ore2.anchor
	await cast()
	loop.enter("town")
	await create_timer(0.8).timeout
	check("scene switch cancels pending hit", loop.state.resource_left("field_ore_1") == 3 and loop.state.resources.ore == 2)
	loop.enter("field")
	await frames()
	ore2 = resource("field_ore_1")
	lane.player.position = ore2.anchor
	await cast()
	loop.state.remaining = 0.01
	loop.paused_for_test = false
	await create_timer(0.65).timeout
	check("day end cancels action and moves to restaurant preparation", not harvest.busy() and loop.location == "restaurant" and loop.state.phase == "day" and loop.state.remaining <= 0.0)
	check("day end gives no pending reward", loop.state.resource_left("field_ore_1") == 3 and loop.state.resources.ore == 2)
	loop.paused_for_test = true
	# Sunset now waits for a menu and explicit opening before the night phase.
	check("select opening menu", loop.state.set_menu_dish(0, true))
	loop.end_phase()
	check("confirmed opening starts service", loop.state.phase == "night")
	var carried_resources: Dictionary = loop.state.resources.duplicate()
	loop.end_phase()
	loop.end_phase()
	await create_timer(0.65).timeout
	check("resources carry into next day", loop.state.day == 2 and loop.state.resources == carried_resources)
	check("nodes and fish refresh next day", loop.state.resource_left("field_tree_7") == 3 and loop.state.fish_left("field_pond") == 3)
	loop.enter("field")
	await frames()
	tree = resource("field_tree_7")
	check("refreshed tree art", tree.available() and tree.ambient.enabled and tree.ambient.original == tree.original)
	# Catch stock is finite and cannot be consumed outside daytime.
	var state = preload("res://Scenes/Gameplay/loop_state.gd").new()
	for i in range(3):
		check("fish stock catch " + str(i), state.catch_fish("pond"))
	check("exhausted pond rejects duplicate fish", not state.catch_fish("pond") and state.resources.fish == 3)
	state.phase = "night"
	check("night rejects harvest", state.strike_resource("tree", "wood") == -1 and not state.catch_fish("other_pond"))
	check("invalid kind rejected", state.strike_resource("tree", "unknown") == -1)
	check("new sounds triggered", loop.audio.counts.get("chop", 0) == 3 and loop.audio.counts.get("mine", 0) == 3 and loop.audio.counts.get("bite", 0) >= 2 and loop.audio.counts.get("catch", 0) == 1)
	state = null
	# Release active streams before headless shutdown, as in the dock verifier.
	loop.audio.set_process(false)
	if is_instance_valid(loop.audio.fade):
		loop.audio.fade.kill()
	for player in loop.audio.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await create_timer(0.1).timeout
	lane.queue_free()
	await frames()
	harvest = null
	loop = null
	lane = null
	await create_timer(0.2).timeout
	print("HARVEST VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
