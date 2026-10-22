extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
const OUT := "res://output/wild_farm/Verification/"
var lane
var loop
var failures := 0
var capture := "--farm-capture" in OS.get_cmdline_user_args()

func _initialize() -> void:
	var profile := "res://output/wild_farm/profile_" + str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile + "/preferences.cfg"
	Saves.directory = profile + "/saves"
	Saves.end_session()
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
	while root.get_node("SceneTransition").active:
		await frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = root.get_visible_rect().size / 2.0
		event.pressed = pressed
		root.push_input(event, true)
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
	s.menu[0] = true
	s.end_phase()
	s.end_phase()
	s.next_day()

func state_checks() -> void:
	var s = bare_state()
	check("starter seeds and full water", s.farm.seeds == 12 and s.farm.water == 24 and s.farm.plots.is_empty())
	s.tools.wand = 0
	check("wand required without modifying soil", not s.work_farm_tile(0) and s.farm.plots.is_empty())
	s.tools.wand = 1
	check("till soil", s.work_farm_tile(0) and s.farm.plots["0"].growth == -1)
	s.select_hotbar_slot(1)
	check("plant consumes one seed", s.work_farm_tile(0) and s.farm.seeds == 11 and s.farm.plots["0"].growth == 0)
	s.select_hotbar_slot(0)
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
	var restored = bare_state()
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
	s.select_hotbar_slot(1)
	check("replant harvested plot", s.work_farm_tile(0) and s.farm.plots["0"].growth == 0)
	s.phase = "night"
	check("night prevents farming and seed purchases", not s.work_farm_tile(1) and not s.can_business("buy_seeds"))
	s.phase = "day"
	check("out of bounds tile rejected", not s.work_farm_tile(-1) and not s.work_farm_tile(State.FARM_TILE_COUNT))
	var old: Dictionary = s.to_save_data()
	old.erase("farm")
	old.erase("bag_slots")
	old.erase("bag_overflow")
	check("existing save receives starter farm", restored.restore_save_data(old) and restored.farm == State.STARTING_FARM)
	for bad in [{"plots": {str(State.FARM_TILE_COUNT): {"growth": 0, "watered": false}}, "seeds": 12, "water": 24}, {"plots": {}, "seeds": -1, "water": 24}, {"plots": {}, "seeds": 12, "water": 25}, {"plots": {"0": {"growth": 9, "watered": false}}, "seeds": 12, "water": 24}, {"plots": {"0": {"growth": 0, "watered": 1}}, "seeds": 12, "water": 24}]:
		var broken: Dictionary = s.to_save_data()
		broken.farm = bad
		check("malformed farming data rejected", State.normalize_save_data(broken).is_empty())

func rain_checks() -> void:
	var s = bare_state()
	s.work_farm_tile(0)
	s.work_farm_tile(1)
	s.select_hotbar_slot(1)
	s.work_farm_tile(1)
	s.farm.plots["2"] = {"growth": State.FARM_GROWTH_DAYS, "watered": false}
	s.farm.water = 0
	s.tools.wand = 0
	var seeds: int = s.farm.seeds
	s.rain_on_farm()
	check("rain wets empty soil, seedlings and mature crops", s.farm.plots["0"].watered and s.farm.plots["1"].watered and s.farm.plots["2"].watered)
	check("rain needs no wand or stored water and preserves seeds", s.farm.water == 0 and s.farm.seeds == seeds)
	var restored = bare_state()
	check("wet empty soil and mature crops survive JSON restore", restored.restore_save_data(JSON.parse_string(JSON.stringify(s.to_save_data()))) and restored.farm == s.farm)
	for index in [0, 1, 2]: s.farm.plots[str(index)].watered = false
	s.phase = "night"
	s.rain_on_farm()
	check("night rain wets every tilled plot", s.farm.plots["0"].watered and s.farm.plots["1"].watered and s.farm.plots["2"].watered)
	s.menu[0] = true
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
		s = bare_state()
		s.day = 1 + int(crop.seasons[0]) * 28
		s.campaign.selected_crop = crop.id
		s.campaign.seeds[crop.id] = 1
		s.work_farm_tile(0)
		s.rain_on_farm()
		s.farm.water = 0
		if crop.id == "herb": s.select_hotbar_slot(1)
		check("wet soil stays wet after planting " + crop.id, s.work_farm_tile(0) and s.farm.plots["0"].watered and s.farm.water == 0)
		check("wet crop needs no manual watering " + crop.id, not s.work_farm_tile(0) and s.farm.water == 0)
		next_day(s)
		check("rainwater grows planted crop " + crop.id, s.farm.plots["0"].growth == 1 and not s.farm.plots["0"].watered)
		s.farm.plots["0"].growth = crop.days
		s.rain_on_farm()
		check("harvest preserves wet soil " + crop.id, s.work_farm_tile(0) and s.farm.plots["0"].watered and s.farm.water == 0)


