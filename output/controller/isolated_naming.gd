extends "res://Scenes/Campaign/verify_player_naming.gd"
func _initialize() -> void:
	Preferences.file_path = "res://output/controller/naming_preferences.cfg"
	Saves.directory = "res://output/controller/naming_saves"
	super()
