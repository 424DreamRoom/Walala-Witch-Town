extends SceneTree
## Verify launch order, real input, timing, localization and save isolation.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const NOTICE := "res://Scenes/MainMenu/startup_notice.tscn"
const MENU := "res://Scenes/MainMenu/main_menu.tscn"
const OUT := "res://output/startup_notice/"
var failures := 0
var capture := false
var notice

func _initialize() -> void:
	# Isolate settings before the autoloads read them during startup.
	Preferences.file_path = "user://startup_verification_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://startup_verification_saves_%d" % OS.get_process_id()
	capture = "--startup-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("STARTUP TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func shot(name: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = notice.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + name, pixels.save_png(OUT + name + ".png") == OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ignore := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
	ignore.close()
	ignore = null
	check("project launches notice before title", ProjectSettings.get_setting("application/run/main_scene") == NOTICE)
	notice = load(NOTICE).instantiate()
	root.add_child(notice)
	current_scene = notice
	await frames()
	check("notice is the first visible scene", current_scene == notice and notice.heading.text == "关于保存")
	notice._enter_menu()
	check("launch input cannot dismiss the notice immediately", not notice.transitioning and notice.continue_button.disabled)
	await create_timer(1.4).timeout
	check("continue becomes available after short read", not notice.continue_button.disabled and notice.viewport.gui_get_focus_owner() == notice.continue_button)
	notice.set_process(false)
	var motion_before: float = notice.icon.motion_time
	await create_timer(0.2).timeout
	check("demo uses animated hat without a false saving label", notice.icon.motion_time > motion_before and not notice.icon.caption.visible and not notice.icon.result_received)
	check("notice never creates a save slot", Saves.active_slot == 0 and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(Saves.directory)))
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		await frames()
		check("translated title " + locale, notice.heading.text == tr("关于保存"))
		for i in range(notice.paragraphs.size()):
			var paragraph: Label = notice.paragraphs[i]
			check("translated body fits " + locale + " " + str(i), paragraph.text == tr(notice.COPY[i]) and paragraph.get_minimum_size().x <= paragraph.size.x and paragraph.get_minimum_size().y <= paragraph.size.y)
		await shot(locale)
	root.get_node("Localization").set_language("zh_CN", false)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await frames(5)
		var factor := float(resolution.x) / 640.0
		check("native canvas stays centered " + str(resolution.x), notice.container.scale * Vector2(root.size) / root.get_visible_rect().size == Vector2.ONE * factor and notice.container.position == Vector2.ZERO)
		await shot("size_" + str(resolution.x))
	root.size = Vector2i(1280, 720)
	await frames(5)
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
		await frames()
	await create_timer(0.5).timeout
	check("continue enters main menu", current_scene.scene_file_path == MENU and current_scene.get("buttons").size() == 4)
	check("main menu does not repeat the launch notice", current_scene.get_node_or_null("StartupNotice") == null)
	current_scene.queue_free()
	await frames(5)
	notice = load(NOTICE).instantiate()
	root.add_child(notice)
	current_scene = notice
	await create_timer(7.1).timeout
	await frames(5)
	check("notice automatically advances without input", current_scene.scene_file_path == MENU and current_scene.get("buttons").size() == 4)
	current_scene.queue_free()
	await frames(5)
	notice = null
	if FileAccess.file_exists(Preferences.file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("STARTUP VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
