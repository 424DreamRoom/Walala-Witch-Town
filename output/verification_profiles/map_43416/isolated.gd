extends "res://Scenes/Map/verify_map.gd"
const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const TestSaves = preload("res://Scenes/Save/save_store.gd")
func _initialize() -> void:
	TestPreferences.file_path = "res://output/verification_profiles/map_43416/preferences.cfg"
	TestSaves.directory = "res://output/verification_profiles/map_43416/saves"
	TestSaves.end_session()
	super._initialize()
