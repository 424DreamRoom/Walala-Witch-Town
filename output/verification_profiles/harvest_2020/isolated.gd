extends "res://Scenes/Gameplay/verify_harvest.gd"
const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const TestSaves = preload("res://Scenes/Save/save_store.gd")
func _initialize() -> void:
	TestPreferences.file_path = "res://output/verification_profiles/harvest_2020/preferences.cfg"
	TestSaves.directory = "res://output/verification_profiles/harvest_2020/saves"
	TestSaves.end_session()
	super._initialize()
