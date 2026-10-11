extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
func _initialize() -> void:
	Preferences.file_path = "res://output/hotbar_counts/preferences.cfg"
	Saves.directory = "res://output/hotbar_counts/saves"
	Saves.end_session()
	run.call_deferred()
func run() -> void:
	var lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	for i in range(5): await process_frame
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	lane.automation = true
	loop.state.bag_slots = loop.state.Items.empty_slots(loop.state.bag_capacity())
	loop.state.bag_slots[0] = {"id":"wand","count":1}
	loop.state.bag_slots[1] = {"id":"seed","count":12}
	loop.state.bag_slots[2] = {"id":"wood","count":6}
	loop.state.bag_slots[3] = {"id":"mushroom","count":99}
	loop.state.bag_slots[4] = {"id":"ore","count":2}
	loop.state.Items.sync(loop.state)
	loop.hud.refresh()
	for variant in ["after", "before"]:
		if variant == "before":
			for count in loop.hud.slot_counts:
				count.add_theme_font_size_override("font_size",12)
				count.position = Vector2(9,11)
				count.size = Vector2(16,13)
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var pixels = lane.viewport.get_texture().get_image()
		pixels.resize(1920,1080,Image.INTERPOLATE_NEAREST)
		pixels.save_png("res://output/hotbar_counts/" + variant + ".png")
	lane.queue_free()
	for i in range(4): await process_frame
	await create_timer(0.2).timeout
	print("HOTBAR COUNT CAPTURE COMPLETE")
	quit()
