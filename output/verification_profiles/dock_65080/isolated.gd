extends "res://Scenes/Dock/verify_dock.gd"
const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const TestSaves = preload("res://Scenes/Save/save_store.gd")
func _initialize() -> void:
	TestPreferences.file_path = "res://output/verification_profiles/dock_65080/preferences.cfg"
	TestSaves.directory = "res://output/verification_profiles/dock_65080/saves"
	TestSaves.end_session()
	super._initialize()
