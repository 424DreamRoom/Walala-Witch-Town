extends SceneTree
## Selection and item-use transactions use process-specific settings and saves.
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/hotbar_selection/"
var failures := 0
var capture := false
var lane
var loop
var hud

func _initialize() -> void:
	Preferences.file_path = "user://hotbar_selection_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://hotbar_selection_%d" % OS.get_process_id()
	Saves.end_session()
	capture = "--hotbar-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("HOTBAR TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func key(code: int, modifier: bool = false, echo: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		event.ctrl_pressed = modifier
		event.echo = echo
		root.push_input(event, true)
		await frames()

func wheel(button: int, pressed: bool = true, modifier: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.ctrl_pressed = modifier
	event.position = root.get_visible_rect().size / 2.0
	event.global_position = event.position
	root.push_input(event, true)
	await frames()

func cast() -> void:
	await wheel(MOUSE_BUTTON_LEFT)
	await wheel(MOUSE_BUTTON_LEFT, false)

func shot(title: String) -> void:
	if not capture: return
	await frames()
	await RenderingServer.frame_post_draw
	var pixels: Image = lane.viewport.get_texture().get_image()
	var bar: Image = pixels.get_region(Rect2i(hud.hotbar_art.get_rect()))
	bar.resize(1072, 128, Image.INTERPOLATE_NEAREST)
	check("capture " + title, bar.save_png(OUT + title + ".png") == OK)
	pixels.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	pixels.save_png(OUT + title + "_hud.png")

func state_checks() -> void:
	var s := State.new()
	check("new game selects the red wand", s.selected_hotbar_slot == 0 and s.is_item_selected("wand") and s.wand_mode == "red")
	s.select_hotbar_slot(1)
	check("owned wand stays owned when seeds are selected", s.is_item_selected("seed") and s.has_tool("wand"))
	for kind in ["wood", "ore", "weed"]:
		check("unselected wand cannot strike " + kind, s.strike_resource(kind, kind) == -1 and s.resource_damage.is_empty())
	check("unselected wand cannot catch fish", not s.catch_fish("pond") and s.fish_catches.is_empty() and s.resources.fish == 0)
	check("unselected wand cannot till", not s.work_farm_tile(0) and s.farm.plots.is_empty())
	s.farm.water = 1
	check("unselected wand cannot refill", not s.refill_farm_water() and s.farm.water == 1)
	for id in State.FarmTerrain.obstacles.values():
		if id != "house": s.resource_damage[id] = State.RESOURCE_HITS
	s.select_hotbar_slot(0)
	s.wand_mode = "blue"
	check("selected wand tills", s.work_farm_tile(0) and s.farm.plots["0"].growth == -1)
	var plot: Dictionary = s.farm.plots.get("0", {}).duplicate(true)
	s.select_hotbar_slot(9)
	check("unselected seeds cannot plant or change soil", not s.work_farm_tile(0) and s.farm.plots["0"] == plot and s.farm.seeds == 12)
	s.bag_slots[1].count = 3
	s.bag_slots[2] = {"id": "seed", "count": 9}
	Items.sync(s)
	s.select_hotbar_slot(1)
	check("plant consumes the selected seed stack", s.work_farm_tile(0) and s.bag_slots[1].count == 2 and s.bag_slots[2].count == 9 and s.farm.seeds == 11)
	check("seeds cannot water", not s.work_farm_tile(0) and not s.farm.plots["0"].watered and s.farm.water == 1)
	s.select_hotbar_slot(0)
	check("selected wand waters", s.work_farm_tile(0) and s.farm.plots["0"].watered and s.farm.water == 0)
	check("selected wand refills", s.refill_farm_water() and s.farm.water == s.water_capacity())
	s.select_hotbar_slot(1)
	check("excessive selected-stack consumption is atomic", not s.consume_selected_item("seed", 3) and s.bag_slots[1].count == 2 and s.bag_slots[2].count == 9)
	check("using last seed clears only its selected slot", s.consume_selected_item("seed", 2) and s.bag_slots[1].is_empty() and s.bag_slots[2].count == 9 and s.selected_item_id().is_empty())
	check("empty selected slot cannot borrow another seed stack", not s.consume_selected_item("seed") and s.bag_slots[2].count == 9)
	s.bag_slots[7] = s.bag_slots[0]
	s.bag_slots[0] = {}
	Items.sync(s)
	s.select_hotbar_slot(0)
	check("selection follows the slot after inventory rearrangement", not s.is_item_selected("wand") and s.strike_resource("tree", "wood") == -1)
	s.select_hotbar_slot(7)
	s.wand_mode = "red"
	check("wand in another selected slot works", s.is_item_selected("wand") and s.strike_resource("tree", "wood") == 2)
	check("invalid selections retain current slot", not s.select_hotbar_slot(-1) and not s.select_hotbar_slot(10) and s.selected_hotbar_slot == 7)
	var saved := s.to_save_data()
	var restored := State.new()
	check("JSON roundtrip restores selected slot", restored.restore_save_data(JSON.parse_string(JSON.stringify(saved))) and restored.selected_hotbar_slot == 7 and restored.is_item_selected("wand"))
	var old := saved.duplicate(true)
	old.erase("selected_hotbar_slot")
	check("older saves default to the first slot", restored.restore_save_data(old) and restored.selected_hotbar_slot == 0)
	for value in [-1, 10, 1.5, "1", null]:
		var broken := saved.duplicate(true)
		broken.selected_hotbar_slot = value
		check("invalid saved selection rejected " + str(value), State.normalize_save_data(broken).is_empty())

func run() -> void:
	state_checks()
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	hud = loop.hud
	var weather: String = lane.weather.get_weather()
	for index in range(hud.HOTBAR_KEYS.size()):
		await key(hud.HOTBAR_KEYS[index])
		check("number selects slot " + str(index), loop.state.selected_hotbar_slot == index and hud.hotbar_selection.position == hud.slot_counts[index].get_parent().position and hud.hotbar_selection.visible and hud.mode.is_empty() and not paused)
	check("selection preserves weather", lane.weather.get_weather() == weather)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check("wheel down wraps last slot to wand", loop.state.selected_hotbar_slot == 0 and loop.state.is_item_selected("wand") and hud.mode.is_empty())
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check("wheel down selects next item and moves highlight", loop.state.is_item_selected("seed") and hud.hotbar_selection.position == hud.slot_counts[1].get_parent().position)
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check("wheel up selects previous item", loop.state.is_item_selected("wand"))
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check("wheel up wraps first slot to empty last slot", loop.state.selected_hotbar_slot == 9 and loop.state.selected_item_id().is_empty())
	await wheel(MOUSE_BUTTON_WHEEL_UP, false)
	await wheel(MOUSE_BUTTON_WHEEL_LEFT)
	await wheel(MOUSE_BUTTON_WHEEL_UP, true, true)
	check("wheel releases horizontal scroll and modifiers do not select", loop.state.selected_hotbar_slot == 9)
	await key(KEY_2)
	check("second slot selects seeds without opening bag", loop.state.is_item_selected("seed") and hud.mode.is_empty())
	await key(KEY_4, true)
	await key(KEY_4, false, true)
	check("modifiers and key repeats do not select", loop.state.selected_hotbar_slot == 1)
	hud.open_bag()
	await key(KEY_3)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check("backpack blocks keyboard and wheel hotbar input", hud.mode == "bag" and paused and loop.state.selected_hotbar_slot == 1)
	hud.close_modal()
	hud.start_dialogue("Test", "res://Art/Character/Storybook/WalalaWitch/walala-witch.aseprite", ["Selection test"])
	await key(KEY_3)
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check("dialogue blocks keyboard and wheel hotbar input", hud.mode == "dialogue" and loop.state.selected_hotbar_slot == 1)
	hud.close_modal()
	hud.open_map()
	await key(KEY_4)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check("map blocks keyboard and wheel hotbar input", hud.mode == "map" and loop.state.selected_hotbar_slot == 1)
	hud.close_modal()
	loop.save_menu.show_menu()
	await key(KEY_5)
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check("pause menu blocks keyboard and wheel hotbar input", paused and loop.state.selected_hotbar_slot == 1)
	loop.save_menu.close_menu()
	paused = true
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check("paused world blocks wheel selection without a modal", loop.state.selected_hotbar_slot == 1)
	paused = false
	var bindings := root.get_node("InputBindings")
	bindings.begin_capture(hud, "interact", 0)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check("key capture blocks wheel selection", bindings.capture_active and loop.state.selected_hotbar_slot == 1)
	await key(KEY_9)
	check("key capture blocks selection", not bindings.capture_active and bindings.bindings.interact[0] == KEY_9 and loop.state.selected_hotbar_slot == 1)
	bindings.reset_defaults()
	check("custom digit binding applies", bindings.assign_key("map", 0, KEY_7).ok)
	await key(KEY_7)
	check("configured action takes priority over hotbar", hud.mode == "map" and loop.state.selected_hotbar_slot == 1)
	hud.close_modal()
	bindings.reset_defaults()
	loop.state.phase = "result"
	hud.refresh()
	await key(KEY_0)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check("settlement blocks keyboard and wheel selection and hides highlight", loop.state.selected_hotbar_slot == 1 and not hud.hotbar_selection.visible)
	loop.state.phase = "day"
	Preferences.set_value("game", "show_hotbar", false)
	hud.refresh()
	await key(KEY_5)
	check("hidden hotbar keeps keyboard selection without visible highlight", loop.state.selected_hotbar_slot == 4 and not hud.hotbar_selection.visible)
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check("hidden hotbar keeps wheel selection without visible highlight", loop.state.selected_hotbar_slot == 3 and not hud.hotbar_selection.visible)
	Preferences.set_value("game", "show_hotbar", true)
	hud.refresh()
	loop.enter("field")
	loop.state.wand_mode = "red"
	var node = loop.area.resource_nodes.filter(func(item): return item.resource_kind == "wood")[0]
	lane.player.position = node.anchor
	await key(KEY_2)
	await key(KEY_F)
	check("real interact cannot use an unselected wand", not loop.harvest.busy() and loop.state.resource_left(node.resource_id) == 3)
	await key(KEY_1)
	await cast()
	check("real interact starts selected wand", loop.harvest.busy())
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check("wheel selection cancels tool action before impact", loop.state.is_item_selected("seed") and not loop.harvest.busy() and loop.state.resource_left(node.resource_id) == 3)
	await key(KEY_1)
	loop.harvest.start(node)
	loop.state.select_hotbar_slot(1)
	loop.harvest.advance(2.0)
	check("state changes also invalidate an active tool action", not loop.harvest.busy() and loop.state.resource_left(node.resource_id) == 3)
	loop.enter("dock")
	var fish = loop.area.resource_nodes.filter(func(item): return item.resource_kind == "fish")[0]
	lane.player.position = fish.anchor
	loop.harvest.start(fish)
	check("unselected wand cannot start fishing", not loop.harvest.busy())
	await key(KEY_1)
	loop.harvest.start(fish)
	check("selected wand starts fishing", loop.harvest.action == "cast")
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check("wheel to empty slot cancels fishing without a reward", loop.state.selected_hotbar_slot == 9 and not loop.harvest.busy() and loop.state.fish_catches.is_empty() and loop.state.resources.fish == 0)
	loop.enter("farm")
	loop.state.wand_mode = "blue"
	for resource in loop.area.resource_nodes:
		loop.state.resource_damage[resource.resource_id] = State.RESOURCE_HITS
		resource.refresh()
	loop.area.refresh_resources()
	lane.player.position = loop.area.tile_center(0) + Vector2(0, 30)
	lane.facing = 1
	await key(KEY_1)
	await cast()
	check("real selected wand tills farm", loop.state.farm.plots.has("0") and loop.state.farm.plots["0"].growth == -1)
	await create_timer(0.3).timeout
	await key(KEY_2)
	await key(KEY_F)
	check("real selected seeds plant once", loop.state.farm.plots["0"].growth == 0 and loop.state.farm.seeds == 11)
	check("seed planting does not display an unselected wand", loop.harvest.farm_cast_left == 0.0)
	await create_timer(0.3).timeout
	await key(KEY_1)
	await cast()
	check("real selected wand waters crop", loop.state.farm.plots["0"].watered and loop.state.farm.water == 23)
	loop.enter("home")
	await key(KEY_2)
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		check("selected highlight survives language " + locale, loop.state.selected_hotbar_slot == 1 and hud.hotbar_selection.position == hud.slot_counts[1].get_parent().position)
		await shot(locale + "_selected_seed")
	check("isolated save slot opens", Saves.begin_slot(1).ok)
	Saves.consume_pending()
	check("manual save persists selection", loop.save_progress().ok and Saves.read_slot(1).data.state.selected_hotbar_slot == 1)
	Saves.end_session()
	lane.queue_free()
	await frames(5)
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("HOTBAR VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
