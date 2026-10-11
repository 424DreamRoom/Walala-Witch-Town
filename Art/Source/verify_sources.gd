extends SceneTree
const Source = preload("res://Art/Source/aseprite_source.gd")
const Ground = preload("res://Art/Source/tile_ground.gd")
var mismatches: Array = []

func _initialize() -> void:
	preload("res://Art/Source/isolated_tools.gd").configure()
	call_deferred("run")

func run() -> void:
	Source.install()
	var assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Source/assets.json"))
	var checked := 0
	for path in assets:
		var data: Dictionary = Source.decode(assets[path].source)
		assert(not data.is_empty(), path)
		if path.ends_with(".png"):
			var original := Image.load_from_file(path)
			original.convert(Image.FORMAT_RGBA8)
			var result: Image = data.image
			if original.get_size() != result.get_size() or original.get_data() != result.get_data():
				mismatches.append(path)
				if mismatches.size() <= 6: result.save_png("res://output/aseprite_migration/mismatch_%d.png" % mismatches.size())
		checked += 1
	var directory := DirAccess.open("res://Art/Environment/Hearthwood")
	var maps := 0
	for filename in directory.get_files():
		if not filename.ends_with(".tiles.json"): continue
		var path := "res://Art/Environment/Hearthwood/" + filename
		var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var layer := Ground.create(path.trim_suffix(".tiles.json") + ".aseprite")
		assert(layer is TileMapLayer and layer.tile_set.get_source(0).texture.resource_path.ends_with(".aseprite"))
		var atlas: Image = layer.tile_set.get_source(0).texture.get_image()
		var composite := Image.create(map.cells[0].size() * 16, map.cells.size() * 16, false, Image.FORMAT_RGBA8)
		for cell in layer.get_used_cells():
			var coordinates := layer.get_cell_atlas_coords(cell)
			composite.blit_rect(atlas, Rect2i(coordinates * 16, Vector2i(16, 16)), cell * 16)
		var original := Image.load_from_file(path.trim_suffix(".tiles.json") + ".png")
		original.convert(Image.FORMAT_RGBA8)
		composite.crop(original.get_width(), original.get_height())
		assert(composite.get_data() == original.get_data(), path)
		layer.free()
		maps += 1
	var report := {"assets": checked, "pixel_mismatches": mismatches, "tile_maps": maps}
	var file := FileAccess.open("res://output/aseprite_migration/pixels.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SOURCE PIXELS ", JSON.stringify(report))
	quit(0 if mismatches.is_empty() else 1)
