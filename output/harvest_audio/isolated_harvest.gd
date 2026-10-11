extends "res://Scenes/Gameplay/verify_harvest.gd"
func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/harvest_audio/regression_harvest_%d.cfg" % OS.get_process_id()
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/harvest_audio/regression_harvest_%d_saves" % OS.get_process_id()
	super._initialize()
