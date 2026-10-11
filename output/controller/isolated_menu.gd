extends "res://Scenes/MainMenu/verify_menu.gd"
func _initialize() -> void:
	Preferences.file_path = "res://output/controller/menu_preferences.cfg"
	Saves.directory = "res://output/controller/menu_saves"
	super()
