extends SceneTree
func _initialize() -> void:
	if FileAccess.file_exists("res://Art/Source/isolated_tools.gd"):
		load("res://Art/Source/isolated_tools.gd").configure()
	var manifest := "res://output/aseprite_migration/vectors.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="): manifest = argument.trim_prefix("--manifest=")
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	for entry in entries:
		var image := Image.new()
		assert(image.load_svg_from_string(FileAccess.get_file_as_string(entry.source)) == OK, entry.source)
		assert(image.save_png(entry.target) == OK, entry.target)
	print("VECTOR RASTERIZATION PASS ", entries.size())
	quit()
