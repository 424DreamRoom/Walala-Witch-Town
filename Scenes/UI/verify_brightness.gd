extends SceneTree
## Verify real controls, saved settings and the final rendered output.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/brightness/"
var capture := false
var failures := 0
var checks := 0
var menu

func _initialize() -> void:
	capture = "--brightness-capture" in OS.get_cmdline_user_args()
	Preferences.file_path = "res://output/brightness_%d.cfg" % OS.get_process_id()
	Saves.directory = "res://output/brightness_%d_saves" % OS.get_process_id()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("BRIGHTNESS TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func applied(viewport: SubViewport) -> float:
	return float((viewport.get_parent().material as ShaderMaterial).get_shader_parameter("brightness"))

func add_probe(viewport: SubViewport) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 1000
	viewport.add_child(layer)
	for index in range(3):
		var swatch := ColorRect.new()
		swatch.position = Vector2(2 + index * 10, 2)
		swatch.size = Vector2(8, 8)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gray: float = [0.25, 0.0, 1.0][index]
		swatch.color = Color(gray, gray, gray)
		layer.add_child(swatch)
	return layer

func rendered_samples(viewport: SubViewport) -> Array:
	await frames()
	RenderingServer.force_draw(false)
	var pixels := root.get_texture().get_image()
	var ratio := Vector2(pixels.get_size()) / root.get_visible_rect().size
	var container := viewport.get_parent() as SubViewportContainer
	var samples := []
	for index in range(3):
		var position := (container.position + Vector2(6 + index * 10, 6) * container.scale) * ratio
		samples.append(pixels.get_pixelv(Vector2i(position)).r)
	return samples

func shot(viewport: SubViewport, title: String) -> void:
	if not capture: return
	# Capture the settled modal, after its existing entrance animation.
	await create_timer(0.25).timeout
	await frames()
	RenderingServer.force_draw(false)
	var pixels := root.get_texture().get_image()
	var ratio := Vector2(pixels.get_size()) / root.get_visible_rect().size
	var container := viewport.get_parent() as SubViewportContainer
	pixels = pixels.get_region(Rect2i(Vector2i(container.position * ratio), Vector2i(Vector2(640, 360) * container.scale * ratio)))
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + title, pixels.save_png(OUT + title + ".png") == OK)

func mouse_slider(slider: HSlider, viewport: SubViewport) -> void:
	var container := viewport.get_parent() as SubViewportContainer
	var rect := slider.get_global_rect()
	var position := container.position + (rect.position + Vector2(rect.size.x * 0.75, rect.size.y * 0.5)) * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await frames()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await frames()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	check("old preferences default to neutral", Preferences.brightness() == 0.0)
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._open_settings()
	menu.dialog.select_page(1, false)
	await frames()
	var panel = menu.dialog
	check("display page has centered brightness control", panel.brightness_slider.visible and panel.brightness_slider.value == 0.0 and panel.brightness_slider.min_value == -50.0 and panel.brightness_slider.max_value == 50.0 and panel.get_node("BrightnessValue").text == "0")
	await mouse_slider(panel.brightness_slider, menu.viewport)
	check("real mouse adjusts and saves brightness", panel.brightness_slider.value > 15 and panel.brightness_slider.value < 35 and Preferences.read().get_value("display", "brightness") == panel.brightness_slider.value and applied(menu.viewport) == panel.brightness_slider.value)
	var before: float = panel.brightness_slider.value
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_D
		event.physical_keycode = KEY_D
		event.pressed = down
		root.push_input(event, true)
		await frames()
	check("existing keyboard input adjusts brightness", panel.brightness_slider.value == before + 1 and panel.get_node("BrightnessValue").text == str(roundi(before + 1)))
	if capture:
		var probe := add_probe(menu.viewport)
		panel.brightness_slider.value = 0
		var neutral: Array = await rendered_samples(menu.viewport)
		panel.brightness_slider.value = -50
		var dark: Array = await rendered_samples(menu.viewport)
		panel.brightness_slider.value = 50
		var light: Array = await rendered_samples(menu.viewport)
		check("shader visibly darkens and brightens final pixels", dark[0] < neutral[0] - 0.03 and light[0] > neutral[0] + 0.03)
		check("neutral preserves source pixels", absf(neutral[0] - 0.25) <= 1.0 / 255.0)
		check("black and white remain intact at both extremes", dark[1] == neutral[1] and light[1] == neutral[1] and dark[2] == neutral[2] and light[2] == neutral[2])
		probe.queue_free()
		panel.brightness_slider.value = -35
		await shot(menu.viewport, "settings_dark")
		panel.brightness_slider.value = 35
		await shot(menu.viewport, "settings_light")
	panel.brightness_slider.value = 25
	menu._close_dialog()
	menu._open_settings()
	menu.dialog.select_page(1, false)
	check("reopened menu restores saved slider", menu.dialog.brightness_slider.value == 25 and applied(menu.viewport) == 25)
	menu.queue_free()
	await frames()
	var lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	lane.automation = true
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	check("gameplay inherits saved brightness", applied(lane.viewport) == 25)
	paused = true
	loop.audio.panel.show()
	loop.audio.panel.select_page(1, false)
	check("pause settings restore brightness", loop.audio.panel.brightness_slider.value == 25)
	var lighting: Color = loop.day_night.modulation.color
	loop.audio.panel.brightness_slider.value = -20
	check("paused adjustment applies and saves immediately", paused and applied(lane.viewport) == -20 and Preferences.read().get_value("display", "brightness") == -20)
	check("brightness preserves time-of-day lighting", loop.day_night.modulation.color == lighting)
	if capture:
		var probe := add_probe(lane.viewport)
		var dark: Array = await rendered_samples(lane.viewport)
		loop.audio.panel.brightness_slider.value = 20
		var light: Array = await rendered_samples(lane.viewport)
		check("paused gameplay visibly previews brightness", paused and light[0] > dark[0] + 0.05)
		probe.queue_free()
		loop.audio.panel.brightness_slider.value = 0
		await shot(lane.viewport, "settings_ingame")
	paused = false
	lane.queue_free()
	await frames()
	Preferences.set_brightness(-20)
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._open_settings()
	menu.dialog.select_page(1, false)
	check("fresh title scene restores saved brightness", applied(menu.viewport) == -20 and menu.dialog.brightness_slider.value == -20)
	Preferences.set_value("game", "auto_run", true)
	menu.audio.set_music_volume(0.37)
	menu.dialog._reset_page()
	check("display reset restores neutral rendering and slider", Preferences.brightness() == 0 and applied(menu.viewport) == 0 and menu.dialog.brightness_slider.value == 0 and menu.dialog.get_node("BrightnessValue").text == "0")
	check("display reset preserves game and audio settings", Preferences.value("game", "auto_run", false) and is_equal_approx(menu.audio.music_volume, 0.37))
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		await frames()
		var label: Label = menu.dialog.get_node("BrightnessLabel")
		var translated := TranslationServer.translate(label.text)
		check("brightness label translated and fits " + locale, (locale == "zh_CN" or translated != label.text) and label.get_theme_font("font").get_string_size(translated, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x)
		await shot(menu.viewport, "settings_" + locale)
	menu.queue_free()
	await frames()
	Preferences.set_brightness(15)
	var notice = load("res://Scenes/MainMenu/startup_notice.tscn").instantiate()
	root.add_child(notice)
	check("startup notice inherits saved brightness", applied(notice.viewport) == 15)
	notice.queue_free()
	await frames()
	await create_timer(0.15).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("BRIGHTNESS VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
