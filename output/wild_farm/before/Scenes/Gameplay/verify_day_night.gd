extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Cycle = preload("res://Scenes/Gameplay/day_night_cycle.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://Scenes/Gameplay/Verification/DayNight/"
var failures := 0
var capture := false
var lane
var loop

func _initialize() -> void:
	capture = "--daynight-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("DAY NIGHT TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func at_time(state, minutes: float) -> void:
	state.phase = "day" if minutes < 1080.0 else "night"
	state.remaining = State.DAY_SECONDS * (1080.0 - minutes) / 720.0 if state.phase == "day" else State.NIGHT_SECONDS * (1320.0 - minutes) / 240.0

func shot(title: String) -> void:
	if not capture:
		return
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)

func run() -> void:
	var state := State.new()
	check("nine-minute day and five-minute service", State.DAY_SECONDS == 540.0 and State.NIGHT_SECONDS == 300.0 and State.DAY_LENGTH_SECONDS == 840.0)
	check("new day starts at 06:00", state.get_time_text() == "06:00" and state.get_time_of_day() == "morning")
	for sample in [[360.0, "06:00"], [373.0, "06:00"], [389.99, "06:00"], [390.0, "06:30"], [419.99, "06:30"], [420.0, "07:00"], [1319.0, "21:30"]]:
		at_time(state, sample[0])
		check("half-hour clock at " + str(sample[0]), state.get_time_text() == sample[1] and is_equal_approx(state.get_time_minutes(), sample[0]))
	for sample in [[360, "morning"], [539, "morning"], [540, "day"], [1019, "day"], [1020, "evening"], [1080, "evening"], [1199, "evening"], [1200, "night"], [1319, "night"]]:
		at_time(state, sample[0])
		check("period boundary " + str(sample[0]), state.get_time_of_day() == sample[1])
		var restored := State.new()
		check("saved clock restores " + str(sample[0]), restored.restore_save_data(state.to_save_data()) and is_equal_approx(restored.get_time_minutes(), state.get_time_minutes()) and restored.get_time_of_day() == sample[1])
	for sample in [["day", 90.0, 720.0, 270.0], ["night", 60.0, 1200.0, 150.0], ["result", 0.0, 1320.0, 0.0]]:
		var legacy: Dictionary = State.new().to_save_data()
		legacy.erase("day_length_seconds")
		legacy.erase("day_seconds")
		legacy.erase("night_seconds")
		legacy.phase = sample[0]
		legacy.remaining = sample[1]
		var migrated := State.new()
		check("legacy save keeps phase progress in " + sample[0], migrated.restore_save_data(legacy) and is_equal_approx(migrated.get_time_minutes(), sample[2]) and is_equal_approx(migrated.remaining, sample[3]))
		var normalized := State.normalize_save_data(legacy)
		check("save normalization scales only once in " + sample[0], State.normalize_save_data(normalized) == normalized and migrated.restore_save_data(normalized) and is_equal_approx(migrated.get_time_minutes(), sample[2]))
	state = State.new()
	state.tick(135.0)
	check("timer reaches daytime at 09:00", state.get_time_text() == "09:00" and state.get_time_of_day() == "day")
	state.tick(360.0)
	check("timer reaches evening at 17:00", state.get_time_text() == "17:00" and state.get_time_of_day() == "evening")
	state.tick(45.0)
	check("sunset waits for menu confirmation at 18:00", state.phase == "day" and state.get_time_text() == "18:00" and state.get_time_of_day() == "evening")
	state.tick(999.0)
	check("unopened service stays at 18:00", state.phase == "day" and state.remaining == 0.0 and state.customers.is_empty())
	state.set_menu_dish(0, true)
	check("confirmed service begins at 18:00", state.start_service() and state.get_time_text() == "18:00")
	state.tick(150.0)
	check("timer reaches night at 20:00", state.get_time_text() == "20:00" and state.get_time_of_day() == "night")
	state.tick(149.0)
	check("service stays open until the last second", state.phase == "night" and state.remaining == 1.0)
	state.tick(1.0)
	check("settlement freezes at 22:00", state.phase == "result" and state.get_time_text() == "22:00" and state.get_time_of_day() == "night")
	state.tick(999.0)
	check("settlement clock does not advance", state.get_time_text() == "22:00")
	state.next_day()
	check("next day resets to morning", state.day == 2 and state.get_time_text() == "06:00")
	state.end_phase()
	check("manual service jumps clock to 18:00", state.get_time_text() == "18:00")
	for boundary in [540.0, 960.0, 1020.0, 1080.0, 1200.0, 1320.0]:
		var before := Cycle.outdoor_color(boundary - 0.01)
		var after := Cycle.outdoor_color(boundary + 0.01)
		check("continuous lighting at " + str(boundary), absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) < 0.001)
	Saves.end_session()
	Preferences.file_path = "res://output/restaurant_service/daynight_preferences.cfg"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	var cycle = loop.day_night
	check("one canvas modulator in gameplay viewport", cycle.modulation.get_viewport() == lane.viewport and cycle.get_parent() == lane.viewport)
	var lamp_count: int = cycle.lights.get_child_count()
	check("town lamps follow six map fixtures", lamp_count == 6)
	for sample in [[373.0, "06:00", 360.0], [389.99, "06:00", 360.0], [390.0, "06:30", 390.0], [419.99, "06:30", 390.0], [420.0, "07:00", 420.0]]:
		at_time(loop.state, sample[0])
		loop._sync_phase()
		loop._refresh()
		check("HUD text and hands update together at " + str(sample[0]), loop.hud.time_label.text == sample[1] and is_equal_approx(loop.hud.clock_art.progress, sample[2] / 720.0))
	for sample in [[420.0, "morning"], [720.0, "day"], [1110.0, "evening"], [1260.0, "night"]]:
		at_time(loop.state, sample[0])
		loop._sync_phase()
		if loop.location != "town":
			loop.enter("town")
		loop._refresh()
		check("scene and HUD share " + sample[1], cycle.time_of_day == sample[1] and loop.hud.time_label.text == loop.state.get_time_text() and loop.hud.period_label.text == loop.state.get_time_of_day_name())
		check("sun and moon match " + sample[1], loop.hud.weather_art.night == (sample[1] == "night"))
		check("world tint matches " + sample[1], cycle.modulation.color.is_equal_approx(Cycle.outdoor_color(sample[0])))
		await shot("town_" + sample[1] + ("_midday" if sample[1] == "day" else ""))
	check("night lamps emit light", cycle.lamp_strength == 1.0 and cycle.lights.get_child(0).enabled and cycle.lights.get_child(0).energy > 0.0)
	var night_color: Color = cycle.modulation.color
	for target in ["home", "restaurant", "blacksmith", "store"]:
		loop.enter(target)
		loop._refresh()
		check("indoor light readable in " + target, cycle.modulation.color.r > 0.85 and cycle.modulation.color.g > 0.85 and cycle.lights.get_child_count() == 0)
		await shot(target + "_night")
	loop.enter("town")
	check("return outdoors restores night lighting", cycle.modulation.color.is_equal_approx(night_color) and cycle.lights.get_child_count() == lamp_count)
	loop.enter("farm")
	check("farm shares outdoor night and has two lamps", cycle.modulation.color.is_equal_approx(night_color) and cycle.lights.get_child_count() == 2)
	loop.enter("town")
	for weather in ["rain", "snow", "clear"]:
		lane.weather.set_weather(weather)
		await frames()
		check("weather retains nighttime tint " + weather, cycle.modulation.color.is_equal_approx(night_color) and lane.weather.get_weather() == weather)
		await shot("night_" + weather)
	at_time(loop.state, 600.0)
	loop._sync_phase()
	for target in ["field", "dock", "farm", "town"]:
		loop.enter(target)
		check("outdoor daylight in " + target, cycle.modulation.color.is_equal_approx(Color.WHITE))
		await shot(target + "_day")
	check("daytime lamps switch off after rebuild", cycle.lamp_strength == 0.0 and not cycle.lights.get_child(0).enabled)
	# Real ticking and the same modal pause path used by the player.
	at_time(loop.state, 539.9)
	loop.paused_for_test = false
	await create_timer(0.25).timeout
	check("real timer changes period", cycle.time_of_day == "day" and loop.hud.period_label.text == "白天")
	loop.hud.open_journal()
	var remaining: float = loop.state.remaining
	var paused_color: Color = cycle.modulation.color
	await create_timer(0.15, true).timeout
	check("journal pauses clock and lighting", paused and loop.state.remaining == remaining and cycle.modulation.color.is_equal_approx(paused_color))
	loop.hud.close_modal()
	loop.paused_for_test = true
	# Fresh scene startup restores lighting directly from the existing save schema.
	at_time(loop.state, 1260.0)
	var snapshot: Dictionary = loop.state.to_save_data()
	Saves.pending = {"state": snapshot, "world": {"location": "town", "position": [408, 364], "town_position": [408, 364], "facing": 0, "weather": "rain"}}
	lane.queue_free()
	await create_timer(0.2).timeout
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	check("fresh scene loads saved night and weather", loop.location == "town" and loop.day_night.time_of_day == "night" and lane.weather.get_weather() == "rain" and loop.hud.time_label.text.begins_with("21:"))
	loop.state.remaining = 0.01
	loop.paused_for_test = false
	await create_timer(0.1).timeout
	check("night ends at dark settlement", loop.state.phase == "result" and loop.day_night.time_of_day == "night")
	loop.end_phase()
	loop._refresh()
	check("next day restores morning HUD and lamps", loop.location == "town" and loop.day_night.time_of_day == "morning" and loop.hud.period_label.text == "早上" and loop.day_night.lamp_strength == 0.0)
	loop.paused_for_test = true
	loop.state.remaining = 0.01
	loop.paused_for_test = false
	await create_timer(0.1).timeout
	check("sunset enters lit restaurant for preparation", loop.state.phase == "day" and loop.state.remaining == 0.0 and loop.location == "restaurant" and loop.day_night.time_of_day == "evening" and loop.day_night.modulation.color.r > 0.85)
	if capture:
		var overview := Image.create(1280, 720, false, Image.FORMAT_RGB8)
		var names := ["town_morning", "town_day_midday", "town_evening", "town_night"]
		for i in range(names.size()):
			var pixels := Image.load_from_file(OUT + names[i] + ".png")
			pixels.convert(Image.FORMAT_RGB8)
			overview.blit_rect(pixels, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
		check("four-period preview saved", overview.save_png(OUT + "overview.png") == OK)
		var day_pixels := Image.load_from_file(OUT + "town_day_midday.png")
		var night_pixels := Image.load_from_file(OUT + "town_night.png")
		check("rendered night is darker than day", night_pixels.get_pixel(100, 220).get_luminance() < day_pixels.get_pixel(100, 220).get_luminance())
		check("rendered HUD frame is unaffected by lighting", night_pixels.get_pixel(12, 12).is_equal_approx(day_pixels.get_pixel(12, 12)))
	lane.queue_free()
	await create_timer(0.2).timeout
	print("DAY NIGHT VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
