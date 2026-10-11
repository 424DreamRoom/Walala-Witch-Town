extends "res://Scenes/LanternLane/verify_town_plan.gd"
const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const TestSaves = preload("res://Scenes/Save/save_store.gd")
func _initialize() -> void:
	TestPreferences.file_path = "res://output/verification_profiles/town_17956/preferences.cfg"
	TestSaves.directory = "res://output/verification_profiles/town_17956/saves"
	TestSaves.end_session()
	super._initialize()
