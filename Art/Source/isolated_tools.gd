extends RefCounted
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")

static func configure() -> void:
	Preferences.file_path = "res://output/aseprite_migration/tool_preferences.cfg"
	Saves.directory = "res://output/aseprite_migration/tool_saves"
	Saves.end_session()
