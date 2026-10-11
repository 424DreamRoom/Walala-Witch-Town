extends SceneTree
const Saves = preload("res://Scenes/Save/save_store.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://output/hud_top_cleanup/21224/hud/"
var lane
var loop
var hud
var failures := 0
var capture := false

func _initialize() -> void:
	Preferences.file_path = "res://output/hud_top_cleanup/21224/hud/preferences.cfg"
	Saves.directory = "res://output/hud_top_cleanup/21224/hud/saves"
	Saves.end_session()
	capture = "--hud-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("HUD TEST ",title,": ","PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await frames()

func click(control: Control) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var position: Vector2 = container.position + control.get_global_rect().get_center() * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion,true)
	await frames()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event,true)
		await frames()

func shot(title: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280,720,Image.INTERPOLATE_NEAREST)
	check("capture " + title,pixels.save_png(OUT+title+".png") == OK)

func advance_phase() -> void:
	var paused_for_test_before: bool = loop.paused_for_test
	loop.state.remaining = 0.01
	loop.paused_for_test = false
	await create_timer(0.1).timeout
	loop.paused_for_test = paused_for_test_before

func run() -> void:
	Saves.directory = "res://output/hud_top_cleanup/21224/hud/saves"
	Preferences.file_path = "res://output/hud_top_cleanup/21224/hud/preferences.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1)+suffix))
	Saves.begin_slot(1)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	hud = loop.hud
	loop._refresh()
	check("HUD attached to native canvas",hud.base.size == Vector2(640,360))
	check("actual initial time",hud.time_label.text == "06:00")
	check("clock and item slots created",hud.base.find_children("InventorySlot*", "Button", false, false).size() == hud.HOTBAR_SLOTS and is_instance_valid(hud.clock_art) and not loop.end_button.visible)
	check("new game starts with one wand",loop.state.tools == State.STARTING_TOOLS and hud.item_counts()[0] == 1 and State.Items.TOOLS == ["wand"])
	check("hotbar stays centered on canvas",hud.base.get_node("InventorySlot0").position.x + hud.slot_counts.back().get_parent().get_rect().end.x == 640)
	check("no permanent bottom menu toolbar",loop.save_menu.layer.get_node_or_null("SaveMenuButton") == null and loop.save_menu.layer.get_child_count() == 2)
	await shot("hud_town")
	await click(hud.base.get_node("InventorySlot0"))
	check("tool slot opens backpack",hud.mode == "bag" and paused and hud.modal.has_node("Backpack/BagSlot0"))
	await key(KEY_B)
	if capture:
		var saved_remaining: float = loop.state.remaining
		var saved_day: int = loop.state.day
		loop.state.day = 3
		loop.state.remaining = State.DAY_SECONDS / 12.0
		loop._sync_phase()
		loop._refresh()
		await shot("hud_clock_compact_evening")
		loop.state.day = saved_day
		loop.state.remaining = saved_remaining
		loop._sync_phase()
		loop._refresh()
	loop.enter("home")
	loop._refresh()
	check("home keeps clock and item slots",not loop.end_button.visible and hud.base.find_children("InventorySlot*", "Button", false, false).size() == hud.HOTBAR_SLOTS and is_instance_valid(hud.clock_art) and not loop.notice.visible)
	await shot("hud_home_clean")
	loop.enter("town")
	loop._refresh()
	await key(KEY_J)
	check("J opens journal and pauses",hud.mode == "campaign" and paused)
	var remaining: float = loop.state.remaining
	var position: Vector2 = lane.player.position
	loop.paused_for_test = false
	lane.test_direction = Vector2.RIGHT
	await create_timer(0.15,true).timeout
	lane.test_direction = Vector2.ZERO
	check("journal freezes time and world",loop.state.remaining == remaining and lane.player.position == position)
	loop.paused_for_test = true
	await shot("journal")
	check("journal presents only the active main",loop.campaign_controller.list.get_child_count() == 1 and loop.campaign_controller.list.has_node("MainQuest"))
	await key(KEY_ESCAPE)
	check("Esc closes journal without pause menu",hud.mode.is_empty() and not paused and not loop.save_menu.open)
	check("gather quest counts successes",loop.state.gather(0) and loop.state.gather(0) and not loop.state.gather(0) and loop.state.journal.gather == 2)
	loop.state.gather(3)
	loop.state.process_raw()
	check("prepare quest counts transferred ingredients",loop.state.journal.prepare == 3 and loop.state.journal.gather == 3)
	check("empty prep never adds progress",not loop.state.process_raw() and loop.state.journal.prepare == 3)
	loop.state.catch_fish("ui_fish")
	check("fish quest records real catch",loop.state.journal.fish == 1)
	loop.state.coins = 128
	loop.state.resources.wood = 3
	loop.state.resources.ore = 2
	loop.state.resources.iron = 1
	loop.state.raw = [2,1,1]
	loop._refresh()
	var mushroom_slot := -1
	var iron_slot := -1
	for index in range(loop.state.bag_slots.size()):
		match loop.state.bag_slots[index].get("id", ""):
			"mushroom": mushroom_slot = index
			"iron": iron_slot = index
	check("HUD inventory reflects shared data",mushroom_slot >= 0 and iron_slot >= 0 and hud.slot_counts[mushroom_slot].text == "2" and hud.slot_counts[iron_slot].text.is_empty() and hud.slot_counts[iron_slot].get_parent().get_node("Icon").kind == "iron")
	await key(KEY_B)
	check("B opens paused bag",hud.mode == "bag" and paused)
	var backpack: Control = hud.modal.get_node("Backpack")
	var all_cards_fit := true
	for card in backpack.bag_slots:
		all_cards_fit = all_cards_fit and Rect2(Vector2.ZERO,backpack.size).encloses(card.get_rect())
	check("all tools and materials fit in backpack",all_cards_fit)
	await shot("bag")
	await key(KEY_B)
	check("B toggles bag closed",hud.mode.is_empty() and not paused)
	await key(KEY_H)
	check("H opens dialogue with typewriter",hud.mode == "dialogue" and paused and hud.dialogue_text.visible_characters < hud.dialogue_text.get_total_character_count())
	await key(KEY_E)
	check("E reveals and presents choices",hud.dialogue_text.visible_characters == hud.dialogue_text.get_total_character_count() and hud.choices_root.visible)
	await shot("dialogue")
	await key(KEY_L)
	check("dialogue history contains current line",hud.history_panel.visible and hud.history_label.text.contains(hud.lines[0]))
	await key(KEY_L)
	await click(hud.choices_root.get_node("DialogueChoice0"))
	check("dialogue choice opens task journal",hud.mode == "campaign" and paused)
	await shot("journal_progress")
	await key(KEY_ESCAPE)
	check("switching modals restores original pause",not paused)
	await key(KEY_H)
	await key(KEY_E)
	await key(KEY_S)
	await key(KEY_ENTER)
	check("keyboard confirms dialogue choice",hud.mode == "campaign" and paused)
	await key(KEY_ESCAPE)
	hud.start_dialogue("小女巫", "res://Art/Character/Storybook/WalalaWitch/walala-witch.png",["第一句。","第二句。"])
	await key(KEY_E)
	await key(KEY_E)
	check("multi-line dialogue advances",hud.line_index == 1)
	await key(KEY_E)
	await key(KEY_E)
	check("last line resumes play",hud.mode.is_empty() and not paused)
	loop.lane.weather.set_weather("rain")
	loop._refresh()
	check("weather HUD uses live weather",hud.weather_art.weather == "rain")
	loop.lane.weather.set_weather("clear")
	loop.enter("restaurant")
	loop._refresh()
	await shot("restaurant_day")
	check("day menu remains available without global phase button",loop.menu_buttons[0].visible and not loop.end_button.visible)
	await click(loop.menu_buttons[2])
	check("real menu input still works",not loop.state.menu[2])
	await advance_phase()
	loop.state.admit()
	loop.lane.player.position = loop.area.stations.kitchen
	loop._refresh()
	check("night cooking panel visible",loop.cook_buttons[0].visible)
	await click(loop.cook_buttons[0])
	check("real cooking input spends stock",loop.state.cooking == 0 and loop.state.materials[0] == 1)
	loop.state.tick(3.1)
	loop._refresh()
	await shot("restaurant_night")
	loop.state.serve(0)
	check("served quest increments once",loop.state.journal.serve == 1 and not loop.state.serve(0) and loop.state.journal.serve == 1)
	var progress: Dictionary = loop.state.journal.duplicate(true)
	check("real six-slot save contains journal",loop.save_progress().ok and Saves.read_slot(1).data.state.journal == progress)
	var restored := State.new()
	check("journal restores with state",restored.restore_save_data(Saves.read_slot(1).data.state) and restored.journal == progress)
	var legacy := restored.to_save_data()
	legacy.erase("journal")
	check("pre-HUD saves remain compatible",restored.restore_save_data(legacy) and restored.journal.gather == 0)
	var invalid: Dictionary = loop.state.to_save_data()
	invalid.journal.fish = -1
	check("invalid journal data rejected",not restored.restore_save_data(invalid))
	await advance_phase()
	loop._refresh()
	await shot("settlement")
	await click(loop.end_button)
	check("quest progress survives next day",loop.state.day == 2 and loop.state.journal == progress)
	check("active main can complete from accumulated progress",loop.state.Campaign.complete_chapter(loop.state))
	loop.campaign_controller.story_filter = "已完成"
	hud.open_journal()
	check("completed filter lists only finished chapters",loop.campaign_controller.list.get_child_count() == 1)
	await shot("journal_completed")
	hud.close_modal()
	await key(KEY_ESCAPE)
	check("Esc still opens normal pause menu",loop.save_menu.open and paused)
	await click(loop.save_menu.panel.get_node("Settings"))
	check("settings available inside pause menu",loop.audio.panel.visible and not loop.save_menu.panel.visible and paused)
	await shot("settings_ingame")
	await click(loop.audio.panel.get_node("GameTab"))
	if capture:
		await click(loop.audio.panel.get_node("DialogueSpeed"))
		for pressed in [true, false]:
			var cancel := InputEventKey.new()
			cancel.keycode = KEY_ESCAPE
			cancel.physical_keycode = KEY_ESCAPE
			cancel.pressed = pressed
			Input.parse_input_event(cancel)
			Input.flush_buffered_events()
			await frames()
		check("ingame Esc dismisses only dropdown",loop.audio.panel.visible and loop.save_menu.open and paused and not loop.audio.panel.has_open_popup())
	await click(loop.audio.panel.get_node("ShowHotbar"))
	hud.refresh()
	check("hotbar preference changes actual HUD",not hud.hotbar_art.visible and hud.slot_counts.all(func(count): return not count.get_parent().visible))
	var speed: OptionButton = loop.audio.panel.get_node("DialogueSpeed")
	speed.select(3)
	speed.item_selected.emit(3)
	await click(loop.audio.panel.get_node("CloseAudioSettings"))
	await key(KEY_ESCAPE)
	await key(KEY_H)
	await frames(2)
	check("instant dialogue is fully revealed",hud.dialogue_text.visible_characters == hud.dialogue_text.get_total_character_count() and hud.choices_root.visible)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await click(loop.save_menu.panel.get_node("Settings"))
	await click(loop.audio.panel.get_node("GameTab"))
	await click(loop.audio.panel.get_node("AutoRun"))
	await click(loop.audio.panel.get_node("CloseAudioSettings"))
	await key(KEY_ESCAPE)
	lane.automation = false
	var running_modes: Array[bool] = []
	var observer := func(_distance: float, running: bool): running_modes.append(running)
	lane.player_moved.connect(observer)
	lane._physics_process(0.0)
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	Input.flush_buffered_events()
	lane._physics_process(0.0)
	shift.pressed = false
	Input.parse_input_event(shift)
	lane.player_moved.disconnect(observer)
	check("auto run and Shift change actual locomotion",running_modes.size() >= 2 and running_modes[0] and not running_modes.back())
	lane.automation = true
	await key(KEY_ESCAPE)
	await click(loop.save_menu.panel.get_node("Settings"))
	await click(loop.audio.panel.get_node("GameTab"))
	await click(loop.audio.panel.get_node("ResetPage"))
	hud.refresh()
	check("game defaults restore visible hotbar",hud.hotbar_art.visible and hud.slot_counts.all(func(count): return count.get_parent().visible) and Preferences.dialogue_speed() == 30.0)
	await click(loop.audio.panel.get_node("CloseAudioSettings"))
	check("settings returns to paused menu",not loop.audio.panel.visible and loop.save_menu.panel.visible and paused)
	await click(loop.save_menu.panel.get_node("Settings"))
	await key(KEY_ESCAPE)
	check("Esc closes settings before resuming",not loop.audio.panel.visible and loop.save_menu.open and paused)
	await shot("pause_clean")
	await key(KEY_ESCAPE)
	check("Esc resumes normal pause menu",not loop.save_menu.open and not paused)
	await key(KEY_J)
	loop.save_menu.show_menu()
	check("pause menu safely takes modal ownership",hud.mode.is_empty() and loop.save_menu.open and paused)
	loop.save_menu.close_menu()
	check("ownership change resumes correctly",not paused)
	Saves.end_session()
	lane.queue_free()
	await frames(6)
	await create_timer(0.1).timeout
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1)+suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("HUD VERIFY END failures=",failures)
	quit(0 if failures == 0 else 1)
