extends "res://Scenes/Save/verify_saving_indicator.gd"

func _initialize() -> void:
	var baseline: GDScript = load("res://output/hotbar_bottom/baseline_hud.gd")
	baseline.take_over_path("res://Scenes/UI/game_hud.gd")
	super._initialize()

func check(title: String, passed: bool) -> void:
	if title == "bottom right cue clears inventory":
		print("BASELINE HOTBAR ", loop.hud.slot_counts.size(), " ", loop.hud.hotbar_art.get_rect())
	super.check(title, passed)
