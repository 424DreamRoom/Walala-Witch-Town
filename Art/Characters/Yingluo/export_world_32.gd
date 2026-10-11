extends SceneTree
## Enforce the requested native raster size; never scan or write original art.
const SOURCE := "res://Art/Characters/Yingluo/yingluo_world_32_source.png"
const OUTPUT := "res://Art/Characters/Yingluo/yingluo_world_32.png"
const MANIFEST := "res://Art/Characters/Yingluo/manifest.json"
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")

func _initialize() -> void:
	Preferences.file_path = "res://output/guide_npc/export_preferences.cfg"
	Saves.directory = "res://output/guide_npc/export_saves"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/guide_npc/"))
	var image := Image.load_from_file(SOURCE)
	if image == null or image.is_empty():
		push_error("Missing Yingluo source")
		quit(1)
		return
	var source_size := image.get_size()
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	if image.save_png(OUTPUT) != OK:
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	data["yingluo_world_32_source.png"] = {"size": [source_size.x, source_size.y], "mode": "RGBA", "sha256": FileAccess.get_sha256(SOURCE), "generator": "built-in image_gen"}
	data["yingluo_world_32.png"] = {"size": [32,32], "mode": "RGBA", "sha256": FileAccess.get_sha256(OUTPUT), "source": "yingluo_world_32_source.png", "resampling": "nearest", "world_scale": 1}
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()
	# Preview is an integer enlargement of the final 32x32 export.
	image.resize(512, 512, Image.INTERPOLATE_NEAREST)
	image.save_png("res://output/guide_npc/yingluo_32_preview.png")
	print("YINGLUO EXPORT 32x32 nearest, source=", source_size)
	quit()
