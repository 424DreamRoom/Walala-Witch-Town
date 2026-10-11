extends SceneTree

const OUT := "res://Scenes/Dock/Verification/"
var lane
var loop
var harvest
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--dock-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("DOCK TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

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

func wait_action(expected: String, seconds: float = 6.0) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while harvest.action != expected and Time.get_ticks_msec() < deadline:
		await process_frame
	check("action " + expected, harvest.action == expected)

func shot(title: String) -> void:
	if not capture:
		return
	await frames()
	RenderingServer.force_draw(false)
	var image: Image = lane.viewport.get_texture().get_image()
	check("capture " + title, image.save_png(OUT + title + ".png") == OK)
	check("window " + title, root.get_texture().get_image().save_png(OUT + title + "_window.png") == OK)
	var colors := {}
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			colors[image.get_pixel(x, y)] = true
	check("nonblank " + title, colors.size() > 40)

func catch_once(short_wait: bool = true) -> void:
	var before: int = loop.state.resources.fish
	await key(KEY_E)
	check("E casts", harvest.action == "cast")
	if short_wait:
		harvest.wait_seconds = 0.12
	await wait_action("bite")
	await key(KEY_E)
	check("bite E reels", harvest.action == "reel")
	await key(KEY_E)
	await wait_action("")
	check("reel grants exactly one fish", loop.state.resources.fish == before + 1)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.automation = true
	loop = lane.get_node_or_null("GameLoop")
	if loop == null or loop.harvest == null:
		check("gameplay controller initialized", false)
		quit(1)
		return
	loop.paused_for_test = true
	loop.enter("town")
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	harvest = loop.harvest
	# Follow the main streets when the town layout places the dock in the southeast.
	await walk_to(loop.DOCK_GATE + Vector2(-24, 0))
	var gate_entry: Vector2 = loop.DOCK_GATE + Vector2(-34, 0)
	check("dock gate prompt", loop.gate_labels[3].visible)
	await shot("town_gate")
	await walk_to(loop.DOCK_GATE)
	check("walking enters dock", loop.location == "dock")
	if loop.location != "dock":
		quit(1)
		return
	check("town collision world detached", not lane.world.is_inside_tree())
	check("dock camera bounds", lane.camera.limit_right == 640 and lane.camera.limit_bottom == 360)
	check("three fishing spots", loop.area.resource_nodes.size() == 3)
	check("dock UI and weather", loop.header.text.contains("潮汐码头") and loop.hud.slot_counts[0].get_parent().visible and lane.weather.visible and not loop.sidebar_title.visible)
	await shot("arrival")
	await walk_to(Vector2(64, 236))
	await walk_to(Vector2(250, 236))
	lane.test_direction = Vector2.UP
	await create_timer(0.6).timeout
	lane.test_direction = Vector2.ZERO
	check("bridge edge blocks water", lane.player.position.y >= 209.9 and lane.player.position.y < 215)
	await walk_to(Vector2(250, 236))
	await walk_to(Vector2(388, 236))
	await shot("pier")
	await walk_to(resource("dock_north").anchor)
	await key(KEY_E)
	await wait_action("wait")
	check("cast waits 2 to 4 seconds", harvest.wait_seconds >= 2.0 and harvest.wait_seconds <= 4.0)
	harvest.paused_for_test = true
	await shot("fishing_wait")
	harvest.paused_for_test = false
	await key(KEY_E)
	check("early reel gives no fish", not harvest.busy() and loop.state.resources.fish == 0 and loop.state.fish_left("dock_north") == 3)
	await key(KEY_E)
	await wait_action("bite")
	check("new cast clears stale failure feedback", loop.state.message.is_empty() and not loop.notice.visible)
	harvest.paused_for_test = true
	await shot("fishing_bite")
	await key(KEY_E)
	check("bite E begins reel", harvest.action == "reel")
	harvest.elapsed = 0.25
	harvest.update_pose()
	await shot("fishing_reel")
	harvest.paused_for_test = false
	await key(KEY_E)
	await wait_action("")
	check("first catch and UI", loop.state.resources.fish == 1 and loop.inventory.text.contains("鱼1"))
	await key(KEY_E)
	harvest.wait_seconds = 0.12
	await wait_action("bite")
	await wait_action("")
	check("missed bite does not consume stock", loop.state.fish_left("dock_north") == 2 and loop.state.resources.fish == 1)
	await key(KEY_E)
	await key(KEY_ESCAPE)
	check("Escape cancels at dock", not harvest.busy() and lane.avatar.visible)
	await key(KEY_E)
	lane.test_direction = Vector2.DOWN
	await physics_frame
	await physics_frame
	lane.test_direction = Vector2.ZERO
	check("walking cancels at dock", not harvest.busy() and lane.avatar.visible)
	await walk_to(resource("dock_north").anchor)
	await catch_once()
	await catch_once()
	check("north stock exhausted independently", loop.state.fish_left("dock_north") == 0 and loop.state.fish_left("dock_east") == 3 and loop.state.fish_left("field_pond") == 3)
	await key(KEY_E)
	check("exhausted dock spot gives no duplicate", not harvest.busy() and loop.state.resources.fish == 3)
	await shot("spot_depleted")
	await walk_to(Vector2(388, 220))
	await walk_to(resource("dock_east").anchor)
	await catch_once()
	check("eastward fishing uses correct water position", loop.state.fish_left("dock_east") == 2)
	await walk_to(Vector2(492, 252))
	lane.test_direction = Vector2.RIGHT
	await create_timer(0.6).timeout
	lane.test_direction = Vector2.ZERO
	check("east pier edge blocks water", lane.player.position.x <= 519.1 and lane.player.position.x > 514)
	await walk_to(Vector2(440, 252))
	await walk_to(resource("dock_south").anchor)
	await catch_once()
	check("south fishing works", loop.state.fish_left("dock_south") == 2 and loop.state.resources.fish == 5)
	await shot("fish_collected")
	await walk_to(Vector2(388, 236))
	await walk_to(Vector2(64, 236))
	await walk_to(loop.area.stations.exit)
	check("walking returns to town gate", loop.location == "town" and lane.player.position.distance_to(gate_entry) < 3.0 and lane.world.is_inside_tree())
	await walk_to(loop.DOCK_GATE)
	check("fish and depleted stock survive reentry", loop.location == "dock" and loop.state.resources.fish == 5 and not resource("dock_north").available())
	# Boundary cases isolate scene reset and timer cancellation after the walking route.
	lane.player.position = resource("dock_east").anchor
	await key(KEY_E)
	await key(KEY_R)
	check("R cancels and resets to dock spawn", not harvest.busy() and lane.player.position.distance_to(loop.area.spawn) < 1.0)
	lane.player.position = resource("dock_east").anchor
	await key(KEY_E)
	loop.enter("town")
	await create_timer(0.7).timeout
	check("leaving dock cancels pending rewards", not harvest.busy() and loop.state.resources.fish == 5)
	loop.enter("dock")
	lane.player.position = resource("dock_east").anchor
	await key(KEY_E)
	harvest.wait_seconds = 0.12
	await wait_action("bite")
	await key(KEY_E)
	loop.state.remaining = 0.01
	loop.paused_for_test = false
	await create_timer(0.15).timeout
	loop.paused_for_test = true
	check("day timer cancels reel and returns for preparation", not harvest.busy() and loop.location == "restaurant" and loop.state.phase == "day" and loop.state.remaining == 0.0 and loop.state.resources.fish == 5)
	loop.state.set_menu_dish(0, true)
	loop.end_phase()
	loop.enter("town")
	await walk_to(loop.DOCK_GATE)
	check("night gate closed with feedback", loop.location == "town" and loop.state.message == "夜间关闭")
	loop.enter("dock")
	check("direct night entry also rejected", loop.location == "town")
	loop.end_phase()
	loop.end_phase()
	await walk_to(loop.DOCK_GATE + Vector2(-34, 0))
	await walk_to(loop.DOCK_GATE)
	check("next day opens dock and keeps fish", loop.state.day == 2 and loop.location == "dock" and loop.state.resources.fish == 5)
	check("all dock spots refresh next day", resource("dock_north").available() and loop.state.fish_left("dock_north") == 3 and loop.state.fish_left("dock_east") == 3 and loop.state.fish_left("dock_south") == 3)
	await key(KEY_2)
	check("rain works at dock", lane.weather.visible and lane.weather.get_weather() == "rain")
	await shot("rain")
	await key(KEY_3)
	check("snow works at dock", lane.weather.get_weather() == "snow")
	await key(KEY_1)
	check("clear works at dock", lane.weather.get_weather() == "clear")
	check("fishing sounds triggered", loop.audio.counts.get("cast", 0) >= 5 and loop.audio.counts.get("catch", 0) == 5)
	# Headless frames can finish before the audio thread releases active streams.
	loop.audio.set_process(false)
	if is_instance_valid(loop.audio.fade):
		loop.audio.fade.kill()
	for player in loop.audio.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await create_timer(0.1).timeout
	lane.queue_free()
	await frames()
	print("DOCK VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
