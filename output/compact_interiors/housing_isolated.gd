extends "res://output/compact_interiors/housing_base.gd"

func _initialize() -> void:
	Preferences.file_path = "res://output/compact_interiors/housing_preferences.cfg"
	Saves.directory = "res://output/compact_interiors/housing_saves"
	Saves.end_session()
	super._initialize()

func frames(count: int = 3) -> void:
	if root.get_node("SceneTransition").active:
		await root.get_node("SceneTransition").finished
	for i in range(count):
		await process_frame
		await physics_frame
	if root.get_node("SceneTransition").active:
		await root.get_node("SceneTransition").finished
