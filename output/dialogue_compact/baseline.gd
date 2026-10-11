extends "res://Scenes/UI/verify_ui.gd"
var baseline_installed := false

func frames(count: int = 3) -> void:
	if not baseline_installed and is_instance_valid(lane):
		var game = lane.get_node_or_null("GameLoop")
		if game != null and is_instance_valid(game.hud):
			baseline_installed = true
			game.hud.base.free()
			game.hud.free()
			game.hud = load("res://output/dialogue_compact/baseline_hud.gd").new()
			game.hud.loop = game
			game.add_child(game.hud)
	await super.frames(count)
