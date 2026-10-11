extends "res://Scenes/Storage/verify_grid.gd"
func _initialize() -> void:
	Preferences.file_path = "res://output/controller/storage_preferences.cfg"
	Saves.directory = "res://output/controller/storage_saves"
	super()
