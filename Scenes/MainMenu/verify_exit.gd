extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	# Let the initial deferred GUI focus and audio startup finish before quitting.
	await create_timer(0.2).timeout
	menu._open_quit()
	print("MENU EXIT CONFIRMED")
	menu.dialog.get_node("ConfirmQuit").pressed.emit()
	# The runner's deadline catches a quit action that fails to terminate.
