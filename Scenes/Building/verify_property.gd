extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const House = preload("res://Scenes/Building/house_catalog.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
const OUT := "res://output/property_service/"
var failures := 0
var checks := 0
var lane
var loop
var capture := false

func _initialize() -> void:
	Preferences.file_path = "user://property_preferences.cfg"
	Saves.directory = "user://property_saves"
	Saves.end_session()
	State.Campaign.pending_intro = false
	capture = "--property-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PROPERTY TEST ", title, ": ", "PASS" if passed else "FAIL")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame
	if root.get_node("SceneTransition").active: await root.get_node("SceneTransition").finished

func key() -> void:
	await preload("res://Scenes/Gameplay/verification_world_action.gd").press(self)
	await frames()

func click(button: Button) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var point: Vector2 = container.position + button.get_global_rect().get_center() * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func shot(title: String) -> void:
	if not capture: return
	loop.last_message = loop.state.message
	loop.message_left = 0.0
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)

func clear_foundation(state) -> void:
	for item in State.FarmTerrain.layout.props:
		if Rect2(142, 122, 256, 128).intersects(Rect2(item.x - item.w / 2.0, item.y - item.h, item.w, item.h)):
			state.resource_damage[item.resource_id] = State.RESOURCE_HITS

func domain_checks() -> void:
	var state := State.new()
	state.menu[0] = true
	check("new restaurant requires a lease before service", not state.restaurant_leased and not state.start_service() and state.phase == "day")
	state.coins = state.RESTAURANT_RENT - 1
	check("insufficient rent is atomic", not state.rent_restaurant() and state.coins == 59 and not state.restaurant_leased)
	state.coins = 100
	state.phase = "night"
	check("closed office cannot charge rent", not state.rent_restaurant() and state.coins == 100)
	state.phase = "day"
	check("lease charges exactly once", state.rent_restaurant() and state.restaurant_leased and state.coins == 40 and not state.rent_restaurant() and state.coins == 40)
	check("leased restaurant operates normally", state.start_service() and state.phase == "night")
	var restored := State.new()
	check("lease persists through save restoration", restored.restore_save_data(state.to_save_data()) and restored.restaurant_leased)
	var legacy := state.to_save_data()
	legacy.erase("restaurant_leased")
	check("existing restaurant saves retain access", State.normalize_save_data(legacy).restaurant_leased)
	for invalid in [1, "true", null]:
		var bad := state.to_save_data()
		bad.restaurant_leased = invalid
		check("invalid lease is rejected " + str(invalid), State.normalize_save_data(bad).is_empty())
	state = State.new()
	state.coins = 1000
	state.resources.wood = 200
	state.resources.iron = 20
	clear_foundation(state)
	state.furniture.stock.chest = 1
	check("furnish starter home", state.place_furniture("chest", Vector2(256, 384), Vector2(320, 405)))
	var chest_id: int = state.furniture.next_id - 1
	check("fill persistent chest", state.transfer_chest(chest_id, "wood", 5, true) == 5)
	var contents: Array = state.furniture.placed.duplicate(true)
	for level in range(2):
		var old_area := House.outdoor_footprint(state.furniture).get_area()
		var coins: int = state.coins
		check("expand interior and footprint " + str(level), state.expand_house() and state.furniture.house_level == level + 1 and House.outdoor_footprint(state.furniture).get_area() > old_area and state.coins == coins - House.COSTS[level].coins)
		check("preserve furniture and chest " + str(level), state.furniture.placed == contents and not State.normalize_save_data(state.to_save_data()).is_empty())
	check("maximum cannot charge again", not state.expand_house() and state.furniture.house_level == 2)
	var occupied := State.new()
	occupied.coins = 1000
	occupied.resources.wood = 200
	occupied.resources.iron = 20
	clear_foundation(occupied)
	var tile := State.FarmTerrain.index_at(Vector2(368, 160))
	occupied.farm.plots[str(tile)] = {"growth": 0, "watered": false}
	check("occupied expansion preserves crops and resources", not occupied.expand_house() and occupied.coins == 1000 and occupied.resources.wood == 200 and occupied.farm.plots.has(str(tile)))
	occupied.farm.plots.clear()
	occupied.furniture.placed.append({"id": 1, "kind": "stool", "x": 368, "y": 160, "area": "farm"})
	check("occupied expansion preserves outdoor furniture", not occupied.expand_house() and occupied.coins == 1000 and occupied.furniture.placed.size() == 1)
	occupied.furniture.placed.clear()
	occupied.farm.plots[str(tile)] = {"growth": -1, "watered": false}
	check("empty soil can become a foundation without locking progression", occupied.expand_house() and not occupied.farm.plots.has(str(tile)) and occupied.furniture.exterior_level == 1)
	var old := State.new().to_save_data()
	old.furniture.house_level = 2
	old.furniture.erase("exterior_level")
	check("old expanded saves keep their farm geometry", State.normalize_save_data(old).furniture.exterior_level == 0)
	var catchup := State.new()
	catchup.restore_save_data(old)
	catchup.coins = 1000
	catchup.resources.wood = 200
	catchup.resources.iron = 20
	clear_foundation(catchup)
	check("old large homes can purchase new land", catchup.expand_house() and catchup.furniture.house_level == 2 and catchup.furniture.exterior_level == 1 and catchup.coins == 880)
	check("old homes retain interior during final land extension", catchup.expand_house() and catchup.furniture.house_level == 2 and catchup.furniture.exterior_level == 2 and not State.normalize_save_data(catchup.to_save_data()).is_empty())
	var natural := State.new()
	natural.coins = 1000
	natural.resources.wood = 200
	natural.resources.iron = 20
	check("first foundation is clear without resource removal", natural.expand_house())
	check("uncleared rock prevents final land purchase", not natural.expand_house() and natural.coins == 880 and natural.resource_left("farm_ore_271") > 0)
	var invalid := natural.to_save_data()
	invalid.furniture.exterior_level = 2
	check("exterior cannot exceed interior level", State.normalize_save_data(invalid).is_empty())
	invalid = natural.to_save_data()
	invalid.phase = "night"
	check("unleased service cannot enter a save", State.normalize_save_data(invalid).is_empty())

