extends SceneTree
## Captures actual Godot controls at the project's native pixel resolution.
const OUT := "res://Art/UI/FramewrightLite/Verification/"
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
var lane
var loop
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("UI SKIN TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed:
		failures += 1

func frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame

func shot(name: String) -> void:
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	check("capture " + name, pixels.save_png(OUT + name + ".png") == OK)
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("preview " + name, pixels.save_png(OUT + name + "_2x.png") == OK)

func check_buttons(buttons: Array, title: String) -> void:
	for button in buttons:
		var style = button.get_theme_stylebox("normal")
		check(title + " uses original pixel texture", style is StyleBoxTexture and "FramewrightLite" in style.texture.resource_path)
		var text_size: Vector2 = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
		check(title + " text fits", text_size.x + style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT) <= button.size.x and text_size.y + style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM) <= button.size.y)
		check(title + " keeps Chinese font", button.get_theme_font("font") == UIFont.get_font())

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(8)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	check("global theme", ProjectSettings.get_setting("gui/theme/custom").ends_with("walala_theme.tres"))
	await shot("town_hud")
	loop.enter("restaurant")
	await frames()
	check_buttons(loop.menu_buttons, "restaurant menu")
	check_buttons([loop.end_button, loop.discard_button], "phase controls")
	await shot("restaurant_menu")
	loop.menu_buttons[1].set_pressed_no_signal(false)
	loop.state.menu[1] = false
	await shot("restaurant_menu_states")
	loop.state.end_phase()
	loop._sync_phase()
	loop.lane.player.position = loop.area.stations.kitchen + Vector2(0, 16)
	loop.state.materials = [6, 6, 6]
	loop._refresh()
	await frames()
	check_buttons(loop.cook_buttons, "cooking")
	await shot("restaurant_cooking")
	loop.state.end_phase()
	loop._sync_phase()
	await shot("restaurant_result")
	loop.state.next_day()
	loop.last_phase = loop.state.phase
	for kind in ["blacksmith", "store"]:
		loop.enter(kind)
		await frames()
		loop.lane.player.position = loop.area.stations.service + Vector2(0, 20)
		loop.area.interact()
		await frames()
		check_buttons(loop.area.buttons, kind)
		check(kind + " panel within canvas", Rect2(Vector2.ZERO, Vector2(640, 360)).encloses(loop.area.service_panel.get_rect()))
		await shot(kind + "_panel")
	loop.enter("town")
	loop.audio.panel.show()
	await shot("sound_settings")
	lane.queue_free()
	await frames()
	print("UI SKIN VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
