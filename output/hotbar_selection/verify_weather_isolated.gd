extends "res://Scenes/LanternLane/Effect/Weather/verify_weather.gd"
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")

func _initialize() -> void:
	Preferences.file_path = "user://hotbar_weather_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://hotbar_weather_%d" % OS.get_process_id()
	Saves.end_session()
	super._initialize()
