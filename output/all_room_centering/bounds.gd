extends SceneTree
func _initialize() -> void:
	preload("res://Art/Source/isolated_tools.gd").configure()
	for name in ["home_empty_0", "home_empty_1", "home_empty_2", "home_ground", "store_compact_ground", "blacksmith_compact_ground", "restaurant_compact_ground"]:
		var ground: TileMapLayer = load("res://Art/Environment/Hearthwood/" + name + ".tilemap.tscn").instantiate()
		var blank := ground.get_cell_atlas_coords(Vector2i.ZERO)
		var bounds := Rect2i()
		for cell in ground.get_used_cells():
			if ground.get_cell_atlas_coords(cell) == blank: continue
			var rect := Rect2i(cell * ground.tile_set.tile_size, ground.tile_set.tile_size)
			bounds = rect if not bounds.has_area() else bounds.merge(rect)
		print(name, " ", bounds, " blank=", blank)
		ground.free()
	quit()
