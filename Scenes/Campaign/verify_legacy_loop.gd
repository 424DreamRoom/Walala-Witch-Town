extends "res://Scenes/Gameplay/verify_loop.gd"
## Run the existing movement, harvest and restaurant suite with isolated preferences.
func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/campaign_legacy_preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/campaign_legacy_saves"
	super._initialize()
