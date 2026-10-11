extends SceneTree
const Saves = preload("res://Scenes/Save/save_store.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://Scenes/Save/Verification/"
var failures := 0
var capture := false
var menu
var lane
var loop

func _initialize() -> void:
	capture = "--save-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("SAVE TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func click(control: Control, viewport: SubViewport) -> void:
	var container := viewport.get_parent() as SubViewportContainer
	var position := container.position + control.get_global_rect().get_center() * container.scale
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

func shot(title: String, viewport: SubViewport) -> void:
	if not capture:
		return
	await frames()
	RenderingServer.force_draw(false)
	var pixels := viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("screenshot " + title, pixels.save_png(OUT + title + ".png") == OK)

func clean_slots() -> void:
	Saves.end_session()
	for slot in range(1, 7):
		for suffix in ["", ".bak", ".tmp"]:
			var file_path: String = Saves.slot_path(slot) + suffix
			if FileAccess.file_exists(file_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))

func sample_snapshot() -> Dictionary:
	var state := State.new()
	state.day = 3
	state.coins = 83
	state.raw = [1, 2, 0]
	state.tools.hoe = 0
	state.materials = [9, 7, 5]
	state.nodes = [0, 1, 2, 0, 1, 2, 0, 1, 2]
	state.resources = {"wood": 7, "ore": 5, "fish": 4, "iron": 2}
	state.resource_damage = {"field_tree_0": 3, "field_ore_0": 1}
	state.fish_catches = {"dock_fish_0": 2}
	state.end_phase()
	state.start_cook(0)
	state.cook_left = 1.75
	state.remaining = 73.25
	state.customers = [{"seat": 0, "dish": 2, "patience": 12.5, "variant": 4, "status": "waiting", "eating_left": 0.0}, {"seat": 2, "dish": 1, "patience": 9.0, "variant": 5, "status": "eating", "eating_left": 1.5}]
	state.arrivals = 4.5
	state.serial = 7
	state.income = 23
	state.served = 2
	state.lost = 1
	state.wasted = 1
	state.message = "存档往返验证"
	var now := int(Time.get_unix_time_from_system())
	return {"state": state.to_save_data(), "world": {"location": "restaurant", "position": [270.0, 130.0], "town_position": [448.0, 384.0], "facing": 2, "weather": "rain"}, "play_seconds": 321.5, "created_at": now, "saved_at": now, "saved_at_text": Time.get_datetime_string_from_system(false, true)}

