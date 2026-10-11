extends "res://output/compact_interiors/restaurant_base.gd"

func frames(count: int = 3) -> void:
	if root.get_node("SceneTransition").active:
		await root.get_node("SceneTransition").finished
	for i in range(count):
		await process_frame
		await physics_frame
	if root.get_node("SceneTransition").active:
		await root.get_node("SceneTransition").finished
