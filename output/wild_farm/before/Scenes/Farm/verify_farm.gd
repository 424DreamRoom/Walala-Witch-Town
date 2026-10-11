extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
const OUT := "res://Scenes/Farm/Verification/"
var lane
var loop
var failures := 0
var capture := "--farm-capture" in OS.get_cmdline_user_args()

func _initialize() -> void:
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("FARM ", title, ": PASS" if ok else ": FAIL")
	if not ok:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame
		await physics_frame

func key() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()
	await create_timer(0.28).timeout

func shot(title: String) -> void:
	if not capture:
		return
	loop.state.message = ""
	loop.last_message = ""
	loop.message_left = 0.0
	lane.camera.force_update_scroll()
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)
	check("window capture " + title, root.get_texture().get_image().save_png(OUT + title + "_window.png") == OK)

func next_day(s) -> void:
	s.end_phase()
	s.end_phase()
	s.next_day()

func state_checks() -> void:
	var s = State.new()
	check("starter seeds and full water", s.farm.seeds == 12 and s.farm.water == 24 and s.farm.plots.is_empty())
	s.tools.wand = 0
	check("wand required without modifying soil", not s.work_farm_tile(0) and s.farm.plots.is_empty())
	s.tools.wand = 1
	check("till soil", s.work_farm_tile(0) and s.farm.plots["0"].growth == -1)
	check("plant consumes one seed", s.work_farm_tile(0) and s.farm.seeds == 11 and s.farm.plots["0"].growth == 0)
	next_day(s)
	check("dry crop survives without growing", s.farm.plots["0"].growth == 0)
	s.tools.wand = 0
	check("watering can required", not s.work_farm_tile(0) and s.farm.water == 24)
	s.tools.wand = 1
	s.farm.water = 0
	check("empty can leaves crop dry", not s.work_farm_tile(0) and not s.farm.plots["0"].watered)
	check("refill capacity", s.refill_farm_water() and s.farm.water == 24)
	check("water consumes one unit", s.work_farm_tile(0) and s.farm.water == 23)
	check("repeated water cannot drain can", not s.work_farm_tile(0) and s.farm.water == 23)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_save_data()))
	var restored = State.new()
	check("JSON restores watered crop and supplies", restored.restore_save_data(saved) and restored.farm == s.farm)
	for i in range(3):
		if i > 0:
			s.rain_on_farm()
		next_day(s)
		check("watered growth day " + str(i + 1), s.farm.plots["0"].growth == i + 1 and not s.farm.plots["0"].watered)
	var mature: Dictionary = s.farm.plots["0"].duplicate(true)
	# One wand and one seed stack occupy two slots in the current bag model.
	s.raw = [State.Items.STACK_SIZE * (s.bag_capacity() - 2), 0, 0]
	check("full backpack preserves mature crop", not s.work_farm_tile(0) and s.farm.plots["0"] == mature)
	s.raw = [0, 0, 0]
	check("harvest shares herb inventory and returns seeds", s.work_farm_tile(0) and s.raw[2] == 1 and s.farm.seeds == 13)
	check("harvest preserves tilled soil", s.farm.plots["0"].growth == -1)
	s.farm.seeds = 0
	check("empty seed bag does not plant", not s.work_farm_tile(0) and s.farm.plots["0"].growth == -1)
	check("sell crop to shared wallet", s.business_transaction("sell_herb") and s.coins == 3 and s.raw[2] == 0)
	check("buy four seeds", s.business_transaction("buy_seeds") and s.coins == 1 and s.farm.seeds == 4)
	check("insufficient gold cannot buy seeds", not s.business_transaction("buy_seeds") and s.farm.seeds == 4)
	check("replant harvested plot", s.work_farm_tile(0) and s.farm.plots["0"].growth == 0)
	s.phase = "night"
	check("night prevents farming and seed purchases", not s.work_farm_tile(1) and not s.can_business("buy_seeds"))
	s.phase = "day"
	check("out of bounds tile rejected", not s.work_farm_tile(-1) and not s.work_farm_tile(96))
	var old: Dictionary = s.to_save_data()
	old.erase("farm")
	old.erase("bag_slots")
	old.erase("bag_overflow")
	check("existing save receives starter farm", restored.restore_save_data(old) and restored.farm == State.STARTING_FARM)
	for bad in [{"plots": {"96": {"growth": 0, "watered": false}}, "seeds": 12, "water": 24}, {"plots": {}, "seeds": -1, "water": 24}, {"plots": {}, "seeds": 12, "water": 25}, {"plots": {"0": {"growth": 9, "watered": false}}, "seeds": 12, "water": 24}, {"plots": {"0": {"growth": 0, "watered": 1}}, "seeds": 12, "water": 24}]:
		var broken: Dictionary = s.to_save_data()
		broken.farm = bad
		check("malformed farming data rejected", State.normalize_save_data(broken).is_empty())

