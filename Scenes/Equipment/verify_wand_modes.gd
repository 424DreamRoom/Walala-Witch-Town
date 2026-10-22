extends SceneTree
## Actual input, transactional failures, save compatibility and rendered colour variants.
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Visuals = preload("res://Scenes/Equipment/wand_visuals.gd")
const WitchAnimation = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")
const Source = preload("res://Art/Source/aseprite_source.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/wand_modes/"
var failures := 0
var capture := false
var lane
var loop

func _initialize() -> void:
	var profile := OUT + "profile_" + str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile + "/preferences.cfg"
	Saves.directory = profile + "/saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("WAND MODES TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func key(code: int, echo: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		event.echo = echo
		root.push_input(event, true)
		await frames()

func click(position: Vector2 = Vector2.INF, button: int = MOUSE_BUTTON_LEFT) -> void:
	if not position.is_finite(): position = root.get_visible_rect().size / 2.0
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func clear_farm(s) -> void:
	for id in State.FarmTerrain.obstacles.values():
		if id != "house": s.resource_damage[id] = State.RESOURCE_HITS

func state_checks() -> void:
	var s := State.new()
	check("fresh game selects red wand", s.wand_mode == "red" and s.is_item_selected("wand"))
	check("selected wand toggles blue", s.toggle_wand_mode() and s.wand_mode == "blue")
	for kind in ["wood", "ore", "weed"]:
		check("blue cannot destroy " + kind, s.strike_resource(kind, kind) == -1 and s.resource_damage.is_empty())
	check("selected wand toggles red", s.toggle_wand_mode() and s.wand_mode == "red")
	for kind in ["wood", "ore", "weed"]:
		check("red destroys " + kind, s.strike_resource(kind, kind) == (0 if kind == "weed" else 2))
	clear_farm(s)
	var soil := s.farm.duplicate(true)
	check("red cannot till", not s.work_farm_tile(0) and s.farm == soil)
	s.farm.water = 1
	check("red cannot refill", not s.refill_farm_water() and s.farm.water == 1)
	s.toggle_wand_mode()
	check("blue tills", s.work_farm_tile(0) and s.farm.plots["0"].growth == -1)
	check("blue wand plants from inventory", s.work_farm_tile(0) and s.farm.plots["0"].growth == 0 and s.farm.seeds == 11)
	check("blue waters", s.work_farm_tile(0) and s.farm.plots["0"].watered and s.farm.water == 0)
	check("repeated watering never drains water", not s.work_farm_tile(0) and s.farm.water == 0)
	check("blue refills to upgraded capacity", s.refill_farm_water() and s.farm.water == s.water_capacity())
	s.farm.plots["1"] = {"growth": -1, "watered": true}
	s.campaign.selected_crop = "turnip"
	var seeds: int = s.campaign.seeds.turnip
	s.toggle_wand_mode()
	check("red cannot plant campaign crops", not s.work_farm_tile(1) and s.campaign.seeds.turnip == seeds and s.farm.plots["1"].growth == -1)
	check("campaign API cannot bypass red mode", not State.Campaign.farm_action(s, 1) and s.campaign.seeds.turnip == seeds)
	s.toggle_wand_mode()
	check("blue plants campaign crops", s.work_farm_tile(1) and s.campaign.seeds.turnip == seeds - 1 and s.farm.plots["1"].watered)
	s.farm.plots["1"].watered = false
	s.toggle_wand_mode()
	var water: int = s.farm.water
	check("red cannot water campaign crops", not State.Campaign.farm_action(s, 1) and not s.farm.plots["1"].watered and s.farm.water == water)
	s.toggle_wand_mode()
	check("blue waters campaign crops", s.work_farm_tile(1) and s.farm.plots["1"].watered and s.farm.water == water - 1)
	s.farm.plots["1"].growth = State.Campaign.crop_days(s.farm.plots["1"])
	check("blue harvests campaign crops", s.work_farm_tile(1) and s.campaign.pantry.turnip > 0)
	for mode in ["blue", "red"]:
		s.wand_mode = mode
		check(mode + " keeps fishing", s.catch_fish("pond_" + mode))
	s.select_hotbar_slot(1)
	check("unselected wand cannot toggle", not s.toggle_wand_mode() and s.wand_mode == "red")
	s.farm.plots["2"] = {"growth": -1, "watered": false}
	s.campaign.selected_crop = "herb"
	s.bag_slots[1].count = 2
	s.bag_slots[2] = {"id": "seed", "count": 9}
	Items.sync(s)
	check("selected seed stack retains planting", s.work_farm_tile(2) and s.bag_slots[1].count == 1 and s.bag_slots[2].count == 9)
	s.select_hotbar_slot(0)
	s.phase = "night"
	check("night still blocks destruction", s.strike_resource("night_tree", "wood") == -1 and not s.resource_damage.has("night_tree"))
	s.phase = "result"
	check("settlement cannot toggle", not s.toggle_wand_mode() and s.wand_mode == "red")
	s.phase = "day"
	var saved := s.to_save_data()
	var restored := State.new()
	check("colour survives JSON roundtrip", restored.restore_save_data(JSON.parse_string(JSON.stringify(saved))) and restored.wand_mode == "red" and restored.equipment == s.equipment and restored.farm == s.farm)
	var old := saved.duplicate(true)
	old.erase("wand_mode")
	check("existing saves default red", restored.restore_save_data(old) and restored.wand_mode == "red")
	var blue_save := saved.duplicate(true)
	blue_save.wand_mode = "blue"
	check("saved blue overrides red default", restored.restore_save_data(blue_save) and restored.wand_mode == "blue")
	for bad in ["purple", "", 0, null, [], {}]:
		var broken := saved.duplicate(true)
		broken.wand_mode = bad
		check("invalid mode rejects atomically " + str(bad), not restored.restore_save_data(broken) and restored.wand_mode == "blue")
	s.menu[0] = true
	s.end_phase()
	s.end_phase()
	s.next_day()
	check("colour survives next day", s.wand_mode == "red")
	s.tools.wand = 0
	check("stored wand cannot toggle", not s.toggle_wand_mode() and s.wand_mode == "red")
	for rank in range(4):
		var upgraded := State.new()
		upgraded.wand_mode = "blue"
		upgraded.equipment.wand = rank
		clear_farm(upgraded)
		check("blue upgrade tills correct area " + str(rank), upgraded.work_farm_tile(41) and upgraded.farm.plots.size() == [1, 3, 9, 15][rank])
		check("blue upgrade still blocks chopping " + str(rank), upgraded.strike_resource("upgraded_tree", "wood") == -1)
		upgraded.toggle_wand_mode()
		var hits := 0
		while upgraded.resource_left("upgraded_tree") > 0 and hits < 4:
			upgraded.strike_resource("upgraded_tree", "wood")
			hits += 1
		check("red upgrade retains speed and yield " + str(rank), hits == [3, 2, 1, 1][rank] and upgraded.resources.wood == 3 + rank)

func visual_checks() -> void:
	for type in ["icon", "action"]:
		var base := Source.texture("res://Art/UI/NativeIcons/wand.aseprite" if type == "icon" else WitchAnimation.SHEET).get_image()
		var variants: Array[Image] = []
		for mode in ["blue", "red"]:
			var texture := Visuals.icon_texture(mode) if type == "icon" else Visuals.action_texture(mode)
			var pixels := texture.get_image()
			variants.append(pixels)
			var alpha_matches := pixels.get_size() == base.get_size()
			for y in range(base.get_height()):
				for x in range(base.get_width()):
					alpha_matches = alpha_matches and base.get_pixel(x, y).a == pixels.get_pixel(x, y).a
			check(type + " preserves canvas and transparency " + mode, alpha_matches)
			if type == "action":
				for facing in range(4):
					for animation in ["idle", "walk", "run"]:
						var tag := WitchAnimation.tag_for(animation, facing)
						var unchanged := true
						for frame in range(int(tag.from), int(tag.to) + 1):
							var rect := Rect2i(Vector2i(frame % 8, frame / 8) * 32, Vector2i(32, 32))
							unchanged = unchanged and pixels.get_region(rect).get_data() == base.get_region(rect).get_data()
						check("body animation unchanged " + mode + animation + str(facing), unchanged)
				for facing in range(4):
					var tag := WitchAnimation.tag_for("cast", facing)
					var frame := int(tag.from) + 4
					var rect := Rect2i(Vector2i(frame % 8, frame / 8) * 32, Vector2i(32, 32))
					check("cast has coloured magic " + mode + str(facing), pixels.get_region(rect).get_data() != base.get_region(rect).get_data())
		check(type + " colours visibly differ", variants[0].get_data() != variants[1].get_data())
		if capture:
			for index in range(2):
				variants[index].save_png(OUT + type + ("_blue.png" if index == 0 else "_red.png"))

func shot(title: String) -> void:
	if not capture: return
	await frames()
	await RenderingServer.frame_post_draw
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)

func run() -> void:
	state_checks()
	visual_checks()
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	check("fresh scene and hotbar default red", loop.state.wand_mode == "red" and loop.hud.slot_counts[0].get_parent().get_node("Icon").wand_mode == "red")
	loop.state.remaining = State.DAY_SECONDS * 0.5
	lane.weather.clear_weather()
	loop.enter("field")
	await frames()
	var tree = loop.area.resource_nodes.filter(func(node): return node.resource_kind == "wood")[0]
	lane.player.position = tree.anchor
	await key(KEY_E)
	check("first E switches to blue without striking", loop.state.wand_mode == "blue" and not loop.harvest.busy() and loop.state.resource_left(tree.resource_id) == 3)
	await key(KEY_E)
	check("E toggles red without striking", loop.state.wand_mode == "red" and not loop.harvest.busy() and loop.state.resource_left(tree.resource_id) == 3)
	check("hotbar reflects red", loop.hud.slot_counts[0].get_parent().get_node("Icon").wand_mode == "red")
	await key(KEY_E, true)
	check("held key echo does not toggle", loop.state.wand_mode == "red")
	await click(Vector2.INF, MOUSE_BUTTON_RIGHT)
	check("right mouse does not cast", not loop.harvest.busy())
	await click()
	check("left mouse starts red chop", loop.harvest.action == "chop")
	await key(KEY_E)
	await create_timer(0.8).timeout
	check("switch cancels before damage", loop.state.wand_mode == "blue" and not loop.harvest.busy() and loop.state.resource_left(tree.resource_id) == 3 and loop.state.resources.wood == 0)
	await click()
	check("blue blocks animation and reward", not loop.harvest.busy() and loop.state.resource_left(tree.resource_id) == 3)
	await key(KEY_E)
	await click()
	loop.harvest.paused_for_test = true
	loop.harvest.elapsed = 0.30
	loop.harvest.update_pose()
	check("red cast uses red variant", loop.harvest.actor.texture == Visuals.action_texture("red"))
	await shot("red_chop")
	loop.harvest.paused_for_test = false
	await create_timer(0.7).timeout
	check("one mouse press applies one strike", loop.state.resource_left(tree.resource_id) == 2)
	# Clicking a HUD cell opens its UI instead of sending a second world action.
	var cell: Control = loop.hud.slot_counts[0].get_parent()
	var container: SubViewportContainer = lane.viewport.get_parent()
	await click(container.position + cell.get_global_rect().get_center() * container.scale)
	check("HUD click cannot cast through UI", loop.hud.mode == "bag" and paused and not loop.harvest.busy())
	await key(KEY_E)
	check("modal E cannot switch colour", loop.state.wand_mode == "red")
	check("backpack icon reflects red", loop.hud.chest_view.bag_slots[0].get_node("Icon").wand_mode == "red")
	loop.hud.close_modal()
	loop.enter("farm")
	clear_farm(loop.state)
	for node in loop.area.resource_nodes: node.refresh()
	loop.area.refresh_resources()
	lane.player.position = loop.area.tile_center(0) + Vector2(0, 30)
	lane.facing = 1
	await click()
	check("red mouse cannot till", loop.state.farm.plots.is_empty())
	await create_timer(0.3).timeout
	await key(KEY_E)
	await click()
	check("blue mouse tills", loop.state.farm.plots.has("0"))
	if loop.state.farm.plots.has("0"):
		loop.harvest.paused_for_test = true
		loop.harvest.farm_cast_left = 0.17
		loop.harvest.update_pose()
		check("blue farm cast uses blue variant", loop.harvest.actor.texture == Visuals.action_texture("blue"))
		await shot("blue_till")
		loop.harvest.paused_for_test = false
		await create_timer(0.4).timeout
		await click()
		check("blue mouse plants without changing slots", loop.state.farm.plots["0"].growth == 0 and loop.state.farm.seeds == 11 and loop.state.selected_hotbar_slot == 0)
		await create_timer(0.4).timeout
		await click()
		check("blue mouse waters", loop.state.farm.plots["0"].watered and loop.state.farm.water == 23)
	# Both colour modes share the old fishing behaviour and cancel on a switch.
	loop.enter("dock")
	var fish = loop.area.resource_nodes[0]
	lane.player.position = fish.anchor
	await click()
	check("left mouse casts fishing", loop.harvest.action == "cast")
	loop.harvest.set_action("bite")
	await click()
	await create_timer(0.7).timeout
	check("left mouse reels and awards fish", loop.state.resources.fish == 1)
	await click()
	await key(KEY_E)
	check("colour switch cancels fishing", not loop.harvest.busy() and loop.state.wand_mode == "red" and loop.state.resources.fish == 1)
	loop.enter("home")
	await frames()
	check("colour survives travel", loop.state.wand_mode == "red")
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		loop.hud.refresh()
		check("localized colour name " + locale, loop.hud.slot_counts[0].get_parent().tooltip_text == TranslationServer.translate(Visuals.NAMES.red))
		await shot("red_hud_" + locale)
	check("isolated save slot created", Saves.begin_slot(1).ok)
	Saves.consume_pending()
	check("manual save records colour", loop.save_progress().ok and Saves.read_slot(1).data.state.wand_mode == "red")
	loop.enter("blacksmith")
	lane.player.position = loop.area.stations.service
	loop.state.coins = 100
	Items.change(loop.state, {"wood": 2, "iron": 1})
	var water_before: int = loop.state.farm.water
	loop.hud.open_equipment_upgrades(loop.area)
	check("upgrade panel opens for selected red wand", loop.hud.mode == "upgrades")
	if loop.hud.mode == "upgrades":
		var panel = loop.hud.modal.get_node("EquipmentUpgrades")
		check("upgrade icon reflects red", panel.entries.wand.get_node("Icon").wand_mode == "red")
		var upgrade: Control = panel.detail.get_node("Upgrade")
		await click(container.position + upgrade.get_global_rect().get_center() * container.scale)
		check("real upgrade preserves colour and stored water", loop.state.equipment.wand == 1 and loop.state.wand_mode == "red" and loop.state.farm.water == water_before)
		loop.hud.close_modal()
	loop.enter("home")
	# The interaction key remains F while the fixed wand toggle remains E.
	var bindings := root.get_node("InputBindings")
	check("interaction key remains F", bindings.bindings.interact[0] == KEY_F)
	await key(KEY_F)
	check("interaction key does not switch colour", loop.state.wand_mode == "red")
	await key(KEY_E)
	check("E switches colour", loop.state.wand_mode == "blue")
	loop.state.select_hotbar_slot(9)
	lane.player.position = loop.area.stations.exit
	await key(KEY_F)
	await create_timer(0.6).timeout
	check("unselected wand keeps keyboard door interaction", loop.location == "farm" and loop.state.wand_mode == "blue")
	loop.state.select_hotbar_slot(0)
	lane.player.position = loop.HOME_EXIT_POSITION
	await click()
	await create_timer(0.6).timeout
	check("selected wand keeps mouse door interaction", loop.location == "home" and loop.state.wand_mode == "blue")
	# Instantiate a fresh gameplay scene from the actual saved disk snapshot.
	lane.queue_free()
	await frames(5)
	check("disk slot reopens", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	check("fresh scene restores saved red wand", loop.state.wand_mode == "red" and loop.location == "home" and loop.hud.slot_counts[0].get_parent().get_node("Icon").wand_mode == "red")
	Saves.end_session()
	lane.queue_free()
	await frames(5)
	print("WAND MODES VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
