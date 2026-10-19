extends "res://Scenes/Gameplay/verify_harvest.gd"
const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const TestSaves = preload("res://Scenes/Save/save_store.gd")
func _initialize() -> void:
	super._initialize()
	TestPreferences.file_path = "res://output/wand_modes/regressions/harvest_20944/preferences.cfg"
	TestSaves.directory = "res://output/wand_modes/regressions/harvest_20944/saves"
	TestSaves.end_session()
