extends "res://Scenes/Building/verify_building.gd"
func _initialize() -> void:
	Preferences.file_path = "res://output/controller/building_preferences.cfg"
	Saves.directory = "res://output/controller/building_saves"
	super()
