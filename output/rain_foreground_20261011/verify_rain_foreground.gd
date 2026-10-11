extends SceneTree
## Isolated actual-scene render probes for the house-shaped gap in foreground rain.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const OUT := "res://output/rain_foreground_20261011/"
var lane
var loop
var failures := 0
var checks := 0
var render := false

func _initialize() -> void:
	var profile := OUT + "profile_" + str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile + "/preferences.cfg"
	Saves.directory = profile + "/saves"
	Saves.end_session()
	render = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("RAIN FOREGROUND ", title, ": ", "PASS" if ok else "FAIL")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func pixels() -> Image:
	lane.weather.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	return lane.viewport.get_texture().get_image()

func close_color(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) < 0.02 and absf(actual.g - expected.g) < 0.02 and absf(actual.b - expected.b) < 0.02

func probe_house(title: String, position: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	lane.player.position = position
	lane.camera.position = offset
	lane.camera.force_update_scroll()
	await frames()
	lane.weather._process(0.0)
	check(title + " screen coverage", lane.weather.get_global_transform_with_canvas().origin.is_equal_approx(Vector2.ZERO))
	check(title + " has house splash exclusion", not lane.weather.roof_rects.is_empty())
	if not render: return
	var roof: Rect2 = lane.weather.roof_rects[0]
	var screen_roof := Rect2(roof.position - lane.weather._world_at(Vector2.ZERO), roof.size).intersection(Rect2(8, 8, 624, 344))
	check(title + " house visible", screen_roof.size.x > 20 and screen_roof.size.y > 20)
	# HUD intentionally covers weather; isolate world pixels for these probes.
	var ui_visibility := {}
	for canvas in lane.find_children("*", "CanvasLayer", true, false):
		ui_visibility[canvas] = canvas.visible
		canvas.hide()
	lane.weather.set_weather("rain")
	lane.weather.rain.clear()
	lane.weather.splashes.clear()
	var clear := await pixels()
	var probes: Array[Vector2] = []
	for x in [0.08, 0.5, 0.92]:
		for y in [0.25, 0.75]:
			var point: Vector2 = (screen_roof.position + screen_roof.size * Vector2(x, y)).round()
			probes.append(point)
			lane.weather.rain.append({"x": point.x, "y": point.y, "speed": 0.0, "length": 8, "landing": 360.0})
	var ground: Vector2 = (screen_roof.end + Vector2(10, 10)).clamp(Vector2(8, 8), Vector2(630, 348)).round()
	lane.weather.rain.append({"x": ground.x, "y": ground.y, "speed": 0.0, "length": 8, "landing": 360.0})
	var image := await pixels()
	for i in range(probes.size()):
		var point := probes[i]
		check(title + " rain across house " + str(i), close_color(image.get_pixelv(Vector2i(point)), lane.weather.RAIN_COLOR))
	check(title + " ground rain", close_color(image.get_pixelv(Vector2i(ground)), lane.weather.RAIN_COLOR))
	# The house should still exclude ground splashes after foreground rain is restored.
	lane.weather.rain.clear()
	var impact := probes[3]
	lane.weather.splashes.append({"world": lane.weather._world_at(impact), "life": 0.16})
	image = await pixels()
	check(title + " no ground splash on house", close_color(image.get_pixelv(Vector2i(impact)), clear.get_pixelv(Vector2i(impact))))
	lane.weather.splashes.clear()
	# Retain the small player exclusion while the rest of the rain remains foreground.
	var face: Vector2 = (lane.player.global_position - lane.weather._world_at(Vector2.ZERO) + Vector2(0, -16)).round()
	lane.weather.rain.append({"x": face.x, "y": face.y, "speed": 0.0, "length": 5, "landing": 360.0})
	image = await pixels()
	check(title + " player stays readable", close_color(image.get_pixelv(Vector2i(face)), clear.get_pixelv(Vector2i(face))))
	lane.weather.rain.clear()
	lane.weather._make_particles()
	for canvas in ui_visibility: canvas.visible = ui_visibility[canvas]
	lane.weather.set_process(true)
	await frames(30)
	image = await pixels()
	var method := RenderingServer.get_current_rendering_method()
	check(title + " save natural rain", image.save_png(OUT + title + "_" + method + ".png") == OK)
	lane.weather.set_process(false)

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.automation = true
	lane.set_physics_process(false)
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.campaign_controller.set_process(false)
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	loop.state.phase = "day"
	loop.state.remaining = State.DAY_SECONDS * 0.25
	loop.day_night.sync(loop.state)
	lane.weather.set_weather("rain")
	var rain_y: float = lane.weather.rain[0].y
	await frames(10)
	check("rain moves", lane.weather.rain[0].y != rain_y)
	lane.weather.set_weather("snow")
	var snow_y: float = lane.weather.snow[0].y
	await frames(10)
	check("snow moves", lane.weather.snow[0].y != snow_y)
	lane.weather.set_process(false)
	await probe_house("farm_house", Vector2(350, 315), Vector2(0, -135))
	await probe_house("farm_camera_moved", Vector2(400, 350))
	loop.enter("home")
	check("indoor weather hidden", not lane.weather.visible)
	loop.enter("farm")
	check("farm restores rain", lane.weather.visible and lane.weather.get_weather() == "rain")
	loop.enter("town")
	var roof: Rect2 = lane.weather.roof_rects[0]
	await probe_house("town_house", roof.get_center() + Vector2(0, 140), Vector2(0, -140))
	lane.weather.clear_weather()
	check("clear weather", lane.weather.get_weather() == "clear" and lane.weather.splashes.is_empty())
	print("RAIN FOREGROUND VERIFY END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
