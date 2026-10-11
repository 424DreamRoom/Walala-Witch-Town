extends SceneTree

const OUT := "res://Art/Environment/Hearthwood/Verification/"
var lane
var loop
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--home-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("HOME TEST ", title, ": ", "PASS" if ok else "FAIL")
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
		await frames()

func walk_to(target: Vector2) -> void:
	var arrived: bool = await preload("res://Scenes/LanternLane/verification_navigation.gd").walk(lane, target)
	check("real walk to " + str(target), arrived)

func shot(title: String) -> void:
	if not capture:
		return
	await frames()
	RenderingServer.force_draw(false)
	var image: Image = lane.viewport.get_texture().get_image()
	check("nonblank " + title, image.get_pixel(320, 180) != Color(0, 0, 0, 1))
	check("capture " + title, image.save_png(OUT + title + ".png") == OK)
	check("capture window " + title, root.get_texture().get_image().save_png(OUT + title + "_window.png") == OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	# Retain the authored-home movement regression for migrated saves.
	loop.state.furniture = preload("res://Scenes/Building/furniture_catalog.gd").legacy_data()
	loop.enter("town")
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	check("new town textures", lane.ART == "res://Art/Environment/Hearthwood/")
	check("character detailed native grid", lane.avatar.texture.get_size() == lane.CHARACTER_SIZE * Vector2(5, 4) and lane.avatar.hframes == 5 and lane.avatar.vframes == 4)
	check("character displayed at 32x32", lane.avatar.get_rect().size * lane.avatar.scale == lane.CHARACTER_SIZE)
	check("character feet grounded", lane.avatar.position.y + lane.avatar.get_rect().end.y * lane.avatar.scale.y == 0)
	check("town Y sorting", lane.actors.y_sort_enabled)
	check("keyboard help removed", lane.viewport.get_node_or_null("TownHints") == null)
	check("town panels removed", not loop.inventory.visible and not loop.menu_buttons[0].visible and not loop.cook_buttons[0].visible and not loop.backgrounds[1].visible)
	check("town HUD compact", loop.backgrounds[0].size.y == 26 and not loop.notice.visible and not loop.backgrounds[2].visible)
	check("distant house label hidden", not loop.gate_labels[2].visible)
	await shot("town_spawn")
	await walk_to(loop.FARM_GATE + Vector2(34, 0))
	check("nearby farm label visible", loop.gate_labels[2].visible)
	await walk_to(loop.FARM_GATE)
	check("farm contains relocated house", loop.location == "farm")
	await walk_to(loop.area.stations.home + Vector2(0, 20))
	await shot("home_exterior")
	lane.weather.set_weather("rain")
	await frames()
	check("outdoor rain", loop.audio.current_ambient == "rain")
	var return_position: Vector2 = loop.HOME_EXIT_POSITION
	await walk_to(loop.area.stations.home)
	check("walking to house door stays on farm", loop.location == "farm")
	await key(KEY_E)
	check("interacting enters home", loop.location == "home")
	if loop.location != "home":
		quit(1)
		return
	check("town collisions detached", not lane.world.is_inside_tree())
	check("home Y sorting", loop.area.y_sort_enabled and lane.player.get_parent() == loop.area)
	check("home world bounds", lane.camera.limit_right == 640 and lane.camera.limit_bottom == 480)
	check("home walls and furniture collide", loop.area.solids.size() == 19)
	check("home weather hidden", not lane.weather.visible)
	check("home rain audio stops", not loop.audio.ambient.playing)
	check("home sidebar hidden", not loop.sidebar_title.visible and not loop.menu_buttons[0].visible and not loop.inventory.visible)
	check("home header fits", loop.header.get_theme_font("font").get_string_size(loop.header.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x < 455)
	await shot("home_south")
	await walk_to(Vector2(218, 405))
	await walk_to(Vector2(218, 223))
	await walk_to(Vector2(354, 223))
	await walk_to(Vector2(354, 176))
	lane.camera.force_update_scroll()
	check("north camera clamp", lane.camera.get_screen_center_position().y == 180)
	await shot("home_north")
	var end: Vector2 = await lane._walk(Vector2(141, 380), Vector2.UP, 80)
	check("bed blocks movement", end.y >= 335.8 and end.y < 338)
	await key(KEY_R)
	check("home R safe spawn", lane.player.position == loop.area.spawn)
	await walk_to(loop.area.stations.exit)
	check("walking to exit stays home", loop.location == "home")
	await key(KEY_E)
	check("interacting exits home to farm", loop.location == "farm" and lane.player.get_parent() == loop.area)
	check("farm doorway restored", lane.player.position.distance_to(return_position) < 0.1)
	check("farm camera restored", lane.camera.limit_right == 960 and lane.camera.limit_bottom == 720)
	check("farm stays uncluttered on return", not loop.sidebar_title.visible and not loop.inventory.visible and not loop.menu_buttons[0].visible)
	check("outdoor weather restores", lane.weather.visible and lane.weather.get_weather() == "rain" and loop.audio.current_ambient == "rain")
	lane.weather.clear_weather()
	loop.enter("home")
	loop.state.remaining = 0.01
	loop.state.tick(0.02)
	loop._sync_phase()
	await frames()
	check("sunset preparation from home", loop.location == "restaurant" and loop.state.phase == "day" and loop.state.remaining == 0.0)
	for dish in range(3): loop.state.set_menu_dish(dish, true)
	loop.end_phase()
	await frames()
	check("restaurant background", loop.area.background.resource_path.ends_with("restaurant_background.png"))
	check("all customer sheets loaded", loop.area.customer_sheets.size() == 6)
	for sheet in loop.area.customer_sheets:
		check("customer native frame grid", sheet.get_size() == Vector2(192, 48))
	check("night kitchen panel hidden at exit", not loop.menu_buttons[0].visible and not loop.cook_buttons[0].visible and not loop.backgrounds[1].visible)
	await shot("restaurant")
	loop.state.materials = [4, 4, 4]
	await walk_to(Vector2(60, 130))
	await walk_to(loop.area.stations.kitchen)
	await frames()
	check("near kitchen shows cooking commands", loop.cook_buttons[0].visible and not loop.cook_buttons[0].disabled and not loop.menu_buttons[0].visible)
	for i in range(3):
		loop.state.admit()
	await shot("restaurant_kitchen")
	if capture:
		loop.state.held = 0
		lane.player.position = loop.area.seats[0] + Vector2(0, 24)
		await shot("restaurant_serving")
		loop.state.held = -1
	loop.state.end_phase()
	loop.state.next_day()
	await frames()
	check("day restaurant shows menu only", loop.menu_buttons[0].visible and not loop.cook_buttons[0].visible and not loop.discard_button.visible)
	await shot("restaurant_menu")
	loop.enter("field")
	await frames()
	check("field background", loop.area.background.resource_path.ends_with("field_background.png"))
	check("gather artwork", loop.area.gather_textures.size() == 4 and loop.area.gather_textures[0].get_size() == Vector2(32, 32))
	check("field shows backpack only", loop.inventory.visible and not loop.sidebar_title.visible and not loop.menu_buttons[0].visible and not loop.cook_buttons[0].visible and loop.backgrounds[0].size.y == 46)
	await shot("field")
	await walk_to(Vector2(60, 115))
	await walk_to(loop.area.points[0])
	await key(KEY_E)
	check("gather feedback visible", loop.notice.visible and loop.backgrounds[2].visible)
	await shot("field_gather")
	await create_timer(3.6).timeout
	check("feedback automatically clears", not loop.notice.visible and not loop.backgrounds[2].visible)
	if capture:
		loop.enter("home")
		lane.player.position = Vector2(230, 310)
		lane.camera.force_update_scroll()
		await shot("home_size_720")
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		await shot("home_1920")
		loop.enter("town")
		await shot("town_1920")
	loop.enter("town")
	lane.queue_free()
	await frames()
	print("HOME VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
