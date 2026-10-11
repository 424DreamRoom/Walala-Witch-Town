extends "res://Scenes/Gameplay/verify_harvest.gd"

func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/witch-v2/profile/preferences-harvest.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/witch-v2/profile/saves-harvest"
	preload("res://Scenes/Save/save_store.gd").end_session()
	capture = true
	capture_output = "res://output/witch-v2/harvest/"
	run.call_deferred()
