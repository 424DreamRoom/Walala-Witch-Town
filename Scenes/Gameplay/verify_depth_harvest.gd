extends "res://Scenes/Gameplay/verify_harvest.gd"

func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/depth_harvest_preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/depth_harvest_saves"
	preload("res://Scenes/Save/save_store.gd").end_session()
	super._initialize()
