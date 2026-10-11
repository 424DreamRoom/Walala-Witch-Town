extends "res://Scenes/UI/verify_ui.gd"
## Compare the pre-layout source in memory; never replace the active HUD file.
func _initialize() -> void:
	var hud_script: GDScript = load("res://Scenes/UI/game_hud.gd")
	hud_script.source_code = FileAccess.get_file_as_string("res://output/dialogue_bottom_align/before_game_hud.gd")
	var result := hud_script.reload(true)
	if result != OK:
		push_error("Baseline HUD reload failed: " + str(result))
		quit(1)
		return
	super._initialize()
