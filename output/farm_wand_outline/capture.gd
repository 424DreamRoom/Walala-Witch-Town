extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/farm_wand_outline/"
var lane
var loop

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	run.call_deferred()

func frames(count: int = 4) -> void:
	for i in range(count): await process_frame

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("farm")
	for resource in loop.area.resource_nodes:
		loop.state.resource_damage[resource.resource_id] = loop.state.RESOURCE_HITS
		resource.refresh()
	loop.area.refresh_resources()
	lane.player.position = loop.area.tile_center(0) + Vector2(0, 30)
	lane.facing = 1
	lane._animate(false, false, 0.0)
	lane.camera.force_update_scroll()
	await frames()
	lane.process_mode = Node.PROCESS_MODE_DISABLED
	for sample in [{"slot": 0, "name": "wand"}, {"slot": 1, "name": "seed"}, {"slot": 9, "name": "empty"}]:
		loop.state.select_hotbar_slot(sample.slot)
		loop.area._process(0.0)
		loop.hud.refresh()
		await frames()
		await RenderingServer.frame_post_draw
		var pixels: Image = lane.viewport.get_texture().get_image()
		var center: Vector2 = loop.area.terrain.get_global_transform_with_canvas() * loop.area.tile_center(0)
		pixels.get_region(Rect2i(Vector2i(center) - Vector2i(16, 16), Vector2i(32, 32))).save_png(OUT + sample.name + "_tile.png")
		pixels.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		pixels.save_png(OUT + sample.name + ".png")
		print("FARM OUTLINE CAPTURE ", sample.name, " selected_tile=", loop.area.selected, " selected_item=", loop.state.selected_item_id())
	lane.queue_free()
	await frames()
	quit()
