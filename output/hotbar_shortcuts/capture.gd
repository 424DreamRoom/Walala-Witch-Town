extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/hotbar_shortcuts/"

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	run.call_deferred()

func run() -> void:
	var lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	for i in range(5): await process_frame
	lane.automation = true
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.state.bag_slots = loop.state.Items.empty_slots(loop.state.bag_capacity())
	for i in range(loop.state.Items.IDS.size()):
		loop.state.bag_slots[i] = {"id": loop.state.Items.IDS[i], "count": 1 if i == 0 else 99 if i == 3 else i + 1}
	loop.state.Items.sync(loop.state)
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		loop.hud.refresh()
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var pixels: Image = lane.viewport.get_texture().get_image()
		var bar: Image = pixels.get_region(Rect2i(156, 316, 328, 40))
		bar.resize(1312, 160, Image.INTERPOLATE_NEAREST)
		bar.save_png(OUT + locale + "_hotbar.png")
		if locale == "zh_CN":
			pixels.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
			pixels.save_png(OUT + "hud.png")
	lane.queue_free()
	for i in range(4): await process_frame
	await create_timer(0.2).timeout
	print("HOTBAR SHORTCUT CAPTURE COMPLETE")
	quit()
