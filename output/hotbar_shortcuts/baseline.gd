extends "res://Scenes/UI/verify_ui.gd"

func _initialize() -> void:
	var baseline: GDScript = load("res://output/hotbar_shortcuts/baseline_hud.gd")
	baseline.take_over_path("res://Scenes/UI/game_hud.gd")
	super._initialize()

func check(title: String, passed: bool) -> void:
	if title == "HUD attached to native canvas":
		print("BASELINE WITHOUT SHORTCUTS ", hud.base.get_node("InventorySlot0").get_node_or_null("Shortcut") == null)
	super.check(title, passed)
