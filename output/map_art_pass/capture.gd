extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
var lane

func _initialize() -> void:
	Preferences.file_path = "res://output/map_art_pass/preferences.cfg"
	Saves.directory = "res://output/map_art_pass/saves"
	Saves.end_session()
	run.call_deferred()

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	lane.automation = true
	var imported: Image = lane.world.get_child(0).texture.get_image()
	var source := Image.load_from_file("res://Art/Environment/Hearthwood/town_ground.png")
	imported.convert(Image.FORMAT_RGBA8)
	source.convert(Image.FORMAT_RGBA8)
	assert(imported.get_data() == source.get_data(), "Runtime ground texture is stale")
	var stage := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var folder := "res://output/map_art_pass/" + stage + "/captures/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for spec in [["arrival", Vector2(408,364)], ["square", Vector2(620,470)], ["north", Vector2(610,190)], ["east_garden", Vector2(1308,360)], ["library", Vector2(536,1216)], ["windmill", Vector2(330,1390)], ["riverside", Vector2(1280,1400)]]:
		lane.player.position = spec[1]
		lane.camera.force_update_scroll()
		for i in range(5):
			await process_frame
		RenderingServer.force_draw(false)
		assert(lane.viewport.get_texture().get_image().save_png(folder + spec[0] + ".png") == OK)
		assert(root.get_texture().get_image().save_png(folder + spec[0] + "_window.png") == OK)
		print("ART PASS CAPTURE ", stage, " ", spec[0])
	lane.queue_free()
	await process_frame
	quit()