func rain_checks() -> void:
	var s = State.new()
	s.work_farm_tile(0)
	s.work_farm_tile(1)
	s.work_farm_tile(1)
	s.farm.plots["2"] = {"growth": State.FARM_GROWTH_DAYS, "watered": false}
	s.farm.water = 0
	s.tools.wand = 0
	var seeds: int = s.farm.seeds
	s.rain_on_farm()
	check("rain wets empty soil, seedlings and mature crops", s.farm.plots["0"].watered and s.farm.plots["1"].watered and s.farm.plots["2"].watered)
	check("rain needs no wand or stored water and preserves seeds", s.farm.water == 0 and s.farm.seeds == seeds)
	var restored = State.new()
	check("wet empty soil and mature crops survive JSON restore", restored.restore_save_data(JSON.parse_string(JSON.stringify(s.to_save_data()))) and restored.farm == s.farm)
	for index in [0, 1, 2]: s.farm.plots[str(index)].watered = false
	s.phase = "night"
	s.rain_on_farm()
	check("night rain wets every tilled plot", s.farm.plots["0"].watered and s.farm.plots["1"].watered and s.farm.plots["2"].watered)
	s.end_phase()
	s.next_day()
	check("night rain grows seedlings but leaves empty and mature plots unchanged", s.farm.plots["0"].growth == -1 and s.farm.plots["1"].growth == 1 and s.farm.plots["2"].growth == State.FARM_GROWTH_DAYS)
	check("new clear day dries soil", not s.farm.plots["0"].watered and not s.farm.plots["1"].watered and not s.farm.plots["2"].watered)
	next_day(s)
	check("later dry day pauses growth", s.farm.plots["1"].growth == 1)
	s.phase = "result"
	s.rain_on_farm()
	check("settlement does not advance soil moisture", not s.farm.plots["1"].watered)
	# Every crop uses the same wet soil, including crops that regrow after harvest.
	for crop in State.Content.DATA.crops:
		s = State.new()
		s.day = 1 + int(crop.seasons[0]) * 28
		s.campaign.selected_crop = crop.id
		s.campaign.seeds[crop.id] = 1
		s.work_farm_tile(0)
		s.rain_on_farm()
		s.farm.water = 0
		check("wet soil stays wet after planting " + crop.id, s.work_farm_tile(0) and s.farm.plots["0"].watered and s.farm.water == 0)
		check("wet crop needs no manual watering " + crop.id, not s.work_farm_tile(0) and s.farm.water == 0)
		next_day(s)
		check("rainwater grows planted crop " + crop.id, s.farm.plots["0"].growth == 1 and not s.farm.plots["0"].watered)
		s.farm.plots["0"].growth = crop.days
		s.rain_on_farm()
		check("harvest preserves wet soil " + crop.id, s.work_farm_tile(0) and s.farm.plots["0"].watered and s.farm.water == 0)

