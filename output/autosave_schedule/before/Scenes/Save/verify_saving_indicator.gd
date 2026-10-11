extends SceneTree
## Isolated saving feedback checks; --indicator-capture also renders a preview.
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://output/saving_indicator/"
var failures := 0
var lane
var loop
var indicator
var capture := false

func _initialize() -> void:
	capture = "--indicator-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("INDICATOR TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func shot(name: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + name, lane.viewport.get_texture().get_image().save_png(OUT + name + ".png") == OK)

func run() -> void:
	Saves.directory = "user://saving_indicator_verification_%d" % OS.get_process_id()
	Preferences.file_path = "user://saving_indicator_preferences_%d.cfg" % OS.get_process_id()
	root.get_node("Localization").set_language("zh_CN", false)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	indicator = loop.save_menu.indicator
	check("scene preview does not show a false save", not loop.save_progress().ok and not indicator.visible)
	check("isolated slot opens", Saves.begin_slot(1).ok)
	Saves.consume_pending()
	loop.enter("home")
	paused = true
	await create_timer(1.7).timeout
	check("initial autosave cue finishes", not indicator.visible)
	check("manual disk write succeeds", loop.save_progress().ok and Saves.read_slot(1).ok)
	check("manual save starts cue above all menus", indicator.visible and loop.save_menu.indicator_layer.layer > loop.hud.layer.layer)
	var before: float = indicator.motion_time
	await create_timer(0.2).timeout
	check("animation advances while gameplay is paused", indicator.motion_time > before and paused)
	var icon_rect: Rect2 = indicator.get_rect()
	var hotbar_rect: Rect2 = loop.hud.base.get_node("InventorySlot11").get_rect()
	check("bottom right cue clears inventory", icon_rect.end == Vector2(628, 348) and not icon_rect.intersects(hotbar_rect))
	check("cue and text pass through mouse input", indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE and indicator.caption.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await create_timer(0.85).timeout
	check("successful save announces completion", indicator.phase == "success" and indicator.caption.text == "已保存")
	await shot("completed")
	await create_timer(0.65).timeout
	check("idle cue hides and stops processing", not indicator.visible and not indicator.is_processing())
	indicator.begin_save()
	await create_timer(1.05).timeout
	check("unfinished save keeps animating", indicator.visible and indicator.phase == "saving")
	indicator.finish_save(true)
	await frames()
	check("long save completes after result arrives", indicator.phase == "success")
	loop._autosave()
	check("another save restarts cue without hiding", indicator.visible and indicator.phase == "saving")
	await create_timer(1.7).timeout
	var good_directory: String = Saves.directory
	var blocker: String = Saves.directory.path_join("blocked")
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("blocks directory creation")
	file.close()
	file = null
	Saves.directory = blocker
	loop.save_menu.show_menu()
	loop.save_menu.return_to_title()
	check("write failure prevents leaving", not loop.save_menu.leaving and current_scene == lane)
	await create_timer(1.05).timeout
	check("real disk failure shows error cue", indicator.visible and indicator.phase == "error" and indicator.caption.text == "保存失败")
	await shot("failed")
	Saves.directory = good_directory
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	loop.save_menu.close_menu()
	paused = true
	loop._autosave()
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		check("translated cue " + locale, indicator.caption.text == tr("保存中") and indicator.caption.get_minimum_size().x <= indicator.size.x)
	root.get_node("Localization").set_language("zh_CN", false)
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
		var ignore := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
		ignore.close()
		indicator.begin_save()
		indicator.finish_save(true)
		indicator.set_process(false)
		for i in range(19):
			if i > 0: indicator._process(0.1)
			indicator.set_process(false)
			await shot("frames/%02d" % i)
			if i == 3: await shot("in_game")
		indicator.hide()
		loop.save_menu.show_menu()
		loop.save_menu.manual_save()
		await shot("paused")
		loop.save_menu.close_menu()
		paused = true
	loop.save_menu.return_to_title()
	check("exit freezes world while showing cue", paused and loop.save_menu.leaving and indicator.visible)
	await create_timer(1.7).timeout
	await frames(5)
	check("exit reaches title after cue", current_scene.scene_file_path == "res://Scenes/MainMenu/main_menu.tscn" and not paused and Saves.active_slot == 0)
	for suffix in ["", ".bak", ".tmp"]:
		var save_path: String = Saves.slot_path(1) + suffix
		if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	if FileAccess.file_exists(Preferences.file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	current_scene.queue_free()
	await frames(5)
	loop = null
	indicator = null
	lane = null
	print("SAVING INDICATOR VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