func corrupt(file_path: String, text: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Saves.directory = "user://save_verification"
	Preferences.file_path = "user://save_verification_preferences.cfg"
	if "--close-write" in OS.get_cmdline_user_args():
		clean_slots()
		Saves.begin_slot(6)
		lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
		root.add_child(lane)
		current_scene = lane
		await create_timer(0.2).timeout
		loop = lane.get_node("GameLoop")
		loop.state.coins = 91
		loop.save_menu.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		print("SAVE CLOSE REQUEST SENT")
		return
	if "--close-read" in OS.get_cmdline_user_args():
		var closed := Saves.read_slot(6)
		check("window close saves before process exits", closed.ok and closed.data.state.coins == 91)
		finish()
		return
	if "--restart-write" in OS.get_cmdline_user_args():
		clean_slots()
		check("restart seed written", Saves.write_slot(6, sample_snapshot()).ok)
		finish(false)
		return
	if "--restart-read" in OS.get_cmdline_user_args():
		var restarted := Saves.read_slot(6)
		check("separate process restores disk save", restarted.ok and restarted.data.state.coins == 83 and restarted.data.state.cook_left == 1.75 and restarted.data.world.weather == "rain")
		finish()
		return
	clean_slots()
	for slot in range(1, 7):
		check("empty slot " + str(slot), Saves.read_slot(slot).ok and Saves.read_slot(slot).empty)
	check("out of range slots rejected", not Saves.read_slot(0).ok and not Saves.read_slot(7).ok)
	var snapshot := sample_snapshot()
	check("snapshot accepted", not Saves.normalize_snapshot(snapshot).is_empty())
	check("save night in slot 4", Saves.write_slot(4, snapshot).ok)
	var loaded := Saves.read_slot(4)
	var restored := State.new()
	check("deserialize state", loaded.ok and restored.restore_save_data(loaded.data.state))
	for field in State.SAVE_FIELDS:
		check("round trip " + field, restored.get(field) == snapshot.state[field])
	var fresh := State.new()
	check("starter tools belong to each new game", fresh.tools == State.STARTING_TOOLS and fresh.tools.hoe == 1 and restored.tools.hoe == 0)
	var legacy := snapshot.duplicate(true)
	legacy.state.erase("tools")
	var migrated := State.normalize_save_data(legacy.state)
	check("legacy saves receive starter tools without losing inventory", not migrated.is_empty() and migrated.tools == State.STARTING_TOOLS and migrated.raw == snapshot.state.raw and migrated.resources == snapshot.state.resources and migrated.coins == snapshot.state.coins)
	restored.end_phase()
	restored.next_day()
	check("tool ownership persists across days", restored.tools == snapshot.state.tools)
	check("other slots remain empty", Saves.read_slot(1).empty and Saves.read_slot(6).empty)
	var invalid := snapshot.duplicate(true)
	invalid.state.tools.axe = 2
	check("stacked tools rejected", not Saves.write_slot(4, invalid).ok)
	invalid = snapshot.duplicate(true)
	invalid.state.tools.pickaxe = 0.5
	check("fractional tools rejected", not Saves.write_slot(4, invalid).ok)
	invalid = snapshot.duplicate(true)
	invalid.state.tools.erase("watering_can")
	check("incomplete tool data rejected", not Saves.write_slot(4, invalid).ok)
	invalid = snapshot.duplicate(true)
	invalid.state.raw = [13, 0, 0]
	check("oversized inventory rejected", not Saves.write_slot(4, invalid).ok)
	invalid = snapshot.duplicate(true)
	invalid.state.customers[1].seat = 0
	check("duplicate customer seats rejected", not Saves.write_slot(4, invalid).ok)
	invalid = snapshot.duplicate(true)
	invalid.world.position = [99999, 130]
	check("invalid world position rejected", not Saves.write_slot(4, invalid).ok)
	invalid = snapshot.duplicate(true)
	invalid.state.materials[0] = 1.5
	check("fractional inventory rejected", not Saves.write_slot(4, invalid).ok)
	snapshot.state.coins = 84
	check("second write succeeds", Saves.write_slot(4, snapshot).ok)
	check("previous save backed up", FileAccess.file_exists(Saves.slot_path(4) + ".bak"))
	corrupt(Saves.slot_path(4), "broken save")
	var backup := Saves.read_slot(4)
	check("corrupt primary recovers backup", backup.ok and backup.recovered and backup.data.state.coins == 83)
	check("recovered slot can start", Saves.begin_slot(4).ok)
	snapshot.state.coins = 85
	check("recovered save can be rewritten", Saves.write_slot(4, snapshot).ok)
	corrupt(Saves.slot_path(4), "broken again")
	check("good backup survives recovery write", Saves.read_slot(4).data.state.coins == 83)
	Saves.write_slot(4, snapshot)
	var envelope = JSON.parse_string(FileAccess.get_file_as_string(Saves.slot_path(4)))
	envelope.version = 99
	corrupt(Saves.slot_path(4), JSON.stringify(envelope))
	check("future version rejected without old fallback", not Saves.read_slot(4).ok and Saves.read_slot(4).code == "version")
	check("future version never overwritten", not Saves.write_slot(4, snapshot).ok)
	var blocked_path := Saves.directory.path_join("blocked")
	corrupt(blocked_path, "file blocks directory")
	var directory_before := Saves.directory
	Saves.directory = blocked_path
	check("disk errors reported", not Saves.write_slot(1, snapshot).ok)
	Saves.directory = directory_before
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_path))
	clean_slots()
	# Seed one occupied slot and leave the remaining five empty for visual QA.
	Saves.write_slot(4, sample_snapshot())
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(5)
	await click(menu.buttons[0], menu.viewport)
	check("start opens slot selection", menu.modal == "slots" and menu.slot_buttons.size() == 6)
	for index in range(6):
		check("three rows two columns " + str(index), menu.slot_buttons[index].position == Vector2(22 + index % 2 * 258, 68 + index / 2 * 68))
	await shot("save_slots", menu.viewport)
	await key(KEY_D)
	check("keyboard selects right slot", menu.viewport.gui_get_focus_owner() == menu.slot_buttons[1])
	await key(KEY_S)
	check("keyboard selects next row", menu.viewport.gui_get_focus_owner() == menu.slot_buttons[3])
	await key(KEY_ESCAPE)
	check("escape returns from slot screen", menu.modal.is_empty() and current_scene == menu)
	await click(menu.buttons[0], menu.viewport)
	await click(menu.slot_buttons[0], menu.viewport)
	await create_timer(0.45).timeout
	lane = current_scene
	loop = lane.get_node("GameLoop")
	lane.automation = true
	loop.paused_for_test = true
	check("empty slot starts new day", Saves.active_slot == 1 and loop.state.day == 1 and loop.state.coins == 0)
	check("new game written to selected slot", not Saves.read_slot(1).empty and Saves.read_slot(4).data.state.coins == 83)
	# Complete the mandatory new-game opening before testing ordinary pause controls.
	loop.campaign_controller.finish_intro()
	await frames()
	loop.campaign_controller.naming.request_confirmation()
	loop.campaign_controller.naming._confirm()
	await frames()
	check("new-game naming completes before pause controls", not paused and not loop.state.campaign.player_name.is_empty())
	loop.state.coins = 47
	loop.state.resources.iron = 3
	loop.state.raw = [2, 1, 0]
	loop.enter("home")
	lane.player.position = Vector2(310, 405)
	lane.facing = 3
	lane.weather.set_weather("snow")
	await key(KEY_ESCAPE)
	check("escape opens pause menu", loop.save_menu.open and paused)
	var remaining: float = loop.state.remaining
	loop.paused_for_test = false
	await create_timer(0.15).timeout
	check("pause freezes gameplay timer", loop.state.remaining == remaining)
	await click(loop.save_menu.panel.get_node("Save"), lane.viewport)
	var manually_saved: Dictionary = Saves.read_slot(1).data
	check("manual save persists current inventory", manually_saved.state.coins == 47 and manually_saved.state.resources.iron == 3 and Vector2(manually_saved.world.position[0], manually_saved.world.position[1]) == Vector2(310, 405) and "已保存到存档" in loop.save_menu.status.text)
	var indicator = loop.save_menu.indicator
	check("manual save shows corner icon above pause menu", indicator.visible and loop.save_menu.indicator_layer.layer > loop.hud.layer.layer)
	check("icon leaves hotbar clear and ignores input", indicator.get_rect().position == Vector2(564, 288) and indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE and indicator.caption.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var motion_before: float = indicator.motion_time
	await create_timer(0.15).timeout
	check("save animation continues while paused", paused and indicator.visible and indicator.motion_time > motion_before)
	await shot("save_pause", lane.viewport)
	var session_directory := Saves.directory
	var blocked_return := session_directory.path_join("blocked_return")
	corrupt(blocked_return, "file blocks directory")
	Saves.directory = blocked_return
	loop.save_menu.return_to_title()
	check("failed save keeps player in game", current_scene == lane and loop.save_menu.open and not loop.save_menu.leaving)
	await create_timer(1.05).timeout
	check("failed write shows failure instead of saved", indicator.visible and indicator.phase == "error" and indicator.caption.text == "保存失败")
	await shot("save_failed", lane.viewport)
	Saves.directory = session_directory
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_return))
	await click(loop.save_menu.panel.get_node("SaveAndReturn"), lane.viewport)
	await create_timer(1.65).timeout
	await frames(8)
	menu = current_scene
	check("save and return reaches title unpaused", menu.scene_file_path == "res://Scenes/MainMenu/main_menu.tscn" and not paused and Saves.active_slot == 0)
	await click(menu.buttons[0], menu.viewport)
	await shot("save_slots_occupied", menu.viewport)
	await click(menu.slot_buttons[0], menu.viewport)
	await create_timer(0.45).timeout
	lane = current_scene
	loop = lane.get_node("GameLoop")
	lane.automation = true
	loop.paused_for_test = true
	check("slot reload restores inventory", loop.state.coins == 47 and loop.state.resources.iron == 3 and loop.state.raw == [2, 1, 0])
	check("slot reload restores map and position", loop.location == "home" and lane.player.position == Vector2(310, 405))
	check("slot reload restores weather and facing", lane.weather.get_weather() == "snow" and lane.facing == 3)
	for location in ["town", "field", "dock", "blacksmith", "store", "restaurant", "home"]:
		loop.enter(location)
		check("location save " + location, loop.save_progress().ok and Saves.read_slot(1).data.world.location == location)
	loop.state.coins = 48
	loop.autosave_left = 0.0
	loop.paused_for_test = false
	loop._process(0.05)
	loop.paused_for_test = true
	check("periodic autosave writes changes", Saves.read_slot(1).data.state.coins == 48)
	indicator = loop.save_menu.indicator
	check("autosave starts animated hat", indicator.visible and indicator.phase == "saving")
	await shot("save_autosave", lane.viewport)
	await create_timer(1.05).timeout
	check("successful save shows completion", indicator.visible and indicator.phase == "success" and indicator.caption.text == "已保存")
	await shot("save_completed", lane.viewport)
	await create_timer(0.65).timeout
	check("save icon fades away when idle", not indicator.visible and not indicator.is_processing())
	loop.end_phase()
	check("phase transition autosaves", Saves.read_slot(1).data.state.phase == "night" and Saves.read_slot(1).data.world.location == "restaurant")
	for location in ["town", "home", "blacksmith", "store", "restaurant"]:
		loop.enter(location)
		check("night location save " + location, loop.save_progress().ok and Saves.read_slot(1).data.world.location == location)
	loop.end_phase()
	check("settlement autosaves", Saves.read_slot(1).data.state.phase == "result")
	loop.end_phase()
	check("next day autosaves", Saves.read_slot(1).data.state.day == 2 and Saves.read_slot(1).data.state.phase == "day")
	loop.save_menu.show_menu()
	loop.save_menu.return_to_title()
	await create_timer(1.65).timeout
	await frames(8)
	menu = current_scene
	await click(menu.buttons[0], menu.viewport)
	await click(menu.slot_buttons[3], menu.viewport)
	await create_timer(0.45).timeout
	lane = current_scene
	loop = lane.get_node("GameLoop")
	lane.automation = true
	loop.paused_for_test = true
	check("occupied slot loads independent progress", Saves.active_slot == 4 and loop.state.day == 3 and loop.state.coins == 83)
	check("night cooking and customers restored", loop.state.cooking == 0 and loop.state.cook_left > 1.0 and loop.state.customers.size() == 2)
	check("consumed harvest resources restored", loop.state.resource_damage.get("field_tree_0") == 3 and loop.state.fish_catches.get("dock_fish_0") == 2)
	check("loading different slot preserves slot 1", Saves.read_slot(1).data.state.day == 2 and Saves.read_slot(1).data.state.coins == 48)
	await shot("loaded_night", lane.viewport)
	lane.queue_free()
	await frames(5)
	finish()

func finish(clean: bool = true) -> void:
	if clean:
		clean_slots()
	if FileAccess.file_exists(Preferences.file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("SAVE VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