func bare_state():
	var state = State.new()
	state.restaurant_leased = true
	state.wand_mode = "blue"
	for entry in State.FarmTerrain.layout.props:
		state.resource_damage[entry.resource_id] = State.RESOURCE_HITS
	return state

func clearing_checks() -> void:
	var terrain = State.FarmTerrain
	for kind in ["wood", "ore", "weed"]:
		loop.state.wand_mode = "red"
		var candidates: Array = loop.area.resource_nodes.filter(func(node): return node.resource_kind == kind and node.available())
		check("initial natural obstacle " + kind, not candidates.is_empty())
		if candidates.is_empty(): continue
		var node = candidates[0]
		var entry: Dictionary = terrain.layout.props.filter(func(item): return item.resource_id == node.resource_id)[0]
		var index: int = int(entry.tiles[0])
		check("occupied land cannot be tilled " + kind, not loop.state.work_farm_tile(index))
		lane.player.position = node.anchor
		loop.harvest.paused_for_test = true
		var before: int = loop.state.resources.get(kind, 0)
		for hit in range(3):
			await key()
			check("real input begins clearing " + kind + str(hit), loop.harvest.busy())
			loop.harvest.paused_for_test = false
			loop.harvest.advance(loop.state.swing_seconds(kind))
			loop.harvest.paused_for_test = true
			if not node.available(): break
		check("clearing removes sprite and physics " + kind, not node.available() and not node.visible and node.collision_layer == 0 and not loop.area.solids.has(node.footprint))
		loop.state.wand_mode = "blue"
		check("cleared land becomes plantable " + kind, terrain.can_till(loop.state, index) and loop.state.work_farm_tile(index))
		if kind != "weed": check("clearing pays existing inventory " + kind, loop.state.resources[kind] == before + (3 if kind == "wood" else 2))
		var reward: Dictionary = loop.state.resources.duplicate()
		check("cleared obstacle cannot pay again " + kind, loop.state.strike_resource(node.resource_id, kind) == -1 and loop.state.resources == reward)
	loop.harvest.paused_for_test = false
	var ids: Dictionary = loop.state.resource_damage.duplicate()
	loop.state.resource_damage["field_test_tree"] = 3
	next_day(loop.state)
	check("homestead clearing persists while wild resources refresh", ids.keys().all(func(id): return loop.state.resource_damage.get(id, -1) == ids[id]) and not loop.state.resource_damage.has("field_test_tree"))
	loop.last_phase = loop.state.phase

