extends SceneTree
## Menu, clock, settlement and real UI checks use only isolated test progress.
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Campaign = preload("res://Scenes/Campaign/campaign_state.gd")
const OUT := "res://output/restaurant_service/"
var failures := 0
var checks := 0
var capture := false
var lane
var loop

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = OUT + "preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = OUT + "saves_%d" % OS.get_process_id()
	Saves.end_session()
	Campaign.pending_intro = false
	capture = "--restaurant-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("RESTAURANT TEST ", title, ": ", "PASS" if ok else "FAIL")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame
	if root.get_node("SceneTransition").active: await root.get_node("SceneTransition").finished

func click(button: Button) -> void:
	loop._refresh()
	var container = lane.viewport.get_parent()
	var position: Vector2 = container.position + button.get_global_rect().get_center() * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func shot(name: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + name, lane.viewport.get_texture().get_image().save_png(OUT + name + ".png") == OK)

func run() -> void:
	var state := State.new()
	# Rental transactions are covered by verify_property; this suite runs service.
	state.restaurant_leased = true
	check("new game has no automatic menu", state.menu.size() == State.DISHES.size() and state.menu.count(true) == 0)
	var before := state.to_save_data()
	check("empty menu cannot open", not state.start_service() and state.phase == "day" and state.remaining == State.DAY_SECONDS and state.coins == before.coins)
	state.tick(State.DAY_SECONDS + 500.0)
	state.tick(500.0)
	check("sunset waits without customers or lost service time", state.phase == "day" and state.get_time_text() == "18:00" and state.remaining == 0.0 and state.customers.is_empty())
	var restored := State.new()
	check("preparation can be saved and restored", restored.restore_save_data(state.to_save_data()) and restored.phase == "day" and restored.get_time_text() == "18:00")
	check("invalid and locked recipe changes are atomic", not state.set_menu_dish(-1, true) and not state.set_menu_dish(state.DISHES.size(), true) and not state.set_menu_dish(35, true) and state.menu.count(true) == 0)
	check("player selects unlocked recipes", state.set_menu_dish(0, true) and state.set_menu_dish(1, true) and state.set_menu_dish(2, true))
	check("menu choices consume no ingredients", state.materials == [0,0,0] and state.raw == [0,0,0])
	state.campaign.restaurant = 4
	for dish in range(Campaign.restaurant(state).menu): state.set_menu_dish(dish, true)
	var full_menu: Array = state.menu.duplicate()
	check("menu capacity is enforced", not state.set_menu_dish(35, true) and state.menu == full_menu)
	state.campaign.restaurant = 0
	state.menu.fill(false)
	state.set_menu_dish(0, true)
	state.materials = [4,0,0]
	check("confirmed opening starts a full five-minute service", state.start_service() and state.remaining == 300.0 and state.get_time_text() == "18:00")
	check("menu locks and repeat opening cannot restart timer", not state.set_menu_dish(1, true) and not state.start_service() and state.remaining == 300.0)
	check("orders use only listed recipes", state.admit() and state.customers[0].dish == 0)
	check("cooking debits exactly once", state.start_cook(0) and not state.start_cook(0) and state.materials == [2,0,0])
	state.tick(3.0)
	check("serving keeps existing pricing", state.held == 0 and state.serve(0) and state.income == 12 and state.coins == 0)
	check("mid-service save preserves orders and time", restored.restore_save_data(state.to_save_data()) and restored.remaining == 297.0 and restored.customers == state.customers and restored.income == 12)
	state.tick(147.0)
	check("half of service is 20:00", state.get_time_text() == "20:00" and state.remaining == 150.0)
	state.tick(149.0)
	check("service remains active at 299 seconds", state.phase == "night" and state.remaining == 1.0 and state.get_time_text() == "21:30")
	state.customers = [{"seat":0,"dish":0,"patience":25.0,"status":"waiting"}, {"seat":1,"dish":0,"patience":25.0,"status":"eating","eating_left":2.0}]
	state.lost = 0
	state.held = 0
	state.cooking = 0
	state.cook_left = 2.0
	state.tick(1.0)
	check("22:00 closes automatically and pays once", state.phase == "result" and state.get_time_text() == "22:00" and state.remaining == 0.0 and state.coins == 12)
	check("closing clears unfinished service and counts only waiting guests", state.customers.is_empty() and state.held == -1 and state.cooking == -1 and state.cook_left == 0.0 and state.wasted == 2 and state.lost == 1)
	state.tick(1000.0)
	state.end_phase()
	check("settlement is frozen and cannot double pay", state.coins == 12 and state.get_time_text() == "22:00")
	state.next_day()
	check("next morning keeps stock and chosen menu", state.day == 2 and state.phase == "day" and state.get_time_text() == "06:00" and state.menu[0] and state.materials == [2,0,0] and state.income == 0)
	state.materials = [0,0,0]
	check("empty stock allows a zero-income service", state.start_service() and not state.admit())
	state.tick(300.0)
	state.next_day()
	check("zero-income service can reach the next day", state.day == 3 and state.phase == "day" and state.coins == 12)
	for old_duration in [300.0, 900.0]:
		for phase in ["day", "night", "result"]:
			var legacy: Dictionary = State.new().to_save_data()
			legacy.erase("restaurant_leased")
			legacy.erase("day_seconds")
			legacy.erase("night_seconds")
			legacy.day_length_seconds = old_duration
			legacy.phase = phase
			legacy.menu[0] = true
			legacy.remaining = old_duration * (0.3 if phase == "day" else 0.2 if phase == "night" else 0.0)
			var normalized := State.normalize_save_data(legacy)
			check("legacy migration " + str(old_duration) + " " + phase, not normalized.is_empty() and restored.restore_save_data(normalized) and restored.remaining == (270.0 if phase == "day" else 150.0 if phase == "night" else 0.0) and restored.menu[0])
			check("migration is idempotent " + str(old_duration) + " " + phase, State.normalize_save_data(normalized) == normalized)
	check("isolated save slot opens", Saves.begin_slot(1).ok)
	Saves.pending.state.campaign.introduced = true
	Saves.pending.state.campaign.guide_met = true
	Saves.pending.state.campaign.opening_stage = 3
	Saves.pending.state.restaurant_leased = true
	Saves.pending.state.campaign.player_name = "Test"
	Saves.pending.world.location = "town"
	Saves.pending.world.position = [408,364]
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	check("opening action belongs to restaurant", not loop.end_button.visible)
	loop.state.remaining = 0.01
	loop.state.tick(0.02)
	loop._sync_phase()
	await frames()
	loop._refresh()
	check("sunset returns to restaurant without auto opening", loop.location == "restaurant" and loop.state.phase == "day" and loop.end_button.visible and loop.end_button.disabled)
	await click(loop.end_button)
	check("disabled empty-menu action cannot open", loop.state.phase == "day")
	await click(loop.menu_buttons[0])
	check("real menu button enables opening", loop.state.menu[0] and not loop.end_button.disabled)
	await click(loop.recipe_button)
	check("recipe button opens full cookbook and pauses world", loop.hud.mode == "campaign" and loop.campaign_controller.tab == "食谱" and paused and loop.campaign_controller.list.get_child_count() == State.DISHES.size() + 1)
	var berry_row: HBoxContainer = loop.campaign_controller.list.get_child(2)
	var actions: Array = berry_row.get_children().filter(func(node): return node is Button)
	await click(actions[0])
	check("cookbook selection shares the same menu", loop.state.menu[1] and loop.state.menu.count(true) == 2 and paused)
	await shot("cookbook")
	loop.hud.close_modal()
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		loop._refresh()
		await frames()
		check("localized preparation controls " + locale, loop.end_button.visible and not loop.end_button.disabled and loop.recipe_button.visible and not loop.service_hours.text.is_empty() and loop.end_button.tooltip_text.is_empty())
		check("preparation controls fit sidebar " + locale, loop.backgrounds[1].get_global_rect().encloses(loop.end_button.get_global_rect()) and loop.backgrounds[1].get_global_rect().encloses(loop.recipe_button.get_global_rect()) and loop.backgrounds[1].get_global_rect().encloses(loop.sidebar_title.get_global_rect()))
		await shot("preparation_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	await click(loop.end_button)
	check("real opening button starts full service", loop.state.phase == "night" and loop.state.remaining == 300.0 and loop.hud.time_label.text == "18:00" and not loop.menu_buttons[0].visible and not loop.end_button.visible)
	check("service save is valid", loop.save_progress().ok and Saves.read_slot(1).data.state.remaining == 300.0)
	loop.paused_for_test = false
	loop.state.income = 27
	loop._process(300.0)
	loop.paused_for_test = true
	check("22:00 writes settlement automatically", Saves.read_slot(1).data.state.phase == "result" and Saves.read_slot(1).data.state.coins == 27 and loop.state.get_time_text() == "22:00")
	check("closing clock hands match 22:00", is_equal_approx(loop.hud.clock_art.progress, 600.0 / 720.0))
	await shot("settlement")
	await click(loop.end_button)
	check("next-day action restores morning and menu editing", loop.state.phase == "day" and loop.state.day == 2 and loop.state.menu.count(true) == 2 and loop.state.coins == 27)
	lane.queue_free()
	await frames(5)
	Saves.end_session()
	print("RESTAURANT VERIFY END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
