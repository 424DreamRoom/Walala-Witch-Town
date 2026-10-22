extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://Scenes/Input/Verification/"
var bindings
var menu
var lane
var loop
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("BINDINGS TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key) -> void:
	for pressed in [true, false]:
		send_key(code, pressed)
		await frames()

func click(control: Control, viewport: SubViewport) -> void:
	var container: SubViewportContainer = viewport.get_parent()
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

func shot(name: String, viewport: SubViewport) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels := viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + name, pixels.save_png(OUT + name + ".png") == OK)

func open_binding(panel, action: String, slot: int, viewport: SubViewport) -> void:
	var button: Button = panel.binding_buttons[action][slot]
	button.grab_focus()
	await frames(5)
	panel.get_node("BindingsScroll").ensure_control_visible(button)
	await frames()
	await click(button, viewport)
	check("mouse opens capture " + action, bindings.capture_active and panel.is_capturing())
	if not bindings.capture_active:
		quit(1)
		await frames()

func keyboard_keys(action: String) -> Array:
	var result := []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: result.append(event.physical_keycode)
	return result

func run() -> void:
	bindings = root.get_node("InputBindings")
	Preferences.file_path = "user://bindings_%d.cfg" % OS.get_process_id()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preferences="): Preferences.file_path = argument.trim_prefix("--preferences=")
	bindings.apply_saved_bindings()
	if "--write-preference" in OS.get_cmdline_user_args():
		Preferences.set_value("game", "language", "ja")
		check("write primary", bindings.assign_key("interact", 0, KEY_F).ok)
		check("write alternate", bindings.assign_key("interact", 1, KEY_G).ok)
		check("write map key", bindings.assign_key("map", 0, KEY_N).ok)
		print("BINDINGS VERIFY END failures=", failures)
		quit(failures)
		return
	if "--read-preference" in OS.get_cmdline_user_args():
		menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
		root.add_child(menu)
		await frames(5)
		check("fresh process restores both bindings", keyboard_keys("interact") == [KEY_F, KEY_G])
		check("fresh process restores map binding", keyboard_keys("map") == [KEY_N])
		check("fresh process preserves language", root.get_node("Localization").language == "ja")
		menu.audio.stop()
		menu.queue_free()
		await create_timer(0.15).timeout
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
		print("BINDINGS VERIFY END failures=", failures)
		quit(failures)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Saves.directory = "user://bindings_saves_%d" % OS.get_process_id()
	check("default game movement includes arrows", keyboard_keys("move_up") == [KEY_W, KEY_UP] and keyboard_keys("move_right") == [KEY_D, KEY_RIGHT])
	check("menu follows primary movement", keyboard_keys("ui_up") == [KEY_W] and keyboard_keys("ui_down") == [KEY_S])
	check("controller menu events retained", InputMap.action_get_events("ui_up").any(func(event): return event is InputEventJoypadButton))
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(5)
	menu._open_settings()
	await click(menu.dialog.get_node("ControlsTab"), menu.viewport)
	var panel = menu.dialog
	await frames(5)
	check("thirteen editable actions including map", panel.binding_buttons.size() == 13 and panel.binding_buttons.has("map") and not panel.reset_button.disabled)
	await shot("controls_zh_CN", menu.viewport)
	panel.binding_buttons.move_up[0].grab_focus()
	for index in range(14): await key(KEY_TAB)
	check("keyboard focus scrolls the mapping list", panel.get_node("BindingsScroll").scroll_vertical > 0 and menu.viewport.gui_get_focus_owner() == panel.binding_buttons.journal[0])
	await open_binding(panel, "interact", 0, menu.viewport)
	await shot("listening", menu.viewport)
	send_key(KEY_F, true)
	await frames()
	check("captured key applies without triggering action", bindings.bindings.interact == [KEY_F, 0] and not bindings.capture_active and not Input.is_action_pressed("interact") and menu.modal == "settings")
	send_key(KEY_F, false)
	await frames()
	check("primary persists", Preferences.read().get_value("input", "interact") == [KEY_F, 0])
	await open_binding(panel, "interact", 1, menu.viewport)
	await key(KEY_G)
	check("alternate applies", keyboard_keys("interact") == [KEY_F, KEY_G])
	await open_binding(panel, "bag", 0, menu.viewport)
	await key(KEY_ESCAPE)
	check("Esc cancels capture without closing settings", not bindings.capture_active and menu.modal == "settings" and bindings.bindings.bag[0] == KEY_B)
	await open_binding(panel, "bag", 0, menu.viewport)
	await key(KEY_F)
	check("conflict leaves both bindings unchanged", bindings.capture_active and bindings.conflict_action == "interact" and bindings.bindings.bag[0] == KEY_B and bindings.bindings.interact[0] == KEY_F)
	await shot("conflict", menu.viewport)
	await key(KEY_ENTER)
	check("keyboard confirms atomic swap", not bindings.capture_active and bindings.bindings.bag[0] == KEY_F and bindings.bindings.interact == [KEY_B, KEY_G])
	check("both swapped actions saved", Preferences.read().get_value("input", "bag")[0] == KEY_F and Preferences.read().get_value("input", "interact")[0] == KEY_B)
	await open_binding(panel, "bag", 0, menu.viewport)
	await key(KEY_B)
	await click(panel.retry_button, menu.viewport)
	await key(KEY_K)
	check("retry chooses a different key", not bindings.capture_active and bindings.bindings.bag[0] == KEY_K and bindings.bindings.interact[0] == KEY_B)
	await open_binding(panel, "bag", 0, menu.viewport)
	await key(KEY_ENTER)
	check("reserved menu key rejected", bindings.capture_active and not bindings.capture_error.is_empty() and bindings.bindings.bag[0] == KEY_K)
	await key(KEY_ESCAPE)
	await open_binding(panel, "bag", 0, menu.viewport)
	await key(KEY_E)
	check("wand toggle key reserved", bindings.capture_active and not bindings.capture_error.is_empty() and bindings.bindings.bag[0] == KEY_K)
	await key(KEY_ESCAPE)
	await open_binding(panel, "interact", 1, menu.viewport)
	await click(panel.clear_button, menu.viewport)
	check("alternate clears without removing primary", not bindings.capture_active and bindings.bindings.interact == [KEY_B, 0])
	await click(panel.reset_button, menu.viewport)
	check("restore defaults updates every action", bindings.bindings == bindings.defaults() and keyboard_keys("interact") == [KEY_F] and keyboard_keys("ui_up") == [KEY_W])
	check("same action keys exchange", bindings.assign_key("move_up", 0, KEY_UP).ok and bindings.bindings.move_up == [KEY_UP, KEY_W])
	bindings.reset_defaults()
	check("change interaction", bindings.assign_key("interact", 0, KEY_F).ok)
	check("reuse freed original key", bindings.assign_key("bag", 0, KEY_Q).ok)
	check("prompt replacement never cascades", bindings.prompt("F / B") == "F / Q")
	for locale in ["en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale)
		await frames()
		await shot("controls_" + locale, menu.viewport)
	root.get_node("Localization").set_language("zh_CN")
	bindings.reset_defaults()
	for item in [["move_up", KEY_I], ["move_right", KEY_P], ["run", KEY_CTRL], ["interact", KEY_F], ["bag", KEY_K], ["journal", KEY_O], ["guide", KEY_U], ["pause", KEY_F6], ["dialogue_next", KEY_Z], ["history", KEY_Y]]:
		check("set gameplay " + item[0], bindings.assign_key(item[0], 0, item[1]).ok)
	await open_binding(panel, "history", 1, menu.viewport)
	menu.audio.stop()
	menu.queue_free()
	await create_timer(0.15).timeout
	check("freeing capture owner cancels safely", not bindings.capture_active)
	check("isolated slot starts", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = false
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	check("scene handoff retains bindings", keyboard_keys("move_up") == [KEY_I, KEY_UP] and keyboard_keys("ui_up") == [KEY_I] and keyboard_keys("bag") == [KEY_K])
	var start: Vector2 = lane.player.position
	send_key(KEY_I, true)
	send_key(KEY_P, true)
	for index in range(20): await physics_frame
	send_key(KEY_I, false)
	send_key(KEY_P, false)
	await frames()
	check("remapped keys walk diagonally at normal speed", lane.player.position.distance_to(start + Vector2(1, -1).normalized() * 30.0) < 4)
	lane.player.position = start
	send_key(KEY_CTRL, true)
	send_key(KEY_I, true)
	send_key(KEY_P, true)
	for index in range(20): await physics_frame
	send_key(KEY_I, false)
	send_key(KEY_P, false)
	send_key(KEY_CTRL, false)
	await frames()
	check("remapped run modifier works diagonally", lane.player.position.distance_to(start + Vector2(1, -1).normalized() * (140.0 / 3.0)) < 4)
	await key(KEY_B)
	check("old bag key no longer opens bag", loop.hud.mode.is_empty())
	await key(KEY_K)
	check("new bag key opens and pauses", loop.hud.mode == "bag" and paused)
	await key(KEY_K)
	check("new bag key toggles closed", loop.hud.mode.is_empty() and not paused)
	await key(KEY_O)
	check("new journal key opens", loop.hud.mode == "campaign" and paused)
	await key(KEY_ESCAPE)
	check("Esc remains an emergency return", loop.hud.mode.is_empty() and not paused)
	await key(KEY_U)
	await key(KEY_Z)
	check("new dialogue key reveals full translated line", loop.hud.mode == "dialogue" and loop.hud.dialogue_text.visible_characters == loop.hud.dialogue_text.get_total_character_count())
	await key(KEY_Y)
	check("new history key opens history", loop.hud.history_panel.visible)
	check("dialogue has no operation prompts after rebinding", not loop.hud.modal.find_children("*", "Label", true, false).any(func(label): return "F / Z" in label.text or "F6" in label.text))
	await key(KEY_ESCAPE)
	loop.enter("field")
	lane.player.position = loop.area.points[0]
	await frames()
	var mushrooms: int = loop.state.raw[0]
	await key(KEY_E)
	check("old interaction key does nothing", loop.state.raw[0] == mushrooms)
	await key(KEY_F)
	check("new interaction key gathers ingredients", loop.state.raw[0] == mushrooms + 1)
	await key(KEY_F6)
	check("new pause key opens menu", loop.save_menu.open and paused)
	await click(loop.save_menu.panel.get_node("Settings"), lane.viewport)
	loop.audio.panel.select_page(3)
	panel = loop.audio.panel
	var before: Dictionary = loop.state.to_save_data().duplicate(true)
	var position: Vector2 = lane.player.position
	await open_binding(panel, "bag", 0, lane.viewport)
	await key(KEY_F6)
	check("pause key during capture checks conflict without leaving", bindings.capture_active and bindings.conflict_action == "pause" and panel.visible and loop.save_menu.open and paused)
	await key(KEY_ESCAPE)
	check("capture cancel preserves paused settings", not bindings.capture_active and panel.visible and loop.save_menu.open and paused)
	await open_binding(panel, "bag", 0, lane.viewport)
	await key(KEY_V)
	check("remapping freezes progress and position", loop.state.to_save_data() == before and lane.player.position == position and paused and bindings.bindings.bag[0] == KEY_V)
	await shot("controls_ingame", lane.viewport)
	await key(KEY_F6)
	check("mapped back returns to pause menu", loop.save_menu.panel.visible and not panel.visible and paused)
	await key(KEY_ESCAPE)
	check("Esc resumes game", not loop.save_menu.open and not paused)
	await key(KEY_V)
	check("remapping inside game applies immediately", loop.hud.mode == "bag")
	await key(KEY_V)
	check("progress save independent of bindings", loop.save_progress().ok and not Saves.read_slot(1).data.state.has("input"))
	lane.queue_free()
	await create_timer(0.15).timeout
	Saves.end_session()
	Preferences.set_value("audio", "music_volume", 0.41)
	Preferences.set_value("input", "move_up", [-1, KEY_UP])
	bindings.apply_saved_bindings()
	check("invalid configuration falls back safely", bindings.bindings == bindings.defaults())
	bindings.reset_defaults()
	check("reset preserves language and sound", Preferences.value("game", "language", "") == "zh_CN" and is_equal_approx(Preferences.value("audio", "music_volume", 0), 0.41))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	print("BINDINGS VERIFY END failures=", failures)
	quit(failures)
