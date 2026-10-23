extends SceneTree
const OUT := "res://output/room_centering/"
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
var lane
var loop
var failures := 0
var checks := 0
func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	preload("res://Scenes/Campaign/campaign_state.gd").pending_intro = false
	run.call_deferred()
func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("ROOM CENTER ", title, ": ", "PASS" if passed else "FAIL")
func centered(usable_width: float = 640.0) -> bool:
	lane.camera.force_update_scroll()
	var center: Vector2 = loop.area.RESTAURANT_BOUNDS.get_center()
	return (lane.viewport.get_canvas_transform() * center).distance_to(Vector2(usable_width / 2.0, 180)) < 0.1
func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	loop.state.restaurant_leased = true
	loop.state.campaign.settling_in = true
	loop.enter("restaurant")
	await frames()
	check("default entry centered", centered())
	check("spawn coordinates preserved", lane.player.position == Vector2(60, 248))
	for point in [Vector2(20, 248), Vector2(304, 251), Vector2(230, 130)]:
		lane.player.position = point
		await frames()
		check("room stays centered at " + str(point), centered())
	loop._restore_world({"location": "restaurant", "position": [60, 248], "town_position": [408, 364], "farm_position": [270, 258], "weather": "clear", "facing": 0})
	await frames()
	check("loaded room centered", centered() and lane.player.position == Vector2(60, 248))
	check("prep route", await Navigation.walk(lane, loop.area.stations.prep))
	check("kitchen route", await Navigation.walk(lane, loop.area.stations.kitchen))
	check("exit route", await Navigation.walk(lane, loop.area.stations.exit))
	lane.player.position = Vector2(110, 248)
	await frames()
	if "--capture" in OS.get_cmdline_user_args():
		for resolution in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
			root.size = resolution
			await frames(5)
			check("centered at " + str(resolution), centered())
			RenderingServer.force_draw(false)
			check("capture " + str(resolution), root.get_texture().get_image().save_png(OUT + "restaurant_%dx%d.png" % [resolution.x, resolution.y]) == OK)
		check("capture viewport", lane.viewport.get_texture().get_image().save_png(OUT + "restaurant.png") == OK)
	loop.state.campaign.settling_in = false
	await frames()
	check("menu centers room in free area", centered(440.0))
	var room_on_screen: Rect2 = lane.viewport.get_canvas_transform() * Rect2(loop.area.RESTAURANT_BOUNDS)
	check("menu does not cover room", not room_on_screen.intersects(loop.backgrounds[1].get_global_rect()))
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920, 1080)
		await frames(5)
		RenderingServer.force_draw(false)
		check("capture menu", root.get_texture().get_image().save_png(OUT + "restaurant_menu_1920x1080.png") == OK)
	loop.state.phase = "night"
	lane.player.position = loop.area.stations.kitchen
	await frames()
	check("cooking panel does not cover room", centered(440.0) and loop.backgrounds[1].visible)
	lane.player.position = loop.area.spawn
	await frames()
	check("closed cooking panel restores screen center", centered() and not loop.backgrounds[1].visible)
	loop.state.held = 0
	await frames()
	check("held dish controls leave room visible", centered(440.0) and loop.discard_button.visible)
	loop.state.held = -1
	loop.state.phase = "day"
	loop.state.campaign.settling_in = true
	for location in ["town", "farm", "home", "blacksmith", "store", "furniture_store", "field", "dock"]:
		loop.enter(location)
		await frames()
		check(location + " normal camera limits restored", lane.camera.limit_left == 0 and lane.camera.limit_top == 0)
	loop.enter("restaurant")
	await frames()
	check("return entry centered", centered())
	lane.queue_free()
	await frames()
	print("ROOM CENTER END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
