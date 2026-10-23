extends SceneTree
func _initialize() -> void:
	preload("res://Art/Source/isolated_tools.gd").configure()
	for name in ["home_empty_0", "home_empty_1", "home_empty_2", "home_ground", "store_ground", "blacksmith_ground"]:
		var source: String = "res://Art/Environment/Hearthwood/" + name + ".aseprite"
		var scene: String = "res://Art/Environment/Hearthwood/" + name.replace("_ground", "_compact_ground") + ".tilemap.tscn" if name in ["store_ground", "blacksmith_ground"] else ""
		var picture := preload("res://Art/Source/tile_ground.gd").preview(source, scene).get_image()
		var blank := picture.get_pixel(0, 0)
		for y in range(picture.get_height()):
			for x in range(picture.get_width()):
				if picture.get_pixel(x, y).is_equal_approx(blank): picture.set_pixel(x, y, Color.TRANSPARENT)
		print(name, " pixels=", picture.get_used_rect(), " bg=", blank)
	quit()

