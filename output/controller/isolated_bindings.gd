extends "res://Scenes/Input/verify_bindings.gd"
func _initialize() -> void:
	Preferences.file_path = "res://output/controller/bindings_preferences.cfg"
	Saves.directory = "res://output/controller/bindings_saves"
	super()
