extends SceneTree
## Run with --fixed-fps 12 to record the real menu's entrance and interaction.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://output/menu_motion/"
var menu
var pointer := Vector2.ZERO

func _initialize() -> void:
	run.call_deferred()

func hover(button: Button) -> void:
	pointer = menu.container.position + button.get_global_rect().get_center() * menu.container.scale
	var event := InputEventMouseMotion.new()
	event.position = pointer
	root.push_input(event, true)

func mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pointer
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func escape(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	var ignore := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
	ignore.close()
	Preferences.file_path = "user://menu_motion_capture_%d.cfg" % OS.get_process_id()
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in range(108):
		match i:
			18: hover(menu.buttons[1])
			30: hover(menu.buttons[2])
			42: hover(menu.buttons[3])
			48: hover(menu.buttons[1])
			50: mouse_button(true)
			52: mouse_button(false)
			65: escape(true)
			66: escape(false)
			73: hover(menu.buttons[0])
		RenderingServer.force_draw(false)
		var pixels: Image = menu.viewport.get_texture().get_image()
		var error := pixels.save_png(OUT + "frames/%03d.png" % i)
		if error != OK:
			push_error("Motion frame capture failed: " + error_string(error))
			quit(1)
			return
		await process_frame
	menu.audio.stop()
	menu.queue_free()
	await create_timer(0.05).timeout
	if FileAccess.file_exists(Preferences.file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("MENU MOTION CAPTURE END frames=108 fps=12")
	quit()
