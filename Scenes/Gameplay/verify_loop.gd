extends SceneTree
var lane
var loop
var failures = 0
var render = false
const OUT = "res://Scenes/Gameplay/Verification/"

func _initialize() -> void:
	render = "--loop-render" in OS.get_cmdline_user_args()
	if "--customer-eat-test" in OS.get_cmdline_user_args():
		render = true
	_run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("LOOP TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func key(code: int) -> void:
	var e = InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	e = InputEventKey.new()
	e.physical_keycode = code
	e.pressed = false
	Input.parse_input_event(e)
	await frames(2)

func click(button: Button) -> void:
	loop._refresh()
	# Input delivered inside the real SubViewport (same hit testing as a mouse).
	var motion = InputEventMouseMotion.new()
	motion.position = lane.viewport.get_parent().position + (button.position + button.size * 0.5) * lane.viewport.get_parent().scale
	root.push_input(motion, true)
	await frames(2)
	var e = InputEventMouseButton.new()
	e.position = lane.viewport.get_parent().position + (button.position + button.size * 0.5) * lane.viewport.get_parent().scale
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	root.push_input(e, true)
	await frames(2)
	e = InputEventMouseButton.new()
	e.position = lane.viewport.get_parent().position + (button.position + button.size * 0.5) * lane.viewport.get_parent().scale
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	root.push_input(e, true)
	await frames(2)

func walk_to(target: Vector2) -> void:
	var count = 0
	while lane.player.position.distance_to(target) > 2.0 and count < 700:
		var diff = target - lane.player.position
		lane.test_direction = Vector2(signf(diff.x), 0) if absf(diff.x) > 1.5 else Vector2(0, signf(diff.y))
		await physics_frame
		count += 1
	lane.test_direction = Vector2.ZERO
	await physics_frame
	check("real walk to " + str(target), lane.player.position.distance_to(target) < 3.0)

func shot(title: String) -> void:
	if not render:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_move_to_foreground()
	await frames(3)
	RenderingServer.force_draw(false)
	check("viewport screenshot " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)
	check("window screenshot " + title, root.get_texture().get_image().save_png(OUT + title + "_window.png") == OK)

func _customer_eat_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.enter("restaurant")
	await frames(5)
	loop.paused_for_test = true
	loop.state.phase = "night"
	loop.state.materials = [0, 0, 0]
	loop.state.menu = [true, true, true]
	loop.state.customers = [
		{"seat": 0, "dish": 0, "patience": 25.0, "variant": 0, "status": "waiting", "eating_left": 0.0},
		{"seat": 1, "dish": 0, "patience": 25.0, "variant": 1, "status": "waiting", "eating_left": 0.0},
		{"seat": 2, "dish": 0, "patience": 25.0, "variant": 2, "status": "waiting", "eating_left": 0.0}
	]
	await shot("customers_idle_012")
	check("variants 0-2 visible", loop.state.customers.size() == 3)
	loop.state.customers[0].variant = 3
	loop.state.customers[1].variant = 4
	loop.state.customers[2].variant = 5
	await frames(2)
	await shot("customers_idle_345")
	check("variants 3-5 visible", loop.state.customers[0].variant == 3 and loop.state.customers[2].variant == 5)
	loop.state.held = 0
	check("serve starts eating", loop.state.serve(0) and loop.state.customers[0].status == "eating" and loop.state.income == 12 and loop.state.served == 1)
	await frames(2)
	await shot("customer_eating_start")
	loop.state.tick(0.9)
	check("eating frame advances", loop.state.customers[0].status == "eating" and loop.state.customers[0].eating_left < 3.0)
	await frames(2)
	await shot("customer_eating_mid")
	check("eating blocks second serve", not loop.state.serve(0) and loop.state.income == 12 and loop.state.served == 1)
	loop.state.tick(2.2)
	check("three seconds removes customer", loop.state.customer_at(0) == null and loop.state.customers.size() == 2 and loop.state.income == 12 and loop.state.served == 1)
	check("income remains once after eating", loop.state.income == 12 and not loop.state.serve(0))
	print("CUSTOMER EAT VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)

func _run() -> void:
	if "--customer-eat-test" in OS.get_cmdline_user_args():
		await _customer_eat_test()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	check("Chinese system font available", loop.font.get_string_size("小女巫餐厅", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > 0)
	await shot("town")
	for day in range(1, 3):
		check("day " + str(day), loop.state.day == day and loop.state.phase == "day")
		await walk_to(loop.FIELD_GATE)
		await key(KEY_E)
		check("E enters independent field", loop.location == "field" and not lane.world.is_inside_tree())
		await walk_to(Vector2(60,115))
		await walk_to(loop.area.points[0])
		await key(KEY_E)
		await key(KEY_E)
		await key(KEY_E)
		check("gather and exhausted point", loop.state.raw[0] == 2 and loop.state.nodes[0] == 0)
		await shot("field_day" + str(day))
		await walk_to(Vector2(60,115))
		await walk_to(loop.area.stations.exit)
		await key(KEY_E)
		check("field exit restores town", loop.location == "town" and lane.player.get_parent() == lane.actors)
		await walk_to(Vector2(448,334))
		await walk_to(loop.REST_GATE)
		await key(KEY_E)
		check("E restaurant entrance", loop.location == "restaurant")
		await walk_to(Vector2(60,130))
		await walk_to(loop.area.stations.prep)
		await key(KEY_E)
		check("processing separates inventories", loop.state.raw == [0,0,0] and loop.state.materials == [2,0,0])
		await key(KEY_E)
		check("processing cannot duplicate", loop.state.materials == [2,0,0])
		if day == 1:
			await click(loop.menu_buttons[1])
			await click(loop.menu_buttons[2])
		check("mouse menu selection", loop.state.menu == [true,false,false])
		await shot("prep_day" + str(day))
		await click(loop.end_button)
		check("manual day end", loop.state.phase == "night" and loop.location == "restaurant")
		await frames(5)
		check("customer orders from menu", loop.state.customers.size() == 1 and loop.state.customers[0].dish == 0)
		var before = loop.state.materials.duplicate()
		loop.cook_dish(0)
		check("remote cook rejected", loop.state.materials == before and loop.state.cooking == -1)
		await walk_to(Vector2(270,130))
		await click(loop.cook_buttons[0])
		check("cook subtracts once", loop.state.materials == [0,0,0] and loop.state.cooking == 0)
		loop.cook_dish(0)
		check("repeat cook rejected", loop.state.materials == [0,0,0])
		await shot("cooking_day" + str(day))
		await create_timer(3.2).timeout
		check("real cooking timer yields held dish", loop.state.held == 0 and loop.state.cooking == -1)
		await walk_to(Vector2(60,130))
		await walk_to(Vector2(60,225))
		await walk_to(loop.area.seats[0])
		await shot("serving_day" + str(day))
		await key(KEY_E)
		check("E served and earned", loop.state.held == -1 and loop.state.served == 1 and loop.state.income == 12)
		check("out of stock stops arrivals", not loop.state.admit() and not loop.state.start_cook(0))
		await click(loop.end_button)
		check("settlement credits once", loop.state.phase == "result" and loop.state.coins == day * 12)
		loop.state.end_phase()
		check("no duplicate income", loop.state.coins == day * 12)
		await shot("result_day" + str(day))
		await click(loop.end_button)
		check("next day refresh and balances", loop.state.day == day+1 and loop.state.nodes == [2,2,2,2,2,2,2,2,2] and loop.state.materials == [0,0,0])
		# Return next-day town spawn to gate via actual walking.
		await walk_to(Vector2(408,384))
	await shot("day3_refresh")
	# Focused boundary checks on the same state/controller after two full days.
	loop.paused_for_test = true
	var s = loop.state
	var recipe_state = preload("res://Scenes/Gameplay/loop_state.gd").new()
	for dish in range(3):
		recipe_state.phase = "night"
		recipe_state.materials = [4,4,4]
		recipe_state.held = -1
		recipe_state.cooking = -1
		recipe_state.customers = [{"seat": 0, "dish": dish, "patience": 25.0}]
		check("recipe " + str(dish) + " starts", recipe_state.start_cook(dish))
		var expected = [4,4,4]
		for ingredient in range(3):
			expected[ingredient] -= recipe_state.COSTS[dish][ingredient]
		check("recipe " + str(dish) + " exact inventory", recipe_state.materials == expected)
		recipe_state.tick(3.1)
		check("recipe " + str(dish) + " serve price", recipe_state.serve(0) and recipe_state.income == [12,26,44][dish])
	recipe_state.menu = [false,false,false]
	check("empty menu no arrivals", not recipe_state.admit())
	s.raw = [4,4,4]
	check("full backpack non-consuming", not s.gather(0) and s.nodes[0] == 2)
	s.raw = [0,0,0]
	s.materials = [6,2,1]
	s.menu = [true,true,true]
	s.remaining = 0.01
	s.tick(0.02)
	loop._sync_phase()
	check("automatic day conversion", s.phase == "night" and loop.location == "restaurant")
	s.admit()
	s.admit()
	s.admit()
	check("three seats and full rejection", s.customers.size() == 3 and not s.admit())
	s.held = (s.customers[0].dish + 1) % 3
	var held = s.held
	check("wrong order preserved", not s.serve(0) and s.held == held and s.income == 0)
	s.discard()
	check("discard frees hand", s.held == -1 and s.wasted == 1)
	await shot("full_orders")
	s.arrivals = 100
	s.tick(25.1)
	check("patience timeout clears seats", s.customers.is_empty() and s.lost == 3)
	s.start_cook(0)
	var inventory = s.materials.duplicate()
	s.raw = [1,0,0]
	s.remaining = 0.01
	s.tick(0.02)
	loop._sync_phase()
	check("night automatic end cancels cooking", s.phase == "result" and s.cooking == -1 and s.held == -1 and s.wasted == 2)
	await shot("timeout_result")
	loop.end_phase()
	check("carryover stock and refresh", s.materials == inventory and s.raw == [1,0,0] and s.nodes[0] == 2)
	s.raw = [0,0,0]
	s.materials = [0,0,0]
	loop.end_phase()
	check("zero ingredient night no deadlock", s.phase == "night" and not s.admit())
	loop.end_phase()
	loop.end_phase()
	check("zero ingredient can reach next day", s.phase == "day" and s.day == 5)
	# Weather and movement still work after returning from interiors.
	await key(KEY_2)
	check("rain input after transition", lane.weather.get_weather() == "rain")
	var pos: Vector2 = await lane._walk(Vector2(224,340),Vector2.UP,60)
	check("town collision after transition", pos.y >= 293.9 and pos.y < 296)
	await key(KEY_3)
	check("snow input after transition", lane.weather.get_weather() == "snow")
	await key(KEY_1)
	await key(KEY_R)
	check("town R preserved", lane.player.position == lane.SPAWN)
	loop.enter("restaurant")
	await key(KEY_R)
	check("interior R safe spawn", lane.player.position == Vector2(60,280))
	await key(KEY_F3)
	check("F3 preserved", lane.world.get_node_or_null("CollisionOverlay") != null)
	print("LOOP VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
