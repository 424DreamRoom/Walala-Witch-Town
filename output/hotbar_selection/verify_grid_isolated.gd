extends "res://Scenes/Storage/verify_grid.gd"

func _initialize() -> void:
	Preferences.file_path = "user://storage_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://storage_%d" % OS.get_process_id()
	Saves.end_session()
	super._initialize()
