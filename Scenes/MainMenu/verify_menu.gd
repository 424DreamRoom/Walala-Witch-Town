extends SceneTree
## Exercises real GUI input, scene handoff and a separate preferences file.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://Scenes/MainMenu/Verification/"
var failures := 0
var menu
var capture := false

func _initialize() -> void:
	capture = "--menu-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("MENU TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func click(control: Control) -> void:
	var position: Vector2 = menu.container.position + control.get_global_rect().get_center() * menu.container.scale
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

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func popup_key(popup: PopupMenu, code: Key) -> void:
	# Popups own their input viewport, including embedded pixel-canvas windows.
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func shot(name: String) -> void:
	if not capture:
		return
	await create_timer(0.25).timeout
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = menu.viewport.get_texture().get_image()
	check("capture " + name, pixels.save_png(OUT + name + ".png") == OK)
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("preview " + name, pixels.save_png(OUT + name + "_2x.png") == OK)
	if name in ["main_menu", "main_menu_1080p", "main_menu_720p"]:
		var window_pixels: Image = root.get_texture().get_image()
		check("window capture " + name, window_pixels.save_png(OUT + name + "_window.png") == OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = "user://menu_verification_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://menu_verification_saves_%d" % OS.get_process_id()
	for suffix in ["", ".bak", ".tmp"]:
		var file_path: String = Saves.slot_path(1) + suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	if FileAccess.file_exists(Preferences.file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(6)
	await create_timer(0.85).timeout
	check("project starts at save notice", ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/MainMenu/startup_notice.tscn")
	check("game title", menu.canvas.get_node("GameTitle").text == "哗啦啦魔女镇")
	check("four requested buttons", menu.buttons.size() == 4 and menu.buttons.map(func(button): return button.text) == ["开始游戏", "设置", "鸣谢", "退出游戏"])
	for i in range(menu.buttons.size()):
		check("centered vertical button " + str(i), menu.buttons[i].position == Vector2(248, 180 + i * 32) and menu.buttons[i].size == Vector2(144, 24))
	check("start initially focused", menu.viewport.gui_get_focus_owner() == menu.buttons[0])
	await shot("main_menu")
	await key(KEY_S)
	check("keyboard moves down", menu.viewport.gui_get_focus_owner() == menu.buttons[1])
	await key(KEY_ENTER)
	check("keyboard opens settings", menu.modal == "settings")
	if menu.modal != "settings":
		menu._open_settings()
	check("modal blocks main buttons", menu.buttons.all(func(button): return button.disabled))
	menu.music_slider.value = 0.41
	menu.dialog.master_slider.value = 0.64
	menu.dialog.character_slider.value = 0.57
	menu.dialog.environment_slider.value = 0.38
	menu.dialog.ui_slider.value = 0.49
	await click(menu.dialog.master_slider)
	check("master volume uses mouse input", not is_equal_approx(menu.audio.master_volume, 0.64))
	menu.dialog.master_slider.value = 0.64
	check("five audio sliders", menu.dialog.page_controls[0].filter(func(control): return control is HSlider).size() == 5 and menu.dialog.get_node_or_null("MusicMute") == null and menu.dialog.get_node_or_null("EffectsMute") == null)
	var saved := Preferences.read()
	check("saved audio preferences", is_equal_approx(saved.get_value("audio", "music_volume"), 0.41) and is_equal_approx(saved.get_value("audio", "master_volume"), 0.64) and is_equal_approx(saved.get_value("audio", "character_volume"), 0.57) and is_equal_approx(saved.get_value("audio", "environment_volume"), 0.38) and is_equal_approx(saved.get_value("audio", "ui_volume"), 0.49))
	await shot("settings")
	check("five settings categories", menu.dialog.tabs.size() == 5)
	await click(menu.dialog.get_node("DisplayTab"))
	check("category switches content", menu.dialog.selected_page == 1 and menu.fullscreen_toggle.visible and not menu.music_slider.visible)
	if capture:
		await click(menu.dialog.resolution)
		await popup_key(menu.dialog.resolution.get_popup(), KEY_ESCAPE)
		check("Esc dismisses dropdown before settings", menu.modal == "settings" and not menu.dialog.resolution.get_popup().visible)
	var limit: OptionButton = menu.dialog.get_node("FrameLimit")
	if capture:
		await click(limit)
		check("dropdown opens with mouse", limit.get_popup().visible)
		await shot("settings_dropdown")
		await popup_key(limit.get_popup(), KEY_S)
		await popup_key(limit.get_popup(), KEY_ENTER)
	else:
		limit.select(0)
		limit.item_selected.emit(0)
	check("frame limit applies immediately", Engine.max_fps == 30 and Preferences.read().get_value("display", "frame_limit") == 30)
	await click(menu.dialog.get_node("VSync"))
	check("vsync preference persists", not Preferences.read().get_value("display", "vsync"))
	if not capture:
		await click(menu.fullscreen_toggle)
		check("fullscreen disables window sizing", Preferences.read().get_value("display", "fullscreen") and menu.dialog.resolution.disabled)
		await click(menu.fullscreen_toggle)
	else:
		menu.dialog.resolution.select(1)
		menu.dialog.resolution.item_selected.emit(1)
		await create_timer(0.15).timeout
		check("window size actually changes", root.size == Vector2i(1600, 900))
	await shot("settings_display")
	await click(menu.dialog.get_node("ResetPage"))
	check("display defaults restore", Engine.max_fps == 60 and Preferences.read().get_value("display", "vsync") and not menu.dialog.fullscreen_toggle.button_pressed)
	await click(menu.dialog.get_node("GameTab"))
	var speed: OptionButton = menu.dialog.get_node("DialogueSpeed")
	if capture:
		await click(speed)
		for i in range(4): await popup_key(speed.get_popup(), KEY_S)
		await popup_key(speed.get_popup(), KEY_ENTER)
	else:
		speed.select(3)
		speed.item_selected.emit(3)
	await click(menu.dialog.get_node("AutoRun"))
	await click(menu.dialog.get_node("ShowHotbar"))
	check("text motion defaults enabled", menu.dialog.get_node("TextJump").button_pressed and menu.dialog.get_node("TextSway").button_pressed)
	await click(menu.dialog.get_node("TextJump"))
	await click(menu.dialog.get_node("TextSway"))
	check("text motion preferences persist from title settings", not Preferences.read().get_value("game", "text_jump", true) and not Preferences.read().get_value("game", "text_sway", true))
	check("game preferences persist", Preferences.dialogue_speed() == 0.0 and Preferences.value("game", "auto_run", false) and not Preferences.value("game", "show_hotbar", true))
	await shot("settings_game")
	await click(menu.dialog.get_node("ResetPage"))
	check("reset affects only current page", Preferences.dialogue_speed() == 30.0 and not Preferences.value("game", "auto_run", true) and Preferences.value("game", "show_hotbar", false) and is_equal_approx(menu.audio.music_volume, 0.41))
	check("game reset restores text motion", Preferences.text_jump_enabled() and Preferences.text_sway_enabled() and menu.dialog.get_node("TextJump").button_pressed and menu.dialog.get_node("TextSway").button_pressed)
	await click(menu.dialog.get_node("ControlsTab"))
	check("shortcut page has editable bindings", not menu.dialog.reset_button.disabled and menu.dialog.binding_buttons.size() == root.get_node("InputBindings").ACTIONS.size() and not menu.dialog.get_node("AutoRun").visible)
	await shot("settings_controls")
	await key(KEY_ESCAPE)
	check("escape closes and restores focus", menu.modal.is_empty() and menu.viewport.gui_get_focus_owner() == menu.buttons[1])
	await click(menu.buttons[1])
	check("settings retain values", is_equal_approx(menu.music_slider.value, 0.41) and is_equal_approx(menu.dialog.master_slider.value, 0.64) and is_equal_approx(menu.dialog.character_slider.value, 0.57) and is_equal_approx(menu.dialog.environment_slider.value, 0.38) and is_equal_approx(menu.dialog.ui_slider.value, 0.49))
	await click(menu.dialog.get_node("Back"))
	await click(menu.buttons[2])
	check("credits button opens scrollable text", menu.modal == "credits" and menu.credits_text.scroll_active)
	check("credits include existing sources", "Kenney" in menu.credits_text.text and "TakWolf" in menu.credits_text.text and "Godot" in menu.credits_text.text)
	await shot("credits")
	menu.credits_text.scroll_to_line(menu.credits_text.get_line_count() - 1)
	await shot("credits_bottom")
	await click(menu.dialog.get_node("Back"))
	await click(menu.buttons[3])
	check("quit asks for confirmation", menu.modal == "quit" and menu.viewport.gui_get_focus_owner().name == "CancelQuit")
	await shot("quit")
	await click(menu.dialog.get_node("CancelQuit"))
	check("quit cancel returns to menu", menu.modal.is_empty() and is_instance_valid(menu))
	# Test a saved display setting without changing the user's desktop window.
	if DisplayServer.get_name() == "headless":
		Preferences.set_fullscreen(true)
		check("display preference persisted", Preferences.read().get_value("display", "fullscreen"))
		Preferences.set_fullscreen(false)
	if capture:
		root.size = Vector2i(1920, 1080)
		await create_timer(0.2).timeout
		check("integer 1080p scale", menu.container.scale * Vector2(root.size) / root.get_visible_rect().size == Vector2(3, 3))
		await shot("main_menu_1080p")
		root.size = Vector2i(1280, 720)
		await create_timer(0.2).timeout
		check("integer 720p scale", menu.container.scale * Vector2(root.size) / root.get_visible_rect().size == Vector2(2, 2))
		await shot("main_menu_720p")
	if "--menu-only" in OS.get_cmdline_user_args():
		menu.audio.stop()
		await create_timer(0.05).timeout
		menu.queue_free()
		await frames(4)
		finish()
		return
	await click(menu.buttons[0])
	check("start opens six save slots", menu.modal == "slots" and menu.slot_buttons.size() == 6)
	check("save slots have no operation instructions", menu.slot_status.text.is_empty() and not menu.dialog.find_children("*", "Label", true, false).any(func(label): return "Enter" in label.text or "Esc" in label.text or "点击" in label.text or "选择已有存档" in label.text))
	for index in range(6):
		check("three rows two columns " + str(index), menu.slot_buttons[index].position == Vector2(22 + (index % 2) * 258, 68 + (index / 2) * 68))
	await shot("save_slots")
	await click(menu.slot_buttons[0])
	await create_timer(0.55).timeout
	await frames(6)
	var lane := current_scene
	check("start enters gameplay scene", lane != null and lane.scene_file_path == "res://Scenes/LanternLane/lantern_lane.tscn")
	if lane != null and lane.has_node("GameLoop"):
		lane.automation = true
		var loop = lane.get_node("GameLoop")
		loop.paused_for_test = true
		check("gameplay ready outside home", lane.player != null and loop.state.day == 1 and loop.location == "farm" and lane.player.position == loop.HOME_EXIT_POSITION)
		check("audio preferences survive scene change", is_equal_approx(loop.audio.music_volume, 0.41) and is_equal_approx(loop.audio.master_volume, 0.64) and is_equal_approx(loop.audio.character_volume, 0.57) and is_equal_approx(loop.audio.environment_volume, 0.38) and is_equal_approx(loop.audio.ui_volume, 0.49))
	else:
		check("gameplay ready", false)
	lane.queue_free()
	await frames(4)
	await create_timer(0.1).timeout
	finish()

func finish() -> void:
	Saves.end_session()
	for suffix in ["", ".bak", ".tmp"]:
		var file_path: String = Saves.slot_path(1) + suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("MENU VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
