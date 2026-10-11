extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/hud_top_cleanup/"

func _initialize() -> void:
	Preferences.file_path = OUT + "capture_preferences.cfg"
	Saves.directory = OUT + "capture_saves"
	Saves.end_session()
	run.call_deferred()

func run() -> void:
	root.get_node("Localization").set_language("zh_CN")
	root.get_node("InputBindings").reset_defaults()
	var lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	for i in range(10): await process_frame
	lane.automation = true
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	loop._refresh()
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	var result := pixels.save_png(OUT + "hud_town.png")
	print("HUD CAPTURE ", result)
	lane.queue_free()
	for i in range(8): await process_frame
	quit(0 if result == OK else 1)
