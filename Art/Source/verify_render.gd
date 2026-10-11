extends SceneTree
const Ground = preload("res://Art/Source/tile_ground.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")

func _initialize() -> void:
	Preferences.file_path = "res://output/aseprite_migration/render_preferences.cfg"
	Saves.directory = "res://output/aseprite_migration/render_saves"
	Saves.end_session()
	call_deferred("run")

func run() -> void:
	var folder := "res://output/aseprite_migration/render/"
	DirAccess.make_dir_recursive_absolute(folder)
	var count := 0
	for filename in DirAccess.open("res://Art/Environment/Hearthwood").get_files():
		if not filename.ends_with(".tiles.json"): continue
		var base := "res://Art/Environment/Hearthwood/" + filename.trim_suffix(".tiles.json")
		var expected := Image.load_from_file(base + ".png")
		expected.convert(Image.FORMAT_RGBA8)
		var viewport := SubViewport.new()
		viewport.size = expected.get_size()
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(Ground.create(base + ".aseprite"))
		await process_frame
		await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		actual.convert(Image.FORMAT_RGBA8)
		actual.save_png(folder + filename.trim_suffix(".tiles.json") + ".png")
		assert(actual.get_data() == expected.get_data(), filename)
		viewport.queue_free()
		count += 1
	var lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	lane.automation = true
	for spec in [["arrival", Vector2(408,364)], ["square", Vector2(620,470)], ["windmill", Vector2(330,1390)]]:
		lane.player.position = spec[1]
		lane.camera.force_update_scroll()
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		assert(lane.viewport.get_texture().get_image().save_png(folder + spec[0] + ".png") == OK)
	lane.queue_free()
	await process_frame
	print("SOURCE TILE GPU RENDER PASS ", count, "; gameplay captures 3")
	quit()
