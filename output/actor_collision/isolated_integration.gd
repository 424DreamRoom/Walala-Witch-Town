extends "res://Scenes/Gameplay/verify_actor_collision.gd"
var test_resources: Array[Resource] = []
func _initialize() -> void:
	# Test-only overlays for unrelated, concurrently edited work. Production
	# scripts/assets are left untouched, and these aliases live for this run only.
	var menu := GDScript.new()
	menu.source_code = FileAccess.get_file_as_string("res://Scenes/Save/save_menu.gd").replace("var building :=", "var building: bool =")
	if menu.reload() == OK:
		menu.take_over_path("res://Scenes/Save/save_menu.gd")
		test_resources.append(menu)
	if not ResourceLoader.exists("res://Art/Environment/Hearthwood/outdoor_sign_furniture_store.png"):
		var sign: Texture2D = load("res://Art/Environment/Hearthwood/outdoor_sign_home.png").duplicate()
		sign.take_over_path("res://Art/Environment/Hearthwood/outdoor_sign_furniture_store.png")
		test_resources.append(sign)
	print("TEST OVERLAYS: menu variable type and unfinished furniture-store sign only")
	super._initialize()
