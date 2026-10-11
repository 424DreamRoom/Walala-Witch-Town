extends SceneTree

func _initialize() -> void:
	# Isolate autoload reads even though this probe never loads gameplay.
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/font_clarity/preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = "res://output/font_clarity/saves"
	run.call_deferred()

func run() -> void:
	var business = preload("res://Scenes/Businesses/business_interior.gd").new()
	var panel := Panel.new()
	root.add_child(panel)
	var label: Label = business._label("橡果杂货店", Vector2.ZERO, panel)
	for key in ["outline_size", "shadow_outline_size", "shadow_offset_x", "shadow_offset_y"]:
		print("LABEL ", key, "=", label.get_theme_constant(key))
	print("LABEL shadow_color=", label.get_theme_color("font_shadow_color"))
	print("LABEL font_size=", label.get_theme_font_size("font_size"))
	business.free()
	panel.free()
	quit()
