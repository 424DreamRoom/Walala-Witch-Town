extends SceneTree

func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/witch-aseprite32/profile/lane/preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/witch-aseprite32/profile/lane/saves"
	preload("res://Scenes/Save/save_store.gd").end_session()
	root.add_child(load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate())
