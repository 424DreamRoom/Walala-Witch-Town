extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const OUT := "res://output/controller/"
var pad
var bindings
var menu
var lane
var loop
var failures := 0
var capture := false

func _initialize() -> void:
	var fixture := "test_%d" % OS.get_process_id()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="): fixture = argument.trim_prefix("--fixture=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = OUT + fixture + ".cfg"
	Saves.directory = OUT + fixture + "_saves"
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("CONTROLLER TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press(index: int) -> void:
	button(index, true)
	await frames()
	button(index, false)
	await frames()

func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func shot(name: String, viewport: SubViewport) -> void:
	if not capture: return
	await create_timer(0.3).timeout
	await frames()
	RenderingServer.force_draw(false)
	var pixels := viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + name, pixels.save_png(OUT + name + ".png") == OK)

func set_layout(kind: String) -> void:
	pad._release_controller()
	pad.set_layout(kind)
	# InputMap uses all-device fallback when no hardware is attached.
	# Also install a synthetic device if the host has actual controllers.
	if not Input.get_connected_joypads().is_empty(): pad.map_device(0, kind)

func run() -> void:
	pad = root.get_node("ControllerInput")
	bindings = root.get_node("InputBindings")
	print("CONTROLLER HARDWARE ", Input.get_connected_joypads())
	if "--write" in OS.get_cmdline_user_args():
		pad.set_layout("switch")
		pad.set_deadzone(0.3)
		check("write keyboard preference", bindings.assign_key("interact", 0, KEY_F).ok)
		check("controller settings saved", Preferences.read().get_value("controller", "layout") == "switch")
		print("CONTROLLER VERIFY END failures=", failures)
		quit(failures)
		return
	if "--read" in OS.get_cmdline_user_args():
		check("fresh process restores layout", pad.layout == "switch")
		check("fresh process restores deadzone", is_equal_approx(pad.deadzone, 0.3))
		check("fresh process preserves keyboard", bindings.bindings.interact[0] == KEY_F)
		print("CONTROLLER VERIFY END failures=", failures)
		quit(failures)
		return
	check("DualSense detection", pad.family("Sony DualSense Wireless Controller") == "playstation")
	check("DualShock detection", pad.family("PS4 Controller") == "playstation")
	check("Sony vendor detection", pad.family("Unknown", 0x054c) == "playstation")
	check("Xbox detection", pad.family("Xbox Series X Controller") == "xbox")
	check("Switch Pro detection", pad.family("Nintendo Switch Pro Controller") == "switch")
	check("Joy-Con pair detection", pad.family("Joy-Con (L/R)") == "switch")
	check("Nintendo vendor detection", pad.family("Unknown", 0x057e) == "switch")
	check("generic normalized fallback", pad.family("Generic XInput") == "xbox")
	for action in pad.OWNED:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: InputMap.action_erase_event(action, event)
	pad.map_device(0, "playstation")
	pad.map_device(1, "switch")
	var mapped := InputEventJoypadButton.new()
	mapped.pressed = true
	mapped.device = 0
	mapped.button_index = JOY_BUTTON_A
	check("simultaneous PlayStation confirm", mapped.is_action_pressed("ui_accept") and not mapped.is_action_pressed("ui_cancel"))
	mapped.device = 1
	check("simultaneous Switch cancel stays device-specific", mapped.is_action_pressed("ui_cancel") and not mapped.is_action_pressed("ui_accept"))
	mapped.button_index = JOY_BUTTON_B
	check("simultaneous Switch confirm stays device-specific", mapped.is_action_pressed("ui_accept") and not mapped.is_action_pressed("ui_cancel"))
	pad.rebuild_mappings()
	Preferences.set_value("controller", "layout", "invalid")
	Preferences.set_value("controller", "deadzone", "bad")
	pad.reload_settings()
	check("invalid settings recover", pad.layout == "auto" and is_equal_approx(pad.deadzone, 0.24))
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(8)
	for kind in ["xbox", "playstation", "switch"]:
		set_layout(kind)
		var accept: int = JOY_BUTTON_B if kind == "switch" else JOY_BUTTON_A
		var cancel: int = JOY_BUTTON_A if kind == "switch" else JOY_BUTTON_B
		menu.buttons[0].grab_focus()
		await press(JOY_BUTTON_DPAD_DOWN)
		check(kind + " menu direction", menu.viewport.gui_get_focus_owner() == menu.buttons[1])
		await press(accept)
		check(kind + " opens settings", menu.modal == "settings")
		if menu.modal != "settings": quit(1); return
		menu.dialog.select_page(4)
		check(kind + " settings reflect actual confirm", menu.dialog.controller_values.ui_accept.text == pad.button_text("interact"))
		for locale in ["zh_CN", "en", "ja", "zh_TW"]:
			root.get_node("Localization").set_language(locale)
			await shot(kind + "_settings_" + locale, menu.viewport)
		menu.dialog.get_node("ControllerBindingsScroll").scroll_vertical = 1000
		await shot(kind + "_settings_pointer", menu.viewport)
		await press(cancel)
		check(kind + " cancel restores focus", menu.modal.is_empty() and menu.viewport.gui_get_focus_owner() == menu.buttons[1])
		await press(JOY_BUTTON_START)
		check(kind + " menu button does not confirm", menu.modal.is_empty())
	set_layout("xbox")
	menu.buttons[0].grab_focus()
	axis(JOY_AXIS_LEFT_Y, 1.0)
	await frames(6)
	check("left stick navigates menu", menu.viewport.gui_get_focus_owner() == menu.buttons[1])
	await create_timer(0.43).timeout
	check("held stick repeats", menu.viewport.gui_get_focus_owner() != menu.buttons[1])
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames()
	menu.buttons[1].grab_focus()
	await press(JOY_BUTTON_A)
	menu.dialog.select_page(3)
	menu.dialog._begin_capture("interact", 0)
	await frames()
	await press(JOY_BUTTON_B)
	check("controller cancels keyboard capture", not bindings.capture_active and menu.modal == "settings")
	await press(JOY_BUTTON_B)
	menu.audio.stop()
	menu.queue_free()
	await frames(5)
	Saves.begin_slot(1)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(10)
	loop = lane.get_node("GameLoop")
	# Quick transfer between backpack rows needs an unlocked second row.
	loop.state.equipment.bag = 1
	Items.ensure_bag(loop.state)
	lane.automation = false
	loop.paused_for_test = true
	var start: Vector2 = lane.player.position
	axis(JOY_AXIS_LEFT_X, 0.1)
	for index in range(10): await physics_frame
	check("deadzone prevents drift", lane.player.position.distance_to(start) < 0.1)
	axis(JOY_AXIS_LEFT_X, 0.62)
	for index in range(20): await physics_frame
	axis(JOY_AXIS_LEFT_X, 0.0)
	var analog_distance: float = lane.player.position.distance_to(start)
	check("partial stick preserves analog speed", analog_distance > 8.0 and analog_distance < 23.0)
	lane.player.position = start
	axis(JOY_AXIS_LEFT_X, 1.0)
	axis(JOY_AXIS_LEFT_Y, -1.0)
	for index in range(20): await physics_frame
	axis(JOY_AXIS_LEFT_X, 0.0)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	check("diagonal speed capped", absf(lane.player.position.distance_to(start) - 30.0) < 4.0)
	check("movement does not steal HUD focus", loop.hud.mode.is_empty() and not paused)
	lane.player.position = start
	button(JOY_BUTTON_LEFT_STICK, true)
	axis(JOY_AXIS_LEFT_X, 1.0)
	for index in range(20): await physics_frame
	axis(JOY_AXIS_LEFT_X, 0.0)
	button(JOY_BUTTON_LEFT_STICK, false)
	check("stick click runs", absf(lane.player.position.distance_to(start) - 140.0 / 3.0) < 4.0)
	for kind in ["xbox", "playstation", "switch"]:
		set_layout(kind)
		var accept: int = JOY_BUTTON_B if kind == "switch" else JOY_BUTTON_A
		var cancel: int = JOY_BUTTON_A if kind == "switch" else JOY_BUTTON_B
		var bag: int = JOY_BUTTON_Y if kind == "switch" else JOY_BUTTON_X
		loop.enter("field")
		loop.state.nodes[0] = 2
		lane.player.position = loop.area.points[0]
		await frames()
		var before: int = loop.state.raw[0]
		await press(accept)
		check(kind + " world interaction", loop.state.raw[0] == before + 1)
		await press(bag)
		check(kind + " bag pauses", loop.hud.mode == "bag" and paused)
		if loop.hud.mode != "bag": quit(1); return
		var chest = loop.hud.chest_view
		var occupied := -1
		for index in range(loop.state.bag_slots.size()):
			if not loop.state.bag_slots[index].is_empty(): occupied = index; break
		chest.bag_slots[occupied].grab_focus()
		await press(accept)
		check(kind + " confirm picks inventory stack", not chest.session.hand.is_empty() and loop.hud.mode == "bag")
		await press(accept)
		check(kind + " confirm returns inventory stack", chest.session.hand.is_empty())
		Items.change(loop.state, {"mushroom": 4})
		var mushroom_slot := -1
		for index in range(loop.state.bag_slots.size()):
			if loop.state.bag_slots[index].get("id", "") == "mushroom": mushroom_slot = index; break
		chest.refresh_language()
		chest.bag_slots[mushroom_slot].grab_focus()
		var stack_count: int = loop.state.bag_slots[mushroom_slot].count
		await press(JOY_BUTTON_X if kind == "switch" else JOY_BUTTON_Y)
		check(kind + " splits focused stack", chest.session.hand.get("count", 0) == ceili(stack_count / 2.0))
		await press(accept)
		chest.bag_slots[mushroom_slot].grab_focus()
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		check(kind + " quick transfers focused stack", loop.state.bag_slots[mushroom_slot].is_empty() and chest.session.hand.is_empty())
		await press(cancel)
		check(kind + " closes bag", loop.hud.mode.is_empty() and not paused)
		await press(JOY_BUTTON_BACK)
		check(kind + " opens map", loop.hud.mode == "map")
		await press(cancel)
		await press(JOY_BUTTON_LEFT_SHOULDER)
		check(kind + " opens journal", loop.hud.mode == "campaign")
		await press(cancel)
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		check(kind + " opens guide dialogue", loop.hud.mode == "dialogue")
		await press(accept)
		check(kind + " reveals dialogue", loop.hud.dialogue_text.visible_characters == loop.hud.dialogue_text.get_total_character_count())
		await press(JOY_BUTTON_X if kind == "switch" else JOY_BUTTON_Y)
		check(kind + " dialogue history", loop.hud.history_panel.visible)
		await press(cancel)
		await press(JOY_BUTTON_START)
		check(kind + " pauses", loop.save_menu.open and paused)
		var position: Vector2 = lane.player.position
		axis(JOY_AXIS_LEFT_X, 1.0)
		await frames(8)
		axis(JOY_AXIS_LEFT_X, 0.0)
		check(kind + " pause freezes player", lane.player.position == position)
		await press(cancel)
	set_layout("xbox")
	loop.hud.start_dialogue("", "res://Art/Character/Storybook/WalalaWitch/walala-witch.aseprite", ["你好。"], [{"text": "继续", "action": loop.hud.close_modal}])
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_A)
	check("controller confirms dialogue choice", loop.hud.mode.is_empty())
	loop.enter("home")
	loop.builder.open_catalog()
	loop.builder._room("place")
	loop.builder.cursor = Vector2(400, 368)
	var before_cursor: Vector2 = loop.builder.cursor
	await press(JOY_BUTTON_DPAD_RIGHT)
	check("building D-pad moves one grid", loop.builder.cursor.x == before_cursor.x + loop.builder.Catalog.GRID)
	axis(JOY_AXIS_LEFT_X, -1.0)
	await frames(6)
	axis(JOY_AXIS_LEFT_X, 0.0)
	check("building left stick moves one grid", loop.builder.cursor == before_cursor)
	loop.builder.close()
	var original: Vector2 = pad.pointer_position
	axis(JOY_AXIS_RIGHT_X, 1.0)
	await frames(8)
	axis(JOY_AXIS_RIGHT_X, 0.0)
	check("right stick moves pointer", pad.pointer_active and pad.pointer_position != original)
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames()
	check("trigger presses virtual mouse", pad.mouse_buttons == MOUSE_BUTTON_MASK_LEFT)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check("trigger release clears virtual mouse", pad.mouse_buttons == 0)
	loop.enter("restaurant")
	await frames()
	var container: SubViewportContainer = lane.viewport.get_parent()
	pad.pointer_position = container.global_position + loop.menu_buttons[0].get_global_rect().get_center() * container.scale
	pad.pointer_active = true
	var was_selected: bool = loop.state.menu[0]
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames()
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await frames()
	check("trigger operates mouse-only restaurant UI", loop.state.menu[0] != was_selected)
	axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	pad._connection_changed(0, false)
	check("disconnect releases input and pointer", not pad.using_controller and pad.mouse_buttons == 0 and not Input.is_action_pressed("move_right"))
	pad._connection_changed(0, true)
	await press(JOY_BUTTON_BACK)
	check("reconnect restores controller mapping", loop.hud.mode == "map")
	await press(JOY_BUTTON_B)
	await key(KEY_W)
	axis(JOY_AXIS_LEFT_X, 0.0)
	check("keyboard restores input mode", not pad.using_controller)
	check("keyboard remapping still works", bindings.assign_key("interact", 0, KEY_F).ok)
	pad.set_layout("switch")
	check("layout preserves keyboard remap", bindings.bindings.interact[0] == KEY_F)
	check("save excludes controller settings", loop.save_progress().ok and not Saves.read_slot(1).data.state.has("controller"))
	lane.queue_free()
	await create_timer(0.2).timeout
	Saves.end_session()
	print("CONTROLLER VERIFY END failures=", failures)
	quit(failures)
