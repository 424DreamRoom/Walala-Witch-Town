extends SceneTree
const OUT := "res://output/shop_doorway_fix/"
func _initialize() -> void:
	preload("res://Art/Source/isolated_tools.gd").configure()
	for kind in ["store", "blacksmith"]:
		for compact in [false, true]:
			var source := "res://Art/Environment/Hearthwood/" + str(kind) + "_ground.aseprite"
			var override := "res://Art/Environment/Hearthwood/" + str(kind) + "_compact_ground.tilemap.tscn" if compact else ""
			var picture := preload("res://Art/Source/tile_ground.gd").preview(source, override).get_image()
			var crop := picture.get_region(Rect2i(232, 384, 176, 96))
			crop.resize(880, 480, Image.INTERPOLATE_NEAREST)
			crop.save_png(OUT + str(kind) + ("_compact" if compact else "_original") + ".png")
	quit()
