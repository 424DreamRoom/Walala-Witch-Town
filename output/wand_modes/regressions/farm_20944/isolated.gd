extends "res://Scenes/Farm/verify_farm.gd"
const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const TestSaves = preload("res://Scenes/Save/save_store.gd")
func _initialize() -> void:
	super._initialize()
	TestPreferences.file_path = "res://output/wand_modes/regressions/farm_20944/preferences.cfg"
	TestSaves.directory = "res://output/wand_modes/regressions/farm_20944/saves"
	TestSaves.end_session()
