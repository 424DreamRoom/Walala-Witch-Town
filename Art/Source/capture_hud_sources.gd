extends SceneTree
const Art = preload("res://Scenes/UI/hud_art.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")

func _initialize() -> void:
	Preferences.file_path = "res://output/aseprite_migration/preferences.cfg"
	Saves.directory = "res://output/aseprite_migration/saves"
	Saves.end_session()
	call_deferred("run")

func run() -> void:
	if FileAccess.file_exists("res://Art/UI/NativeIcons/wand.aseprite"):
		print("HUD source migration is already complete; edit the Aseprite sources.")
		quit()
		return
	var folder := "res://Art/UI/NativeIcons/"
	DirAccess.make_dir_recursive_absolute(folder)
	var entries: Array = []
	for kind in ["seed", "wand", "mushroom", "berry", "herb", "journal", "bag", "help", "book"]:
		entries.append({"kind":kind, "name":kind, "night":false, "weather":"clear"})
	for night in [false, true]:
		entries.append({"kind":"clock", "name":"clock_night" if night else "clock_day", "night":night, "weather":"clear"})
		for weather in ["clear", "rain", "snow"]:
			entries.append({"kind":"weather", "name":"weather_" + weather + ("_night" if night else "_day"), "night":night, "weather":weather})
	for entry in entries:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 240) if entry.kind == "book" else Vector2i(32, 32) if entry.kind == "clock" else Vector2i(24, 24)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var icon := Art.new()
		icon.kind = entry.kind
		icon.night = entry.night
		icon.weather = entry.weather
		icon.bake_base = true
		icon.size = viewport.size
		viewport.add_child(icon)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(folder + entry.name + ".png") == OK)
		viewport.queue_free()
	print("HUD SOURCE CAPTURE PASS ", entries.size())
	quit()