func run() -> void:
	Preferences.file_path = "user://farm_verification_%d.cfg" % OS.get_process_id()
	Saves.directory = "res://output/farm_test_saves_" + str(Time.get_ticks_usec())
	state_checks()
	rain_checks()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	var town: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(loop.lane.ART + "town_layout.json"))
	check("old home removed from town", town.buildings.size() == 8 and not town.gates.has("home"))
	check("west road farm entrance", loop.FARM_GATE == Vector2(8, 364))
	check("real walk from town to farm", await Navigation.walk(lane, loop.FARM_GATE))
	check("independent farm owns player", loop.location == "farm" and lane.player.get_parent() == loop.area and not lane.world.is_inside_tree())
	if loop.location != "farm":
		quit(1)
		return
	check("farm camera bounds", lane.camera.limit_right == 960 and lane.camera.limit_bottom == 720)
	check("outdoor weather and roof shelter", lane.weather.visible and lane.weather.roof_rects.size() == 1)
	check("farm daylight controller and lamps", loop.day_night.location == "farm" and loop.day_night.lights.get_child_count() == 2)
	check("farm soil footsteps", loop.footstep_surfaces.resolve("farm", Vector2(208, 400), "clear") == "dirt")
	check("farm snow footsteps", loop.footstep_surfaces.resolve("farm", Vector2(208, 400), "snow") == "snow")
	await shot("farm_arrival")
	check("real walk to relocated home", await Navigation.walk(lane, loop.area.stations.home))
	check("home doorway requires interaction", loop.location == "farm")
	await key()
	check("home interior reached from farm", loop.location == "home" and not lane.weather.visible)
	var home_position: Vector2 = loop.farm_position
	check("home saves return to front doorstep", home_position == Vector2(270, 258))
	check("real walk out of home", await Navigation.walk(lane, loop.area.stations.exit))
	check("home exit requires interaction", loop.location == "home")
	await key()
	check("home returns to farm", loop.location == "farm" and lane.player.position.distance_to(home_position) < 0.1)
	await shot("farm_house")
	for target in [Vector2(208, 384), Vector2(560, 384), Vector2(208, 608), Vector2(560, 608), loop.area.stations.refill, loop.area.stations.well]:
		check("clear farm route " + str(target), not Navigation.route(lane, target).is_empty())
	check("real walk to first tile", await Navigation.walk(lane, Vector2(208, 360)))
	lane.facing = 0
	await frames()
	check("facing selects reachable first tile", loop.area.selected_tile() == 0)
	await key()
	check("E tills actual farm tile", loop.state.farm.plots.has("0") and loop.state.farm.plots["0"].growth == -1)
	await key()
	check("E plants actual farm tile", loop.state.farm.plots["0"].growth == 0 and loop.state.farm.seeds == 11)
	await key()
	check("E waters actual farm tile", loop.state.farm.plots["0"].watered and loop.state.farm.water == 23)
	await shot("farm_planted")
	check("real walk to pond refill", await Navigation.walk(lane, loop.area.stations.refill))
	await key()
	check("pond E refills shared watering can", loop.state.farm.water == 24)
	await shot("farm_pond")
	var pond_end: Vector2 = await lane._walk(Vector2(774, 580), Vector2.UP, 60)
	check("pond collision keeps feet out of water", pond_end.y >= 555.9)
	lane.weather.set_weather("rain")
	lane.player.position = Vector2(560, 584)
	lane.facing = 0
	await frames()
	await key()
	check("rain wets newly tilled soil in actual farm", loop.state.farm.plots.has("95") and loop.state.farm.plots["95"].growth == -1 and loop.state.farm.plots["95"].watered)
	await key()
	check("rainy planting preserves wet soil without spending water", loop.state.farm.plots["95"].growth == 0 and loop.state.farm.plots["95"].watered and loop.state.farm.water == 24)
	await key()
	check("rainy interaction cannot spend water", loop.state.farm.water == 24)
	loop.enter("home")
	await frames()
	loop.state.farm.plots["0"].watered = false
	lane.weather.set_weather("rain")
	await frames()
	check("rain waters farm while player is indoors", loop.state.farm.plots["0"].watered and not lane.weather.visible)
	loop.state.phase = "night"
	loop.state.remaining = State.NIGHT_SECONDS
	loop.last_phase = "night"
	loop.state.farm.plots["0"].watered = false
	await frames()
	check("night rain reaches farm while player is indoors", loop.state.farm.plots["0"].watered and not lane.weather.visible)
	loop.state.phase = "day"
	loop.state.remaining = State.DAY_SECONDS
	loop.last_phase = "day"
	lane.weather.clear_weather()
	await frames()
	check("rain stopping preserves wet soil and stored water", loop.state.farm.plots["0"].watered and loop.state.farm.plots["95"].watered and loop.state.farm.water == 24)
	var now := int(Time.get_unix_time_from_system())
	Saves.active_slot = 1
	Saves.created_at = now
	check("home with farm state can save", loop.save_progress().ok)
	var disk := Saves.read_slot(1)
	check("disk save retains crop and supplies", disk.ok and disk.data.state.farm == loop.state.farm)
	check("disk save retains home return", disk.ok and Vector2(disk.data.world.farm_position[0], disk.data.world.farm_position[1]) == Vector2(270, 258))
	loop.enter("town")
	loop._restore_world(disk.data.world)
	await frames()
	check("real walk to restored home exit", await Navigation.walk(lane, loop.area.stations.exit))
	await key()
	check("restored home exits to farm", loop.location == "farm")
	check("farm itself can save", loop.save_progress().ok)
	disk = Saves.read_slot(1)
	check("farm location accepted in save schema", disk.ok and disk.data.world.location == "farm")
	loop.enter("town")
	loop._restore_world(disk.data.world)
	await frames()
	check("farm load restores player and camera", loop.location == "farm" and lane.camera.limit_bottom == 720)
	Saves.end_session()
	for suffix in ["", ".bak", ".tmp"]:
		var file_path: String = Saves.slot_path(1) + suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	Saves.directory = "user://saves"
	# Presentation fixture uses real state transitions to show growth stages.
	for index in range(1, 24):
		loop.state.work_farm_tile(index)
		loop.state.farm.seeds = maxi(1, loop.state.farm.seeds)
		loop.state.work_farm_tile(index)
	for day_index in range(3):
		loop.state.rain_on_farm()
		next_day(loop.state)
	loop.last_phase = loop.state.phase
	check("planted crop matures across three days", loop.state.farm.plots["0"].growth == 3)
	lane.player.position = Vector2(352, 472)
	lane.facing = 1
	await shot("farm_mature")
	lane.player.position = Vector2(208, 360)
	lane.facing = 0
	await key()
	check("E harvest puts crop in existing backpack", loop.state.raw[2] == 1 and loop.state.farm.plots["0"].growth == -1)
	check("real walk back to town", await Navigation.walk(lane, loop.area.stations.exit))
	check("return reaches marked town entrance with town collisions restored", loop.location == "town" and lane.player.position.distance_to(loop.FARM_GATE) < 0.1 and lane.world.is_inside_tree())
	check("crops persist after farm is detached", loop.state.farm.plots["1"].growth == 3)
	loop.set_process(false)
	loop.audio.set_process(false)
	if is_instance_valid(loop.audio.fade): loop.audio.fade.kill()
	for player in loop.audio.get_children():
		if player is AudioStreamPlayer: player.stop()
	await create_timer(0.1).timeout
	lane.queue_free()
	await frames()
	await create_timer(0.2).timeout
	print("FARM VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
