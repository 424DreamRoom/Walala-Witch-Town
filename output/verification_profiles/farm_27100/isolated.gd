extends "res://Scenes/Farm/verify_farm.gd"
const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const TestSaves = preload("res://Scenes/Save/save_store.gd")
func _initialize() -> void:
	TestPreferences.file_path = "res://output/verification_profiles/farm_27100/preferences.cfg"
	TestSaves.directory = "res://output/verification_profiles/farm_27100/saves"
	TestSaves.end_session()
	super._initialize()
