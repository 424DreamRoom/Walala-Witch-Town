extends SceneTree

func _initialize() -> void:
	preload("res://Art/Source/isolated_tools.gd").configure()
	var preview := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	var names := ["store", "blacksmith", "furniture_store", "restaurant_full"]
	for i in range(names.size()):
		var picture := Image.load_from_file("res://output/compact_interiors/" + names[i] + ".png")
		preview.blit_rect(picture, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
	assert(preview.save_png("res://output/compact_interiors/preview.png") == OK)
	print("PREVIEW PASS")
	quit()
