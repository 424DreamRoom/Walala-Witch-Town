extends "res://output/witch-v2/capture_harvest.gd"

var legacy_art_applied := false

func _initialize() -> void:
	super._initialize()
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/witch-v2/profile/preferences-baseline.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/witch-v2/profile/saves-baseline"
	capture_output = "res://output/witch-v2/baseline-harvest/"

func frames(count: int = 3) -> void:
	await super.frames(count)
	if lane != null and not legacy_art_applied:
		var active_loop = lane.get_node_or_null("GameLoop")
		if active_loop != null and active_loop.harvest != null:
			lane.avatar.texture = load("res://Art/Character/Storybook/WalalaWitch/walala-witch.png")
			active_loop.harvest.actor.texture = load("res://Art/Character/Storybook/WalalaTools/witch-tools.png")
			legacy_art_applied = true
			print("BASELINE OLD TEXTURES: ", lane.avatar.texture.resource_path, " + ", active_loop.harvest.actor.texture.resource_path)
