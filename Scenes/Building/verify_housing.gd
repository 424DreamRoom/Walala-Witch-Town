extends SceneTree
## Real input, geometry, transactions and disk round trips use isolated profiles.
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Furniture = preload("res://Scenes/Building/furniture_catalog.gd")
const House = preload("res://Scenes/Building/house_catalog.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
const OUT := "res://output/housing_progression/"
var lane
var loop
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--housing-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("HOUSING TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame
	if root.get_node("SceneTransition").active: await root.get_node("SceneTransition").finished

func key(code: Key) -> void:
	if code == KEY_E:
		await preload("res://Scenes/Gameplay/verification_world_action.gd").press(self)
		await frames()
		return
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func click_at(point: Vector2) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var position: Vector2 = container.position + point * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func click(control: Control) -> void:
	await click_at(control.get_global_rect().get_center())

func shot(title: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + title, pixels.save_png(OUT + title + ".png") == OK)

func domain_checks() -> void:
	var state := State.new()
	check("starter house is empty including fixtures and stock", state.furniture.house_level == 0 and state.furniture.placed.is_empty() and Furniture.fixed_solids(state.furniture).is_empty() and state.furniture.stock.values().all(func(value): return value == 0))
	var original := state.to_save_data()
	check("insufficient funds cannot expand", not state.expand_house() and state.coins == original.coins and state.resources == original.resources and state.furniture == original.furniture)
	state.coins = 1000
	state.resources.wood = 200
	state.resources.iron = 20
	check("starter still supports crafting", state.craft_furniture("stool", "farm", Vector2(416, 312)) and state.craft_furniture("chest", "farm", Vector2(416, 312)))
	check("larger floor is locked before purchase", not state.place_furniture("stool", Vector2(480, 352), Vector2(320, 405)) and state.furniture.stock.stool == 1)
	check("starter supports real furniture", state.place_furniture("stool", Vector2(384, 352), Vector2(320, 405)) and state.place_furniture("chest", Vector2(256, 384), Vector2(320, 405)))
	var chest_id: int = state.furniture.next_id - 1
	check("chest accepts real inventory", state.transfer_chest(chest_id, "wood", 5, true) == 5)
	var placed: Array = state.furniture.placed.duplicate(true)
	# The second exterior foundation now includes this authored farm rock.
	state.resource_damage["farm_ore_271"] = state.RESOURCE_HITS
	for rank in range(House.MAX_LEVEL):
		var coins: int = state.coins
		var wood: int = state.resources.wood
		var iron: int = state.resources.iron
		var cost: Dictionary = House.COSTS[rank]
		check("expansion charges exact cost " + str(rank), state.expand_house() and state.furniture.house_level == rank + 1 and state.coins == coins - cost.coins and state.resources.wood == wood - cost.wood and state.resources.iron == iron - cost.iron)
		check("expansion preserves IDs positions and contents " + str(rank), state.furniture.placed == placed and not State.normalize_save_data(state.to_save_data()).is_empty())
	check("maximum cannot charge again", not state.expand_house() and state.furniture.placed == placed)
	for bad_level in [-1, 3, 0.5, "1"]:
		var invalid := state.to_save_data()
		invalid.furniture.house_level = bad_level
		check("reject invalid house level " + str(bad_level), State.normalize_save_data(invalid).is_empty())
	var invalid := state.to_save_data()
	invalid.furniture.house_level = 0
	invalid.furniture.placed[0].x = 480
	check("save validates level-specific furniture bounds", State.normalize_save_data(invalid).is_empty())
	var legacy := original.duplicate(true)
	legacy.erase("furniture")
	check("pre-furniture saves retain authored house", State.normalize_save_data(legacy).furniture == Furniture.legacy_data())
	legacy.furniture = Furniture.legacy_data()
	legacy.furniture.erase("house_level")
	legacy.furniture.erase("legacy_fixtures")
	check("pre-expansion saves retain every furnishing", State.normalize_save_data(legacy).furniture == Furniture.legacy_data())
	var poor := State.new()
	poor.coins = 120
	poor.resources.wood = 29
	poor.resources.iron = 3
	check("one missing material prevents all charges", not poor.expand_house() and poor.coins == 120 and poor.resources.wood == 29 and poor.resources.iron == 3)
	poor.resources.wood = 30
	poor.phase = "night"
	check("night expansion cannot mutate", not poor.expand_house() and poor.furniture.house_level == 0 and poor.coins == 120)
	var obstacles: Array[Rect2] = [Rect2(224, 356, 192, 12)]
	check("small room still protects escape route", not Furniture._exit_reachable(obstacles, Vector2(256, 330), House.FLOORS[0]))

func load_lane() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(6)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true

func run() -> void:
	Preferences.file_path = "user://housing_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://housing_saves_%d" % OS.get_process_id()
	root.get_node("Localization").set_language("zh_CN", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	domain_checks()
	Saves.end_session()
	await load_lane()
	check("fresh slot opens", Saves.begin_slot(1).ok)
	Saves.consume_pending()
	State.Campaign.pending_intro = false
	loop.state.campaign.introduced = true
	loop.state.campaign.guide_met = true
	loop.enter("home")
	await frames()
	check("starter has only its eight wall bodies", loop.area.solids.size() == 8 and loop.area.furniture_bodies.is_empty() and lane.camera.limit_bottom == 532)
	check("starter floor is one sixth of former floor", House.floor_for(loop.state.furniture).get_area() == 192 * 128)
	await shot("starter_empty")
	var end: Vector2 = await lane._walk(Vector2(320, 352), Vector2.LEFT, 200)
	check("starter side wall physically blocks movement", end.x >= 224 and end.x < 233)
	# Prepare furnishings at the real farm workbench before arranging the empty home.
	loop.enter("farm")
	lane.player.position = Vector2(416, 312)
	loop.state.resources.wood = 10
	await key(KEY_E)
	await click(loop.builder.detail.get_node("Craft"))
	await click(loop.builder.root.get_node("FurnitureCatalog/Recipe_chest"))
	await click(loop.builder.detail.get_node("Craft"))
	loop.builder.close()
	loop.builder.selected_kind = "stool"
	loop.enter("home")
	lane.player.position = loop.area.spawn
	await key(KEY_ESCAPE)
	check("home pause menu omits construction", loop.save_menu.open and not loop.save_menu.panel.has_node("BuildFurniture"))
	await key(KEY_ESCAPE)
	loop.builder.open_catalog()
	check("construction safely takes pause ownership", loop.builder.active() and paused and not loop.save_menu.open)
	loop.builder._refresh_catalog()
	await click(loop.builder.detail.get_node("Craft"))
	await click(loop.builder.detail.get_node("Place"))
	await click_at(lane.viewport.get_canvas_transform() * Vector2(384, 352))
	check("real input crafts and places first furnishing", loop.builder.mode == "edit" and loop.state.furniture.placed.size() == 1 and loop.state.resources.wood == 0 and loop.area.furniture_bodies.size() == 1)
	await click(loop.builder.root.find_child("Catalog", true, false))
	await click(loop.builder.root.get_node("FurnitureCatalog/Recipe_chest"))
	await click(loop.builder.detail.get_node("Craft"))
	await click(loop.builder.detail.get_node("Place"))
	await click_at(lane.viewport.get_canvas_transform() * Vector2(256, 384))
	check("real input builds chest in starter", loop.state.furniture.placed.size() == 2 and loop.area.furniture_bodies.size() == 2)
	var chest_id: int = loop.state.furniture.next_id - 1
	loop.state.resources.wood = 5
	check("starter chest stores materials", loop.state.transfer_chest(chest_id, "wood", 5, true) == 5)
	await key(KEY_ESCAPE)
	await shot("starter_furnished")
	var placed: Array = loop.state.furniture.placed.duplicate(true)
	loop.hud.open_map()
	loop.hud.map_view.show_region("home", false)
	check("map mirrors empty shell and crafted furniture", loop.hud.map_view.canvas.region_items("home").size() == 2 and loop.hud.map_view.canvas.region_size("home") == Vector2(640, 532))
	loop.hud.close_modal()
	check("starter doorway remains reachable", await Navigation.walk(lane, loop.area.stations.exit))
	await key(KEY_E)
	check("starter exits to farm", loop.location == "farm")
	loop.enter("town")
	lane.player.position = loop.FURNITURE_GATE + Vector2(0, 20)
	await key(KEY_E)
	check("town door enters actual furniture store", loop.location == "furniture_store" and not lane.weather.visible)
	check("shop service is reachable", await Navigation.walk(lane, loop.area.stations.service))
	loop.state.coins = 120
	loop.state.resources.wood = 30
	loop.state.resources.iron = 3
	await shot("furniture_store")
	await key(KEY_E)
	check("shop interaction opens paused expansion panel", loop.hud.mode == "housing" and paused and loop.hud.modal.has_node("HouseUpgrades"))
	var view = loop.hud.modal.get_node("HouseUpgrades")
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		await shot("expansion_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	await click(view.detail.get_node("Expand"))
	check("first purchase charges only listed resources", loop.state.furniture.house_level == 1 and loop.state.coins == 0 and loop.state.resources.wood == 0 and loop.state.resources.iron == 0)
	check("second tier is unavailable without its price", view.detail.get_node("Expand").disabled)
	loop.hud.close_modal()
	view.purchase()
	check("closed service cannot charge stale click", loop.state.furniture.house_level == 1 and loop.state.coins == 0)
	loop.enter("home")
	await shot("expanded_once")
	check("first expansion changes geometry and keeps furniture", House.floor_for(loop.state.furniture) == House.FLOORS[1] and loop.area.solids[0] == House.walls(loop.state.furniture)[0] and loop.state.furniture.placed == placed)
	loop.hud.open_house_upgrades(loop.area)
	check("upgrades are unavailable remotely from home", loop.hud.mode.is_empty())
	loop.enter("furniture_store")
	lane.player.position = loop.area.stations.service
	loop.state.coins = 400
	loop.state.resource_damage["farm_ore_271"] = loop.state.RESOURCE_HITS
	loop.state.resources.wood = 80
	loop.state.resources.iron = 8
	await key(KEY_E)
	view = loop.hud.modal.get_node("HouseUpgrades")
	await click(view.detail.get_node("Expand"))
	check("second purchase unlocks full room without furnishings", loop.state.furniture.house_level == 2 and loop.state.coins == 0 and loop.state.furniture.placed == placed and not loop.state.furniture.legacy_fixtures)
	check("maximum disables purchase", view.detail.get_node("Expand").disabled)
	check("new shop location persists to disk", loop.save_progress().ok and Saves.read_slot(1).data.world.location == "furniture_store")
	loop.hud.close_modal()
	loop.enter("home")
	await shot("expanded_twice")
	check("expanded room keeps crafted collisions and contents", Furniture.footprint("chest", Vector2(256, 384)) in lane.solid_rects and loop.state.furniture_by_id(chest_id).items.wood == 5 and loop.area.world_size == Vector2i(640, 480))
	check("expanded home saves", loop.save_progress().ok)
	lane.queue_free()
	await frames(6)
	check("saved slot reopens", Saves.begin_slot(1).ok)
	await load_lane()
	check("disk reload restores house size furniture and chest", loop.location == "home" and loop.state.furniture.house_level == 2 and loop.state.furniture.placed == placed and loop.state.furniture_by_id(chest_id).items.wood == 5)
	Saves.end_session()
	lane.queue_free()
	await frames(6)
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("HOUSING VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
