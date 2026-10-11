extends "res://Scenes/Gameplay/verify_harvest.gd"
## Run the existing harvesting regression using this task's own profile.
const WitchAnimation = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")

func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/witch-aseprite32/profile/harvest/preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/witch-aseprite32/profile/harvest/saves"
	preload("res://Scenes/Save/save_store.gd").end_session()
	capture_output = "res://output/witch-aseprite32/harvest/"
	run.call_deferred()

func swing(node, name: String) -> void:
	await super.swing(node, name)
	# Exercise the actual action controller without advancing gameplay/rewards.
	lane.player.position = node.anchor
	harvest.target = node
	for direction in range(4):
		lane.facing = direction
		for action_name in ["chop", "mine"]:
			harvest.action = action_name
			var duration: float = loop.state.swing_seconds(node.resource_kind)
			for step in range(8):
				harvest.elapsed = duration * (float(step) + 0.1) / 8.0
				harvest.update_pose()
				check("spell " + action_name + "/" + str(direction) + "/" + str(step), harvest.actor.frame == int(WitchAnimation.tag_for("cast", direction).from) + step)
	harvest.cancel()
