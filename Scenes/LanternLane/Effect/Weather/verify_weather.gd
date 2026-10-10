extends SceneTree
## Bounded integration verification; --weather-render saves new screenshots only.
var lane
var failures := 0
var render := false
var output_dir := "res://Scenes/LanternLane/Effect/Weather/Verification/"

func _initialize() -> void:
	render = "--weather-render" in OS.get_cmdline_user_args()
	_run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("WEATHER TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)

func shot(title: String) -> Image:
	await frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = lane.viewport.get_texture().get_image()
	check("save " + title, image.save_png(output_dir + title + ".png") == OK)
	return image

func _run() -> void:
	print("WEATHER VERIFY START")
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	lane.automation = true
	await frames(5)
	var weather = lane.weather
	check("default clear", weather.get_weather() == "clear")
	if render:
		output_dir += RenderingServer.get_current_rendering_method() + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var baseline: Image
	if render:
		baseline = await shot("clear")
	key(KEY_2)
	await frames(3)
	check("input 2 rain", weather.get_weather() == "rain")
	var rain_y: float = weather.rain[0].y
	await frames(20)
	check("rain process moves", weather.rain[0].y != rain_y)
	if render:
		var image := await shot("rain")
		check("rain changes pixels", image.get_data() != baseline.get_data())
	key(KEY_3)
	await frames(3)
	check("input 3 snow", weather.get_weather() == "snow")
	var snow_y: float = weather.snow[0].y
	await frames(20)
	check("snow process moves", weather.snow[0].y != snow_y)
	if render:
		await shot("snow")
	key(KEY_1)
	await frames(3)
	check("input 1 clear", weather.get_weather() == "clear")
	if render:
		var cleared := await shot("clear_after")
		check("clear removes all weather pixels", cleared.get_data() == baseline.get_data())
	for mode in ["rain", "snow"]:
		weather.set_weather(mode)
		var pos: Vector2 = await lane._walk(Vector2(408,364), Vector2.RIGHT, 40)
		check(mode + " movement", absf(pos.x - 468.0) < 3.0)
		pos = await lane._walk(Vector2(224,340), Vector2.UP, 60)
		check(mode + " building collision", pos.y >= 293.9 and pos.y < 296.0)
		for corner in [Vector2(24,24), Vector2(1256,936), Vector2(808,684)]:
			lane.player.position = corner
			lane.camera.force_update_scroll()
			await frames(3)
			check(mode + " screen overlay transform " + str(corner), weather.get_global_transform_with_canvas().origin.is_equal_approx(Vector2.ZERO))
			if render:
				await shot(mode + "_" + str(int(corner.x)) + "_" + str(int(corner.y)))
	weather.clear_weather()
	print("WEATHER VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