func run() -> void:
	state_checks()
	rain_checks()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.state.restaurant_leased = true
	loop.paused_for_test = true
	loop.campaign_controller.set_process(false)
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	loop.enter("town")
	check("real walk from town to farm", await Navigation.walk(lane, loop.FARM_GATE))
	check("independent farm owns player", loop.location == "farm" and lane.player.get_parent() == loop.area and not lane.world.is_inside_tree())
	if loop.location != "farm":
		quit(1)
		return
	var terrain = State.FarmTerrain
	var layout: Dictionary = terrain.layout
	check("map area doubles exactly", Vector2i(layout.size[0], layout.size[1]) == terrain.WORLD_SIZE and int(layout.size[0]) * int(layout.size[1]) == 2 * 960 * 720)
	check("house is the only built structure", layout.buildings.size() == 1 and layout.props.all(func(item): return item.has("resource_id")) and layout.water.is_empty() and not layout.has("well"))
	check("new game has no prepared plots", loop.state.farm.plots.is_empty())
	check("farm camera bounds", lane.camera.limit_right == 1440 and lane.camera.limit_bottom == 960)
	check("outdoor weather and roof shelter", lane.weather.visible and lane.weather.roof_rects.size() == 1)
	check("only the house light remains", loop.day_night.lights.get_child_count() == 1)
	check("unworked land has grass footsteps", loop.footstep_surfaces.resolve("farm", Vector2(208, 400), "clear") == "grass")
	check("farm snow footsteps", loop.footstep_surfaces.resolve("farm", Vector2(208, 400), "snow") == "snow")
	check("all old plot IDs retain world positions", terrain.tile_center(0) == Vector2(208, 384) and terrain.tile_center(95) == Vector2(560, 608))
	await shot("farm_arrival")
	check("real walk to original house", await Navigation.walk(lane, loop.area.stations.home))
	await shot("farm_house")
	await key()
	check("home interior reached from farm", loop.location == "home" and not lane.weather.visible)
	check("home return keeps original doorstep", loop.farm_position == Vector2(270, 258))
	check("real walk out of home", await Navigation.walk(lane, loop.area.stations.exit))
	await key()
	check("home returns to farm", loop.location == "farm" and lane.player.position == Vector2(270, 258))
	await clearing_checks()

	# Existing crops are not covered by the expanded map's new vegetation.
	var covered: Dictionary = layout.props.filter(func(item): return item.resource_type == "wood" and loop.state.resource_left(item.resource_id) > 0)[0]
	var covered_tile: int = int(covered.tiles[0])
	loop.state.farm.plots[str(covered_tile)] = {"growth": 1, "watered": true}
	loop.enter("home")
	loop.enter("farm")
	check("older crop survives newly generated trees", loop.state.farm.plots[str(covered_tile)].growth == 1 and loop.area.resource_nodes.filter(func(node): return node.resource_id == covered.resource_id and node.available()).is_empty())

	# A cleared fixture exercises the existing planting and rain loop with real input.
	for node in loop.area.resource_nodes:
		if node.resource_kind == "fish": continue
		loop.state.resource_damage[node.resource_id] = State.RESOURCE_HITS
		node.refresh()
	loop.area.refresh_resources()
	loop.state.farm.plots.clear()
	loop.state.raw = [0, 0, 0]
	loop.state.farm.seeds = 12
	loop.state.farm.water = 24
	check("first original tile remains reachable", await Navigation.walk(lane, Vector2(208, 360)))
	lane.facing = 0
	await frames()
	check("facing selects reachable first tile", loop.area.selected_tile() == 0)
	await key()
	check("real input tills soil", loop.state.farm.plots.has("0") and loop.state.farm.plots["0"].growth == -1)
	loop.state.select_hotbar_slot(1)
	await key()
	check("real input plants seed", loop.state.farm.plots["0"].growth == 0 and loop.state.farm.seeds == 11)
	loop.state.select_hotbar_slot(0)
	await key()
	check("real input waters crop", loop.state.farm.plots["0"].watered and loop.state.farm.water == 23)
	check("house water remains reachable", await Navigation.walk(lane, loop.area.stations.refill))
	await key()
	check("house supply refills shared water", loop.state.farm.water == 24)
	var far_point := Vector2(1264, 864)
	var far_tile: int = terrain.index_at(far_point)
	check("new southern land has a valid unique ID", far_tile >= 96 and terrain.index_at(terrain.tile_center(far_tile)) == far_tile)
	check("expanded land is reachable", await Navigation.walk(lane, far_point - Vector2(0, 24)))
	lane.facing = 0
	lane.weather.set_weather("rain")
	await frames()
	await key()
	check("rain wets newly tilled expanded land", loop.state.farm.plots.has(str(far_tile)) and loop.state.farm.plots[str(far_tile)].watered)
	loop.state.select_hotbar_slot(1)
	await key()
	check("expanded land accepts crops", loop.state.farm.plots[str(far_tile)].growth == 0 and loop.state.farm.water == 24)
	await shot("expanded_farm_planted")
	loop.enter("home")
	loop.state.farm.plots["0"].watered = false
	await frames()
	check("rain waters farm while indoors", loop.state.farm.plots["0"].watered and not lane.weather.visible)
	lane.weather.clear_weather()
	for day_index in range(3):
		loop.state.rain_on_farm()
		next_day(loop.state)
	loop.last_phase = loop.state.phase
	check("crops mature on both original and expanded land", loop.state.farm.plots["0"].growth == 3 and loop.state.farm.plots[str(far_tile)].growth == 3)
	loop.enter("farm")
	lane.player.position = far_point
	Saves.active_slot = 1
	Saves.created_at = int(Time.get_unix_time_from_system())
	check("expanded farm position can save", loop.save_progress().ok)
	var disk := Saves.read_slot(1)
	check("disk save retains crops and permanent clearing", disk.ok and disk.data.state.farm == loop.state.farm and disk.data.state.resource_damage == loop.state.resource_damage)
	loop.enter("home")
	loop._restore_world(disk.data.world)
	await frames()
	check("expanded farm load restores player and camera", loop.location == "farm" and lane.player.position == far_point and lane.camera.limit_right == 1440 and lane.camera.limit_bottom == 960)
	check("cleared collisions stay removed after reload", loop.area.resource_nodes.all(func(node): return not node.available() and node.collision_layer == 0))
	lane.player.position = Vector2(208, 360)
	lane.facing = 0
	await key()
	check("harvest returns crop to shared inventory", loop.state.raw[2] == 1 and loop.state.farm.plots["0"].growth == -1)
	check("real walk back to town", await Navigation.walk(lane, loop.area.stations.exit))
	check("town connection restored", loop.location == "town" and lane.player.position == loop.FARM_GATE and lane.world.is_inside_tree())
	Saves.end_session()
	loop.set_process(false)
	loop.audio.set_process(false)
	if is_instance_valid(loop.audio.fade): loop.audio.fade.kill()
	for player in loop.audio.get_children():
		if player is AudioStreamPlayer: player.stop()
	lane.queue_free()
	await frames()
	print("FARM VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
