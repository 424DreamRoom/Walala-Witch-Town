extends "res://output/witch-aseprite32/baseline/test.gd"
func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/witch-aseprite32/baseline/preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/witch-aseprite32/baseline/saves"
	preload("res://Scenes/Save/save_store.gd").end_session()
	capture_output = "res://output/witch-aseprite32/baseline/captures/"
	run.call_deferred()