func text_fits(node: Node) -> bool:
	for child in node.get_children():
		if child is Label or child is Button:
			var rendered: String = child.tr(child.text) if child.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else child.text
			var width: float = child.get_theme_font("font").get_string_size(rendered, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
			if width > child.size.x: return false
		if not text_fits(child): return false
	return true

func load_world() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(6)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true

func run() -> void:
	domain_checks()
	check("isolated slot opens", Saves.begin_slot(1).ok)
	Saves.pending.state.campaign.introduced = true
	Saves.pending.state.campaign.guide_met = true
	await load_world()
	loop.enter("town")
	check("unleased door remains closed", not loop.state.restaurant_leased)
	loop.enter("restaurant")
	check("unleased restaurant cannot be entered", loop.location == "town")
	loop.state.remaining = 0
	loop._sync_phase()
	await frames()
	check("unleased sunset keeps town services available", loop.location == "town" and loop.state.phase == "day" and not loop.awaiting_open)
	loop.state.remaining = State.DAY_SECONDS
	var actor = loop.property_service.actor
	check("property witch stands on free ground", not loop.town_solids.any(func(rect): return rect.grow(6).has_point(actor.position)))
	lane.player.position = actor.position + Vector2(0, 22)
	await shot("witch_in_town")
	await key()
	check("real interaction opens property office", loop.hud.mode == "property" and paused)
	var office = loop.hud.modal.get_node("PropertyOffice")
	check("rent disabled without funds", office.body.get_node("Rent").disabled)
	loop.state.coins = 1000
	loop.state.resources.wood = 200
	loop.state.resources.iron = 20
	clear_foundation(loop.state)
	office.refresh()
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		check("property text fits and language preserves transaction " + locale, text_fits(office) and paused and loop.state.coins == 1000)
		await shot("office_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	await click(office.body.get_node("Rent"))
	check("real rental button persists exact payment", loop.state.restaurant_leased and loop.state.coins == 940 and loop.save_progress().ok and Saves.read_slot(1).data.state.restaurant_leased)
	var stale_rent: Callable = office.rent_restaurant
	await click(office.body.get_node("House"))
	check("property witch provides expansion panel", loop.hud.mode == "housing" and paused)
	var housing = loop.hud.modal.get_node("HouseUpgrades")
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		check("expansion text fits " + locale, text_fits(housing))
		await shot("expansion_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	await shot("expansion_offer")
	await click(housing.detail.get_node("Expand"))
	check("witch expansion updates saved levels", loop.state.furniture.house_level == 1 and loop.state.furniture.exterior_level == 1 and loop.state.coins == 820)
	loop.hud.close_modal()
	housing.purchase()
	check("closed services reject stale callbacks", not stale_rent.is_valid() and loop.state.coins == 820 and loop.state.furniture.house_level == 1)
	loop.enter("farm")
	var initial := House.outdoor_footprint(loop.state.furniture)
	check("expanded exterior has actual wider collision", initial in loop.area.solids and initial.size == Vector2(208, 112))
	var stopped: Vector2 = await lane._walk(Vector2(140, 190), Vector2.RIGHT, 80)
	check("expanded wall physically stops movement", stopped.x < initial.position.x and stopped.x > 150)
	lane.player.position = Vector2(270, 324)
	check("home doorway stays reachable", await Navigation.walk(lane, loop.area.stations.home + Vector2(0, 12)))
	lane.player.position = Vector2(270, 290)
	lane.camera.offset = Vector2(0, -130)
	await shot("farm_level_1")
	lane.camera.offset = Vector2.ZERO
	loop.hud.open_map()
	loop.hud.map_view.show_region("farm", false)
	check("map shares actual exterior texture", House.exterior_texture(loop.state.furniture).get_width() == 240)
	await shot("farm_map_level_1")
	loop.hud.map_view.show_region("town", false)
	check("map locates property witch", loop.hud.map_view.canvas.region_markers("town").any(func(marker): return marker.get("type", "") == "property" and marker.point == actor.position))
	await shot("town_map")
	loop.hud.close_modal()
	loop.enter("town")
	lane.player.position = actor.position + Vector2(0, 22)
	await key()
	office = loop.hud.modal.get_node("PropertyOffice")
	await click(office.body.get_node("House"))
	housing = loop.hud.modal.get_node("HouseUpgrades")
	await click(housing.detail.get_node("Expand"))
	check("second expansion charges listed materials", loop.state.coins == 420 and loop.state.resources.wood == 90 and loop.state.resources.iron == 9 and loop.state.furniture.exterior_level == 2)
	loop.hud.close_modal()
	loop.enter("farm")
	check("largest foundation blocks farming and construction", not State.FarmTerrain.can_till(loop.state, State.FarmTerrain.index_at(Vector2(160, 192))) and not State.Furniture.placement_error(loop.state.furniture, "stool", Vector2(160, 192), -1, Vector2.INF, "farm").is_empty())
	lane.player.position = Vector2(270, 290)
	lane.camera.offset = Vector2(0, -130)
	await shot("farm_level_2")
	lane.camera.offset = Vector2.ZERO
	loop.enter("home")
	check("largest interior grows with exterior", House.floor_for(loop.state.furniture) == House.FLOORS[2])
	await shot("home_level_2")
	loop.enter("restaurant")
	check("rented restaurant becomes accessible", loop.location == "restaurant")
	loop.state.menu[0] = true
	check("rented restaurant can begin service", loop.state.start_service())
	check("property mutations save to disk", loop.save_progress().ok)
	lane.queue_free()
	await frames(6)
	check("slot reopens after world destruction", Saves.begin_slot(1).ok)
	await load_world()
	check("reload retains lease level and restaurant", loop.location == "restaurant" and loop.state.restaurant_leased and loop.state.furniture.exterior_level == 2 and loop.state.coins == 420)
	loop.enter("town")
	lane.player.position = loop.property_service.actor.position + Vector2(0, 22)
	loop.property_service.open()
	check("night office cannot open transactions", loop.hud.mode.is_empty())
	loop.enter("farm")
	check("reload recreates largest foundation", House.outdoor_footprint(loop.state.furniture) in loop.area.solids)
	lane.queue_free()
	await frames(6)
	Saves.end_session()
	print("PROPERTY VERIFY END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
