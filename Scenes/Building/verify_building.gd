extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Catalog = preload("res://Scenes/Building/furniture_catalog.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://Scenes/Building/Verification/"
var lane
var loop
var builder
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("BUILD TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func click_at(point: Vector2, press: bool = true) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var screen_point := container.position + point * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = screen_point
	root.push_input(motion, true)
	await frames()
	if not press: return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = screen_point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func click(control: Control) -> void:
	await click_at(control.get_global_rect().get_center())

func world_click(point: Vector2, press: bool = true) -> void:
	await click_at(lane.viewport.get_canvas_transform() * point, press)

func shot(name: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("screenshot " + name, pixels.save_png(OUT + name + ".png") == OK)

func domain_checks() -> void:
	var state := State.new()
	check("new room starts empty and small", state.furniture.house_level == 0 and state.furniture.placed.is_empty() and not Catalog.normalize(state.furniture).is_empty())
	var legacy := state.to_save_data()
	legacy.erase("furniture")
	check("legacy saves retain the original room", State.normalize_save_data(legacy).furniture == Catalog.legacy_data())
	state.furniture = Catalog.legacy_data()
	var before := state.to_save_data()
	check("insufficient materials never mutate resources", not state.craft_furniture("table", "farm", Vector2(416, 312)) and state.resources == before.resources and state.furniture == before.furniture)
	state.resources.wood = 100
	state.resources.iron = 20
	for kind in Catalog.IDS:
		state.resources.wood = 100
		state.resources.iron = 20
		state.resources.ore = 100
		var wood: int = state.resources.wood
		var iron: int = state.resources.iron
		check("craft recipe " + kind, state.craft_furniture(kind, "farm", Vector2(416, 312)) and state.resources.wood == wood - Catalog.RECIPES[kind].wood and state.resources.iron == iron - Catalog.RECIPES[kind].iron and state.furniture.stock[kind] == 1)
	state.furniture.stock.stool = Catalog.MAX_STOCK
	var wood: int = state.resources.wood
	check("stock capacity blocks crafting without spending", not state.craft_furniture("stool", "farm", Vector2(416, 312)) and state.resources.wood == wood)
	state.furniture.stock.stool = 1
	check("outside floor cannot consume furniture", not state.place_furniture("stool", Vector2(20, 20), Vector2(320, 405)) and state.furniture.stock.stool == 1)
	check("doorway stays open", not state.place_furniture("stool", Vector2(320, 400), Vector2(320, 405)))
	check("fixed fixtures block placement", not state.place_furniture("stool", Vector2(272, 192), Vector2(320, 405)))
	check("player cannot be covered", not state.place_furniture("stool", Vector2(400, 384), Vector2(400, 382)))
	check("valid placement consumes exactly one", state.place_furniture("stool", Vector2(400, 384), Vector2(320, 405)) and state.furniture.stock.stool == 0)
	var id: int = state.furniture.next_id - 1
	check("overlap rejects second furniture", not state.place_furniture("table", Vector2(400, 384), Vector2(320, 405)) and state.furniture.stock.table == 1)
	check("invalid move leaves original position", not state.move_furniture(id, Vector2(320, 400), Vector2(320, 405)) and state.furniture_by_id(id).x == 400)
	check("valid move does not charge resources", state.move_furniture(id, Vector2(416, 384), Vector2(320, 405)) and state.resources.wood == wood)
	check("storing preserves furniture and materials", state.store_furniture(id) and state.furniture.stock.stool == 1 and state.resources.wood == wood)
	check("storing twice cannot duplicate", not state.store_furniture(id) and state.furniture.stock.stool == 1)
	state.phase = "night"
	check("night building cannot mutate", not state.craft_furniture("stool", "farm", Vector2(416, 312)) and not state.place_furniture("stool", Vector2(400, 384), Vector2(320, 405)) and not state.store_furniture(1))
	state.phase = "day"
	var invalid := state.to_save_data()
	invalid.furniture.placed[0].x = 9999
	check("save rejects out-of-bounds furniture", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.furniture.placed.append(invalid.furniture.placed[0].duplicate())
	check("save rejects duplicate IDs", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.furniture.stock.stool = -1
	check("save rejects negative inventory", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.furniture.placed[0].kind = "unknown"
	check("save rejects unknown recipe IDs", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.furniture.placed[1].x = invalid.furniture.placed[0].x
	invalid.furniture.placed[1].y = invalid.furniture.placed[0].y
	check("save rejects overlapping furniture", State.normalize_save_data(invalid).is_empty())
	var obstacles: Array[Rect2] = [Rect2(64, 356, 512, 12)]
	check("path check catches sealed exit route", not Catalog._exit_reachable(obstacles, Vector2(400, 340)))
	check("path check accepts the starting room", Catalog._exit_reachable(Catalog.fixed_solids(), Vector2(320, 405)))

func run() -> void:
	Preferences.file_path = "user://building_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://building_saves_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	domain_checks()
	check("new slot initializes", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	builder = loop.builder
	loop.enter("town")
	check("building unavailable in town", not builder.open_catalog())
	loop.state.furniture = Catalog.legacy_data()
	loop.enter("home")
	await frames(5)
	check("original home collisions preserved", loop.area.solids.size() == 19 and loop.area.furniture_bodies.size() == 9)
	loop.state.furniture.stock.workbench = 1
	check("test workbench placed", loop.state.place_furniture("workbench", Vector2(536, 400), lane.player.position))
	var bench_id: int = loop.state.furniture.next_id - 1
	loop.area.refresh_furniture()
	lane.player.position = Vector2(536, 416)
	check("home catalog opens", builder.open_catalog())
	check("catalog pauses game", builder.mode == "catalog" and paused and not loop.save_menu.open and not loop.hud.base.visible)
	check("craft disabled without materials", builder.detail.get_node("Craft").disabled)
	check("place disabled without stock", builder.detail.get_node("Place").disabled)
	loop.state.resources.wood = 40
	loop.state.resources.iron = 10
	builder._refresh_catalog()
	await click(builder.detail.get_node("Craft"))
	check("mouse crafts and updates stock", loop.state.resources.wood == 38 and loop.state.furniture.stock.stool == 1 and not builder.detail.get_node("Place").disabled)
	check("test workbench stored", loop.state.store_furniture(bench_id))
	loop.area.refresh_furniture()
	await shot("catalog_zh_CN")
	for locale in ["en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		await frames()
		await shot("catalog_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	await click(builder.detail.get_node("Place"))
	check("stock enters placement", builder.mode == "place")
	var remaining: float = loop.state.remaining
	var position: Vector2 = lane.player.position
	await key(KEY_B)
	check("building blocks unrelated modals", loop.hud.mode.is_empty())
	await world_click(Vector2(320, 400))
	check("invalid mouse placement spends nothing", builder.mode == "place" and loop.state.furniture.stock.stool == 1 and not builder.error.is_empty())
	await world_click(Vector2(400, 384), false)
	check("green preview matches mouse world position", builder.cursor == Vector2(400, 384) and builder.error.is_empty())
	await shot("placement")
	await world_click(Vector2(400, 384))
	var id: int = loop.state.furniture.next_id - 1
	check("mouse confirms real furniture body", builder.mode == "edit" and loop.area.furniture_bodies.size() == 10 and loop.state.furniture.stock.stool == 0)
	if builder.mode != "edit":
		quit(1)
		return
	var old_rect := Catalog.footprint("stool", Vector2(400, 384))
	check("new body included in navigation solids", old_rect in lane.solid_rects)
	await click(builder.move_button)
	await key(KEY_D)
	check("keyboard shifts preview one grid cell", builder.cursor == Vector2(416, 384))
	await key(KEY_ESCAPE)
	check("cancel move retains original furniture", builder.mode == "edit" and loop.state.furniture_by_id(id).x == 400 and paused)
	await click(builder.move_button)
	await key(KEY_D)
	await key(KEY_F)
	check("keyboard confirms atomic move", builder.mode == "edit" and loop.state.furniture_by_id(id).x == 416)
	check("moving replaces collision footprint", old_rect not in lane.solid_rects and Catalog.footprint("stool", Vector2(416, 384)) in lane.solid_rects)
	await click(builder.store_button)
	check("store removes body and returns item", loop.state.furniture.stock.stool == 1 and loop.area.furniture_bodies.size() == 9 and loop.state.furniture_by_id(id).is_empty())
	await world_click(Vector2(141, 300))
	check("original furniture can be selected", loop.state.furniture_by_id(builder.selected_id).kind == "bed")
	await click(builder.store_button)
	check("original furniture can be stored", loop.state.furniture.stock.bed == 1 and loop.area.furniture_bodies.size() == 8)
	builder._catalog()
	await click(builder.detail.get_node("Place"))
	check("remapped interaction applies", root.get_node("InputBindings").assign_key("interact", 0, KEY_F).ok)
	await world_click(Vector2(400, 384), false)
	await key(KEY_E)
	check("old interact cannot confirm placement", builder.mode == "place" and loop.state.furniture.stock.stool == 1)
	await key(KEY_F)
	check("new interact confirms placement", builder.mode == "edit" and loop.state.furniture.stock.stool == 0)
	check("building freezes world clock and player", loop.state.remaining == remaining and lane.player.position == position)
	await shot("room_arranged")
	var expected: Dictionary = loop.state.furniture.duplicate(true)
	check("save while building succeeds", loop.save_progress().ok)
	var loaded := Saves.read_slot(1)
	check("disk round trip retains stock and positions", loaded.ok and loaded.data.state.furniture == expected)
	await key(KEY_ESCAPE)
	check("Esc exits building and restores HUD", not builder.active() and not paused and loop.hud.base.visible and not loop.save_menu.open)
	lane.player.position = Vector2(400, 408)
	lane.test_direction = Vector2.UP
	for index in range(25): await physics_frame
	lane.test_direction = Vector2.ZERO
	check("placed furniture blocks real walking", lane.player.position.y >= 389 and lane.player.position.y < 408)
	var blocked_id: int = loop.state.furniture.next_id - 1
	check("collision test furniture stored", loop.state.store_furniture(blocked_id))
	loop.area.refresh_furniture()
	lane.player.position = Vector2(400, 408)
	lane.test_direction = Vector2.UP
	for index in range(25): await physics_frame
	lane.test_direction = Vector2.ZERO
	check("stored furniture releases real walking path", lane.player.position.y < 380)
	loop.state.furniture = expected.duplicate(true)
	loop.area.refresh_furniture()
	lane.player.position = Vector2(354, 176)
	lane.camera.force_update_scroll()
	var camera_before: Vector2 = lane.camera.position
	builder.open_catalog()
	check("building frames room from north wall", lane.viewport.get_canvas_transform().origin.y == -120)
	builder.close()
	check("closing restores camera position", lane.camera.position == camera_before)
	loop.enter("farm")
	loop.enter("home")
	await frames()
	check("reentering room preserves edits", loop.state.furniture == expected and loop.area.furniture_bodies.size() == expected.placed.size())
	builder.open_catalog()
	await key(KEY_ESCAPE)
	check("catalog Esc closes without pause menu", not builder.active() and not loop.save_menu.open and not paused)
	lane.queue_free()
	await frames(5)
	check("saved slot begins again", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	loop = lane.get_node("GameLoop")
	check("loaded scene renders saved furniture", loop.location == "home" and loop.state.furniture == expected and loop.area.furniture_bodies.size() == expected.placed.size())
	lane.queue_free()
	await frames(5)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	Saves.end_session()
	# Let stopped audio voices drain before the engine releases resources.
	await create_timer(0.25).timeout
	print("BUILD VERIFY END failures=", failures)
	quit(failures)
