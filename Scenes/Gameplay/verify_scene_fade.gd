extends SceneTree
## Exercise the visible cover, blocked input, pause ownership and scene handoff.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/scene_fade/"
const MENU := "res://Scenes/MainMenu/main_menu.tscn"
var transition
var lane
var loop
var failures := 0
var capture := "--fade-capture" in OS.get_cmdline_user_args()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = OUT + "preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = OUT + "saves_%d" % OS.get_process_id()
	Saves.end_session()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("SCENE FADE ", title, ": PASS" if ok else ": FAIL")
	if not ok: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func wait_for(predicate: Callable) -> bool:
	for i in range(240):
		if predicate.call(): return true
		await create_timer(0.02).timeout
	return false

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func shot(title: String) -> void:
	if not capture: return
	RenderingServer.force_draw(false)
	check("capture " + title, root.get_texture().get_image().save_png(OUT + title + ".png") == OK)

func run() -> void:
	transition = root.get_node("SceneTransition")
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	await frames()
	check("idle cover does not block input", not transition.active and not transition.cover.visible)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 800)]:
		root.size = resolution
		await frames()
		check("cover fills viewport " + str(resolution), transition.cover.get_global_rect() == root.get_visible_rect())
	root.size = Vector2i(1280, 720)
	await frames()
	var position: Vector2 = lane.player.position
	loop.paused_for_test = false
	var remaining: float = loop.state.remaining
	loop.travel("store", loop.STORE_GATE + Vector2(0, 34))
	check("fade starts before world swap", transition.active and transition.cover.visible and loop.location == "town")
	lane.test_direction = Vector2.RIGHT
	await create_timer(0.1).timeout
	check("fade out has intermediate opacity", transition.cover.color.a > 0.0 and transition.cover.color.a < 1.0)
	check("movement and clock freeze", paused and lane.player.position == position and loop.state.remaining == remaining)
	shot("01_fade_out")
	await key(KEY_ESCAPE)
	await key(KEY_B)
	check("always processing menus cannot open during fade", not loop.save_menu.open and loop.hud.mode.is_empty())
	loop.travel("farm")
	check("swap reaches destination", await wait_for(func(): return loop.location == "store"))
	lane.test_direction = Vector2.ZERO
	check("world swaps only behind opaque cover", transition.active and transition.cover.color.a > 0.99 and paused)
	shot("02_covered")
	await create_timer(0.08).timeout
	check("destination fades in gradually", transition.cover.color.a > 0.0 and transition.cover.color.a < 1.0)
	shot("03_fade_in")
	check("fade finishes", await wait_for(func(): return not transition.active))
	check("duplicate travel ignored and input restored", loop.location == "store" and not paused and not transition.cover.visible)
	check("destination HUD ready", loop.header.text.contains(tr("橡果杂货店")))
	shot("04_arrived")
	loop.paused_for_test = true
	paused = true
	loop.travel("town")
	check("paused travel finishes", await wait_for(func(): return not transition.active))
	check("existing pause is retained", paused and loop.location == "town")
	paused = false
	var owner := Node.new()
	var invalid_action := owner.queue_free
	owner.free()
	check("freed destination recovers", await transition.run(invalid_action) == ERR_DOES_NOT_EXIST)
	check("failed swap reveals original scene", not transition.active and not transition.cover.visible and not paused)
	loop.state.remaining = 0.0
	loop._sync_phase()
	check("preparation automatically fades", transition.active and loop.location == "town")
	check("preparation arrives at restaurant", await wait_for(func(): return not transition.active) and loop.location == "restaurant")
	loop.state.set_menu_dish(0, true)
	loop.end_phase()
	loop.state.end_phase()
	loop._sync_phase()
	loop.end_phase()
	check("new day automatically fades", transition.active)
	check("new day arrives at town", await wait_for(func(): return not transition.active) and loop.location == "town")
	check("scene change succeeds", await transition.change_scene(MENU) == OK)
	check("scene cover persists across SceneTree replacement", current_scene.scene_file_path == MENU and not paused and not transition.cover.visible)
	var menu = current_scene
	menu._start_game()
	menu._select_slot(1)
	check("new game uses shared fade", transition.active)
	check("new game fade finishes", await wait_for(func(): return not transition.active))
	lane = current_scene
	loop = lane.get_node("GameLoop")
	lane.automation = true
	loop.paused_for_test = true
	var campaign = loop.campaign_controller
	check("new game intro retains its pause", paused and is_instance_valid(campaign.intro) and not campaign.intro_old_pause)
	check("intro does not advance behind fade", campaign.intro_elapsed < 0.05)
	campaign.finish_intro()
	check("arrival captures unpaused world", campaign.arrival_active and not campaign.arrival_old_pause)
	campaign._finish_arrival()
	loop.hud.close_modal()
	loop.state.campaign.guide_met = false
	loop.save_menu.show_menu()
	loop.save_menu.return_to_title()
	check("saving and returning to title finishes", await wait_for(func(): return current_scene != null and current_scene.scene_file_path == MENU and not transition.active))
	check("title restores input and ends save session", not paused and Saves.active_slot == 0)
	menu = current_scene
	menu._start_game()
	menu._select_slot(1)
	check("continue game uses shared fade", transition.active)
	check("continue game fade finishes", await wait_for(func(): return not transition.active))
	loop = current_scene.get_node("GameLoop")
	check("loaded arrival retains its own pause", paused and loop.campaign_controller.arrival_active and not loop.campaign_controller.arrival_old_pause)
	current_scene.queue_free()
	await frames(5)
	Saves.end_session()
	print("SCENE FADE VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
