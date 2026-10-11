extends SceneTree
const Source = preload("res://Art/Source/aseprite_source.gd")
const Ground = preload("res://Art/Source/tile_ground.gd")

func _initialize() -> void:
	preload("res://Art/Source/isolated_tools.gd").configure()
	Source.install()
	var count := 0
	for filename in DirAccess.open("res://Art/Environment/Hearthwood").get_files():
		if not filename.ends_with(".tiles.json"): continue
		var stem := filename.trim_suffix(".tiles.json")
		var base := "res://Art/Environment/Hearthwood/" + stem
		# Once created, the TileMap scene is the editable map authority.
		if FileAccess.file_exists(base + ".tilemap.tscn") and "--refresh-generated" not in OS.get_cmdline_user_args(): continue
		var tiles := Ground.create(base + ".aseprite")
		var tileset_path := "res://Art/Environment/Hearthwood/Tiles/" + stem + ".tres"
		assert(ResourceSaver.save(tiles.tile_set, tileset_path, ResourceSaver.FLAG_CHANGE_PATH) == OK)
		tiles.tile_set = load(tileset_path)
		var scene := PackedScene.new()
		assert(scene.pack(tiles) == OK)
		assert(ResourceSaver.save(scene, base + ".tilemap.tscn") == OK)
		tiles.free()
		count += 1
	print("EDITABLE TILE SCENES PASS ", count)
	quit()
