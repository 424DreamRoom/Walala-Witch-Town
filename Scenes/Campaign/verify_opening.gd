extends SceneTree
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Collision = preload("res://Scenes/Gameplay/actor_collision.gd")
const OUT := "res://output/doorstep_opening/"
var checks := 0
var failures := 0
var capture := false
var lane
var loop
var controller

func _initialize() -> void:
	var profile := OUT + str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile + "/preferences.cfg"
	Saves.directory = profile + "/saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(caption: String, result: bool) -> void:
	checks += 1
	if not result: failures += 1
	print("OPENING ", caption, ": PASS" if result else ": FAIL")

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func shot(filename: String) -> void:
	if not capture: return
	await frames(3)
	await RenderingServer.frame_post_draw
	check("capture " + filename, lane.viewport.get_texture().get_image().save_png(OUT + filename + ".png") == OK)

func load_game() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(8)
	loop = lane.get_node("GameLoop")
	controller = loop.campaign_controller
	controller.set_process(false)

func unload_game() -> void:
	lane.queue_free()
	await frames(5)
	controller = null
	loop = null
	lane = null

func finish_walk() -> void:
	for index in range(200):
		if not controller.arrival_active: break
		controller._process(0.05)

func run() -> void:
	check("protagonist defaults to Weierliya", State.new().campaign.player_name == "薇尔莉娅")
	for introduced in [false, true]:
		for missing_name in [false, true]:
			var legacy: Dictionary = State.new().to_save_data()
			legacy.campaign.introduced = introduced
			legacy.campaign.erase("guide_met")
			if missing_name: legacy.campaign.erase("player_name")
			else: legacy.campaign.player_name = ""
			var restored := State.normalize_save_data(legacy)
			check("legacy default name " + str([introduced, missing_name]), not restored.is_empty() and restored.campaign.player_name == C.DEFAULT_PLAYER_NAME)
			check("legacy welcome progress " + str([introduced, missing_name]), restored.campaign.guide_met == (introduced and missing_name))
	for guide_met in [false, true]:
		var legacy: Dictionary = State.new().to_save_data()
		legacy.campaign.introduced = true
		legacy.campaign.player_name = ""
		legacy.campaign.guide_met = guide_met
		check("explicit welcome progress preserved " + str(guide_met), State.normalize_save_data(legacy).campaign.guide_met == guide_met)
	var named: Dictionary = State.new().to_save_data()
	named.campaign.player_name = "Aster"
	check("existing save name preserved", State.normalize_save_data(named).campaign.player_name == "Aster")
	for invalid in [42, "a\nb"]:
		named.campaign.player_name = invalid
		check("invalid legacy name rejected " + str(invalid).c_escape(), State.normalize_save_data(named).is_empty())
	check("new slot created", Saves.begin_slot(1).ok)
	var disk := Saves.read_slot(1)
	check("new slot persists default name", disk.data.state.campaign.player_name == C.DEFAULT_PLAYER_NAME)
	check("new snapshot starts outside home", disk.data.world.location == "farm" and Vector2(disk.data.world.position[0],disk.data.world.position[1]) == Vector2(270,258))
	C.pending_intro = true
	await load_game()
	check("film starts over exterior spawn", paused and is_instance_valid(controller.intro) and loop.location == "farm" and lane.player.position == loop.HOME_EXIT_POSITION)
	controller.finish_intro()
	check("skipped film starts visible approach directly", controller.arrival_active and paused and not loop.state.campaign.guide_met and controller.arrival_actor.get_parent() == loop.area and loop.hud.mode.is_empty() and loop.state.campaign.player_name == C.DEFAULT_PLAYER_NAME)
	check("opening has no name input", loop.hud.layer.find_child("NameInput", true, false) == null)
	check("opening frames both characters", lane.camera.position == Vector2(0,64))
	var start: Vector2 = controller.arrival_actor.position
	var remaining: float = loop.state.remaining
	controller._process(0.5)
	check("NPC walks continuously", controller.arrival_actor.position.distance_to(start) == 40.0 and controller.arrival_active)
	start = controller.arrival_actor.position
	controller._process(1.0 / 60.0)
	check("fractional frame budget finishes without spinning", controller.arrival_actor.position.distance_to(start) > 1.0 and controller.arrival_actor.position.distance_to(start) < 1.4)
	lane.automation = true
	lane.test_direction = Vector2.RIGHT
	await frames(8)
	check("approach freezes clock and player", loop.state.remaining == remaining and lane.player.position == loop.HOME_EXIT_POSITION)
	lane.test_direction = Vector2.ZERO
	loop.hud.open_bag()
	loop.save_menu.show_menu()
	check("approach blocks competing modals", loop.hud.mode.is_empty() and not loop.save_menu.open)
	await shot("approach")
	check("interrupted approach saves", loop.save_progress().ok and not Saves.read_slot(1).data.state.campaign.guide_met)
	await unload_game()
	check("unloading approach restores pause", not paused)
	check("interrupted slot reopens", Saves.begin_slot(1).ok)
	C.pending_intro = false
	await load_game()
	check("interrupted approach resumes directly", controller.arrival_active and not is_instance_valid(controller.intro) and loop.location == "farm")
	var clear := true
	for index in range(200):
		if not controller.arrival_active: break
		controller._process(0.05)
		var feet := Collision.footprint(controller.arrival_actor.position)
		if loop.area.solids.any(func(rect): return rect.intersects(feet)): clear = false
	check("whole approach clears farm obstacles", clear)
	check("arrival starts story beside the witch", not controller.arrival_active and loop.hud.mode == "dialogue" and paused and loop.state.campaign.guide_met and controller.arrival_actor.position == Vector2(270,294))
	check("story introduces conflict and current chapter", loop.hud.lines.size() == 7 and loop.hud.lines[-1] == preload("res://Scenes/Campaign/guide_profile.gd").CHAPTERS[0])
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		for index in range(loop.hud.lines.size()):
			loop.hud.line_index = index
			loop.hud._show_line()
			await frames(1)
			check("story fits " + locale + " " + str(index), loop.hud.dialogue_text.get_content_height() <= loop.hud.dialogue_text.size.y)
		loop.hud.line_index = 2
		loop.hud._show_line()
		loop.hud.dialogue_text.visible_characters = -1
		await shot("story_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	loop.hud.close_modal()
	controller._process(0.0)
	check("story releases world and camera", not paused and lane.camera.position == Vector2.ZERO and controller.arrival_departing)
	start = controller.arrival_actor.position
	lane.player.position = Vector2(270,315)
	controller._process(0.5)
	check("departing guide waits for player clearance", controller.arrival_actor.position == start)
	lane.player.position = loop.HOME_EXIT_POSITION
	for index in range(200):
		if not controller.arrival_departing: break
		controller._process(0.05)
	check("NPC leaves along the path", not controller.arrival_departing and not is_instance_valid(controller.arrival_actor))
	check("completed welcome saves", loop.save_progress().ok and Saves.read_slot(1).data.state.campaign.guide_met)
	await unload_game()
	check("completed slot reopens", Saves.begin_slot(1).ok)
	await load_game()
	check("completed save skips approach", not paused and not controller.opening_active() and not is_instance_valid(controller.arrival_actor))
	loop.enter("home")
	lane.player.position = Vector2(320,405)
	check("existing interior position saves", loop.save_progress().ok)
	await unload_game()
	check("interior slot reopens", Saves.begin_slot(1).ok)
	await load_game()
	check("existing save preserves its location", loop.location == "home" and lane.player.position == Vector2(320,405) and not controller.opening_active())
	await unload_game()
	check("second new slot created", Saves.begin_slot(2).ok)
	C.pending_intro = true
	await load_game()
	controller.intro_elapsed = 23.99
	controller._process(0.02)
	check("natural film end starts approach directly", paused and controller.arrival_active and not is_instance_valid(controller.intro) and loop.state.campaign.player_name == C.DEFAULT_PLAYER_NAME)
	finish_walk()
	check("natural film end reaches welcome", paused and loop.hud.mode == "dialogue" and loop.state.campaign.guide_met)
	loop.hud.close_modal()
	check("natural opening resumes play", not paused)
	await unload_game()
	Saves.end_session()
	var menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	await frames()
	menu._start_game()
	check("slot card displays default name", menu.slot_buttons[0].get_child(0).text.contains(C.DEFAULT_PLAYER_NAME))
	menu.queue_free()
	await frames()
	await create_timer(0.25).timeout
	print("OPENING COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
