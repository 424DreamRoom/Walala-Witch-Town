extends SceneTree
## Exercises real GUI input, scene handoff and a separate preferences file.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://Art/UI/FramewrightLite/Verification/"
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

func shot(name: String) -> void:
	if not capture:
		return
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
	Preferences.file_path = "user://menu_verification.cfg"
	if FileAccess.file_exists(Preferences.file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(6)
	check("project starts at menu", ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/MainMenu/main_menu.tscn")
	check("game title", menu.canvas.get_node("GameTitle").text == "哗啦啦魔女镇")
	check("four requested buttons", menu.buttons.size() == 4 and menu.buttons.map(func(button): return button.text) == ["开始游戏", "设置", "鸣谢", "退出游戏"])
	for i in range(menu.buttons.size()):
		check("centered vertical button " + str(i), menu.buttons[i].position == Vector2(232, 168 + i * 38) and menu.buttons[i].size == Vector2(176, 30))
	check("start initially focused", menu.viewport.gui_get_focus_owner() == menu.buttons[0])
	await shot("main_menu")
	await key(KEY_DOWN)
	check("keyboard moves down", menu.viewport.gui_get_focus_owner() == menu.buttons[1])
	await key(KEY_ENTER)
	check("keyboard opens settings", menu.modal == "settings")
	if menu.modal != "settings":
		menu._open_settings()
	check("modal blocks main buttons", menu.buttons.all(func(button): return button.disabled))
	menu.music_slider.value = 0.41
	menu.effects_slider.value = 0.57
	await click(menu.dialog.get_node("MusicMute"))
	check("music mute uses mouse input", menu.audio.music_muted and menu.audio.music.stream_paused)
	var saved := Preferences.read()
	check("saved audio preferences", is_equal_approx(saved.get_value("audio", "music_volume"), 0.41) and is_equal_approx(saved.get_value("audio", "effects_volume"), 0.57) and saved.get_value("audio", "music_muted"))
	await shot("settings")
	await key(KEY_ESCAPE)
	check("escape closes and restores focus", menu.modal.is_empty() and menu.viewport.gui_get_focus_owner() == menu.buttons[1])
	await click(menu.buttons[1])
	check("settings retain values", is_equal_approx(menu.music_slider.value, 0.41) and menu.dialog.get_node("MusicMute").button_pressed)
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
	await create_timer(0.55).timeout
	await frames(6)
	var lane := current_scene
	check("start enters actual town scene", lane != null and lane.scene_file_path == "res://Scenes/LanternLane/lantern_lane.tscn")
	if lane != null and lane.has_node("GameLoop"):
		lane.automation = true
		var loop = lane.get_node("GameLoop")
		loop.paused_for_test = true
		check("gameplay ready", lane.player != null and loop.state.day == 1)
		check("audio preferences survive scene change", is_equal_approx(loop.audio.music_volume, 0.41) and is_equal_approx(loop.audio.effects_volume, 0.57) and loop.audio.music_muted)
	else:
		check("gameplay ready", false)
	lane.queue_free()
	await frames(4)
	finish()

func finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("MENU VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
