extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/pause_menu/"
var lane

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = OUT + "saves_%d" % OS.get_process_id()
	Saves.end_session()
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func click(control: Control) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var position: Vector2 = container.position + control.get_global_rect().get_center() * container.scale
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

func shot(filename: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	pixels.save_png(OUT + filename + ".png")

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames()
	lane.automation = true
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("farm")
	Saves.active_slot = 1
	Saves.created_at = int(Time.get_unix_time_from_system())
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		loop.save_menu.show_menu()
		await shot("pause_" + locale)
		print("PAUSE CAPTURE ", locale, " BUTTONS ", loop.save_menu.panel.find_children("*", "Button", false, false).size(), " STATUS_VISIBLE ", loop.save_menu.status.visible)
		loop.save_menu.close_menu()
	root.get_node("Localization").set_language("zh_CN", false)
	loop.save_menu.show_menu()
	loop.save_menu.manual_save()
	await shot("pause_saved")
	await click(loop.save_menu.panel.get_node("Settings"))
	print("PAUSE CAPTURE SETTINGS_VISIBLE ", loop.audio.panel.visible)
	loop.save_menu.close_settings()
	print("PAUSE CAPTURE BEFORE RETURN ", loop.save_menu.leaving, " ACTIVE_FADE ", root.get_node("SceneTransition").active)
	await click(loop.save_menu.panel.get_node("SaveAndReturn"))
	await create_timer(2.0).timeout
	await frames()
	print("PAUSE CAPTURE RETURN_SCENE ", current_scene.scene_file_path, " PAUSED ", paused)
	if current_scene.scene_file_path != "res://Scenes/MainMenu/main_menu.tscn":
		quit(1)
		return
	current_scene.queue_free()
	await frames()
	Saves.end_session()
	print("PAUSE CAPTURE COMPLETE")
	quit()
