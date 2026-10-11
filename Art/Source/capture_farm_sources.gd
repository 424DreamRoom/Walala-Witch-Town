extends SceneTree
const Farm = preload("res://Scenes/Farm/farm.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")

func _initialize() -> void:
	Preferences.file_path = "res://output/aseprite_migration/preferences.cfg"
	Saves.directory = "res://output/aseprite_migration/saves"
	Saves.end_session()
	call_deferred("run")

func run() -> void:
	if FileAccess.file_exists("res://Art/Environment/Hearthwood/Tiles/farm_soil.aseprite"):
		print("Farm source migration is already complete; edit the Aseprite sources.")
		quit()
		return
	var farm := Farm.new()
	var state := State.new()
	farm.loop = {"state": state}
	var folder := "res://Art/Environment/Hearthwood/Tiles/"
	for soil in [false, true]:
		var sheet := Image.create(64 if soil else 128, 32, false, Image.FORMAT_RGBA8)
		for index in (2 if soil else 4):
			state.farm.plots = {"0": {"growth": index, "crop": "herb", "watered": bool(index)}}
			var viewport := SubViewport.new()
			viewport.size = Vector2i(32, 32)
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var painter := Node2D.new()
			painter.position = Vector2(16, 16) - farm.tile_center(0) if soil else Vector2(16, 31)
			viewport.add_child(painter)
			if soil:
				farm.terrain = painter
				painter.draw.connect(farm._draw_plots)
			else:
				painter.draw.connect(farm._draw_crop.bind(painter, "0"))
			await process_frame
			await RenderingServer.frame_post_draw
			sheet.blit_rect(viewport.get_texture().get_image(), Rect2i(0, 0, 32, 32), Vector2i(index * 32, 0))
			viewport.queue_free()
		assert(sheet.save_png(folder + ("farm_soil.png" if soil else "herb_lifecycle.png")) == OK)
	farm.free()
	print("FARM SOURCE CAPTURE PASS")
	quit()
