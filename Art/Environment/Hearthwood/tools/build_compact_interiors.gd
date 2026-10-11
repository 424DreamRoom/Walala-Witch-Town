extends SceneTree
## Rearrange existing native tiles; never redraw, resize or write source artwork.
const ART := "res://Art/Environment/Hearthwood/"
const Source = preload("res://Art/Source/aseprite_source.gd")

func _initialize() -> void:
	preload("res://Art/Source/isolated_tools.gd").configure()
	Source.install()
	for kind in ["store", "blacksmith", "restaurant"]:
		var original: TileMapLayer = load(ART + kind + "_ground.tilemap.tscn").instantiate()
		var compact := TileMapLayer.new()
		compact.name = "Ground"
		compact.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		compact.tile_set = original.tile_set
		for y in range(23 if kind == "restaurant" else 30):
			for x in range(40):
				var source := Vector2i.ZERO
				if kind == "restaurant":
					source = Vector2i(x if x < 14 else x + 6, y if y < 12 else y + 2)
					if source.x >= 40 or source.y >= 23: source = Vector2i(39, 0)
				elif x >= 8 and x <= 31 and y >= 8 and y <= 28:
					var column := x - 6 if x <= 14 else x if x <= 24 else x + 6
					source = Vector2i(column, y - 5 if y <= 18 else y + 1)
				compact.set_cell(Vector2i(x, y), original.get_cell_source_id(source), original.get_cell_atlas_coords(source), original.get_cell_alternative_tile(source))
		compact.set_meta("compact_source", ART + kind + "_ground.tilemap.tscn")
		var scene := PackedScene.new()
		assert(scene.pack(compact) == OK)
		assert(ResourceSaver.save(scene, ART + kind + "_compact_ground.tilemap.tscn") == OK)
		compact.free()
		original.free()
	print("COMPACT TILE MAPS PASS 3; original art unchanged")
	quit()
