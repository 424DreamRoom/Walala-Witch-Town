extends SceneTree
const OUT := "res://output/all_room_centering/"
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
const Framing = preload("res://Scenes/Gameplay/room_framing.gd")
var lane
var loop
var failures := 0
var checks := 0
var capture := "--capture" in OS.get_cmdline_user_args()
var pictures: Array[Image] = []
func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	preload("res://Scenes/Campaign/campaign_state.gd").pending_intro = false
	run.call_deferred()
func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame
		await physics_frame
func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("ALL ROOMS ", title, ": ", "PASS" if passed else "FAIL")
func room_screen() -> Rect2:
	lane.camera.force_update_scroll()
	return lane.viewport.get_canvas_transform() * Rect2(loop.area.room_bounds)
func centered(width: int = 0) -> bool:
	return room_screen().get_center().distance_to(Framing.play_rect(lane.viewport.size, width).get_center()) < 1.1
func fits(width: int = 0) -> bool:
	return Framing.play_rect(lane.viewport.size, width).grow(1.1).encloses(room_screen())
func shot(title: String, overview: bool = false) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var picture: Image = lane.viewport.get_texture().get_image()
	check("capture " + title, picture.save_png(OUT + title + ".png") == OK)
	if overview: pictures.append(picture)
func restore() -> void:
	var point: Vector2 = loop.area.spawn
	loop._restore_world({"location": loop.location, "position": [point.x, point.y], "town_position": [408, 364], "farm_position": [270, 258], "weather": "clear", "facing": 0})
	await frames()
func exit_room(title: String) -> void:
	check(title + " real walk to exit", await Navigation.walk(lane, loop.area.stations.exit))
	loop.interact()
	await frames()
	if root.get_node("SceneTransition").active: await root.get_node("SceneTransition").finished
	await frames()
	check(title + " returns outdoors", loop.location in ["town", "farm"])
	check(title + " outdoor zoom and limits restored", lane.camera.zoom == Vector2.ONE and lane.camera.limit_left == 0 and lane.camera.limit_top == 0)
func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.campaign_controller.set_process(false)
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	loop.state.restaurant_leased = true
	loop.state.campaign.settling_in = true
	for level in range(4):
		var title := "home_%d" % level
		loop.state.furniture.legacy_fixtures = level == 3
		loop.state.furniture.house_level = mini(level, 2)
		loop.enter("home")
		await frames()
		check(title + " entry centered and complete", centered() and fits())
		check(title + " original spawn preserved", lane.player.position == Vector2(320, 405))
		await shot(title, true)
		for point in [Vector2(320, 405), Vector2(320, 300), Vector2(320, 449)]:
			lane.player.position = point
			await frames()
			check(title + " stable camera " + str(point), centered() and fits())
		await restore()
		check(title + " restore centered", centered() and fits())
		check(title + " build catalog opens", loop.builder.open_catalog())
		loop.builder._room("edit")
		await frames()
		check(title + " build mode room visible", centered() and fits())
		loop.builder.close()
		await frames()
		check(title + " build mode restores camera", centered() and fits())
		await exit_room(title)
	for kind in ["store", "blacksmith", "furniture_store", "restaurant"]:
		loop.enter(kind)
		await frames()
		check(kind + " entry centered and complete", centered() and fits())
		await shot(kind, true)
		await restore()
		check(kind + " restore centered", centered() and fits())
		if kind == "restaurant":
			check("restaurant prep route", await Navigation.walk(lane, loop.area.stations.prep))
			check("restaurant kitchen route", await Navigation.walk(lane, loop.area.stations.kitchen))
			loop.state.campaign.settling_in = false
			await frames()
			check("restaurant menu leaves room visible", centered(440) and fits(440))
			await shot("restaurant_menu")
			loop.state.phase = "night"
			await frames()
			check("restaurant cooking leaves room visible", loop.backgrounds[1].visible and centered(440) and fits(440))
			loop.state.phase = "day"
			loop.state.campaign.settling_in = true
		elif kind in ["store", "blacksmith"]:
			check(kind + " real walk to service", await Navigation.walk(lane, loop.area.stations.service))
			loop.interact()
			await frames()
			check(kind + " service leaves room visible", loop.area.service_panel.visible and centered(406) and fits(406))
			await shot(kind + "_service")
			loop.interact()
			await frames()
			check(kind + " service closes and recenters", not loop.area.service_panel.visible and centered() and fits())
		else:
			check(kind + " real walk to service", await Navigation.walk(lane, loop.area.stations.service))
			loop.interact()
			await frames()
			check(kind + " modal opens", loop.hud.mode == "housing")
			loop.hud.close_modal()
			await frames()
			check(kind + " modal closes and recenters", centered() and fits())
		await exit_room(kind)
	for kind in ["town", "farm", "field", "dock"]:
		loop.enter(kind)
		await frames()
		check(kind + " outdoor framing unchanged", lane.camera.zoom == Vector2.ONE and lane.camera.limit_left == 0 and lane.camera.limit_top == 0)
	if capture:
		var overview := Image.create(1280, 1440, false, Image.FORMAT_RGBA8)
		for i in range(pictures.size()): overview.blit_rect(pictures[i], Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
		check("capture all rooms overview", overview.save_png(OUT + "overview.png") == OK)
		loop.enter("restaurant")
		for resolution in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1080)]:
			root.size = resolution
			await frames(5)
			check("window centered " + str(resolution), centered() and fits())
			RenderingServer.force_draw(false)
			check("capture window " + str(resolution), root.get_texture().get_image().save_png(OUT + "window_%dx%d.png" % [resolution.x, resolution.y]) == OK)
	lane.queue_free()
	await frames()
	print("ALL ROOMS END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
