extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/hud_top_cleanup/21224/map/"
var lane
var loop
var hud
var bindings
var failures := 0
var capture := false

func _initialize() -> void:
	Preferences.file_path = "res://output/hud_top_cleanup/21224/map/preferences.cfg"
	Saves.directory = "res://output/hud_top_cleanup/21224/map/saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("MAP TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 4) -> void:
	for index in range(count): await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
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

func shot(name: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + name, pixels.save_png(OUT + name + ".png") == OK)

func visit(region: String) -> void:
	hud.close_modal()
	loop.enter(region)
	await frames()
	await key(KEY_M)
	await click(hud.map_view.region_buttons[region])
	await frames()

func run() -> void:
	Preferences.file_path = "res://output/hud_top_cleanup/21224/map/preferences.cfg"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	bindings = root.get_node("InputBindings")
	bindings.apply_saved_bindings()
	# M may already be used by a pre-map version's custom key configuration.
	var legacy := ConfigFile.new()
	legacy.set_value("input", "interact", [KEY_M, 0])
	legacy.set_value("input", "bag", [KEY_F, 0])
	legacy.save(Preferences.file_path)
	bindings.apply_saved_bindings()
	check("legacy custom keys survive new map action", bindings.bindings.interact == [KEY_M, 0] and bindings.bindings.bag == [KEY_F, 0] and bindings.bindings.map == [KEY_F4, 0])
	bindings.reset_defaults()
	Saves.end_session()
	root.get_node("Localization").set_language("zh_CN")
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(6)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.enter("town")
	hud = loop.hud
	loop.audio.set_music_muted(true)
	loop.audio.set_effects_muted(true)
	await key(KEY_M)
	check("M opens a paused world overview", hud.mode == "map" and paused and hud.map_view.selected == "world")
	var remaining: float = loop.state.remaining
	var position: Vector2 = lane.player.position
	Input.action_press("move_right")
	await create_timer(0.2, true).timeout
	Input.action_release("move_right")
	check("map freezes clock and player", loop.state.remaining == remaining and lane.player.position == position)
	await shot("world")
	var canvas = hud.map_view.canvas
	check("town projection reads expanded layout", canvas.region_size("town") == Vector2(1600, 1536))
	check("world locates player at actual coordinates", canvas.player_point == canvas.project(position, "town", canvas.WORLD_RECTS.town))
	await click_at(canvas.global_position + canvas.WORLD_RECTS.farm.get_center())
	check("clicking farm shows its detail without travel", hud.map_view.selected == "farm" and loop.location == "town" and lane.player.position == position)
	await click(hud.map_view.region_buttons.town)
	await frames()
	var store_point: Vector2 = canvas.project(loop.STORE_GATE, "town", canvas.detail_rect("town"))
	await click_at(canvas.global_position + store_point)
	check("map door pin opens destination detail", hud.map_view.selected == "store" and loop.location == "town")
	for region in canvas.PLACES:
		await click(hud.map_view.region_buttons[region])
		check("select region " + region, hud.map_view.selected == region and hud.map_view.region_buttons[region].button_pressed and not canvas.region_markers(region).is_empty())
		await shot("detail_" + region)
	await key(KEY_M)
	check("M closes and resumes", hud.mode.is_empty() and not paused)
	await key(KEY_M)
	await click(hud.map_view.get_node("CloseMap"))
	check("mouse close resumes gameplay", hud.mode.is_empty() and not paused)
	await key(KEY_M)
	await key(KEY_ESCAPE)
	check("Esc closes map without opening pause menu", hud.mode.is_empty() and not paused and not loop.save_menu.open)
	# Reopening reads the player's new position, not an old screenshot.
	lane.player.position = Vector2(400, 450)
	await key(KEY_M)
	check("reopened map updates position", hud.map_view.canvas.player_point == hud.map_view.canvas.project(lane.player.position, "town", hud.map_view.canvas.WORLD_RECTS.town))
	await visit("farm")
	canvas = hud.map_view.canvas
	check("farm player point uses farm dimensions", canvas.player_point == canvas.project(lane.player.position, "farm", canvas.detail_rect("farm")))
	loop.state.farm.plots["0"] = {"growth": 3, "watered": true}
	loop.state.farm.plots["13"] = {"growth": 1, "watered": false}
	canvas.queue_redraw()
	await shot("farm_crops")
	var crops: Dictionary = loop.state.farm.duplicate(true)
	await click(hud.map_view.region_buttons.world)
	await click(hud.map_view.region_buttons.home)
	check("map inspection leaves crops untouched", loop.state.farm == crops)
	# Preserve the existing map-edit checks with a migrated furnished home.
	loop.state.furniture = preload("res://Scenes/Building/furniture_catalog.gd").legacy_data()
	await visit("home")
	canvas = hud.map_view.canvas
	var saved_furniture: Dictionary = loop.state.furniture.duplicate(true)
	var furniture_count: int = canvas.region_items("home").size()
	var item: Dictionary = loop.state.furniture.placed.pop_back()
	check("stored furniture disappears from map", canvas.region_items("home").size() == furniture_count - 1)
	item.x = 392
	item.y = 352
	loop.state.furniture.placed.append(item)
	var moved_found := false
	for entry in canvas.region_items("home"):
		if entry.kind == "home_" + item.kind and entry.x == 392 and entry.y == 352: moved_found = true
	check("moved furniture uses saved coordinates", moved_found)
	loop.state.furniture = saved_furniture
	await click(hud.map_view.region_buttons.world)
	check("indoor world point is placed at house door", canvas.player_point == canvas.project(Vector2(canvas.layouts.farm.home[0], canvas.layouts.farm.home[1]), "farm", canvas.WORLD_RECTS.farm))
	await visit("store")
	canvas = hud.map_view.canvas
	await click(hud.map_view.region_buttons.world)
	check("store world point is placed at town door", canvas.player_point == canvas.project(loop.STORE_GATE, "town", canvas.WORLD_RECTS.town))
	await click(hud.map_view.region_buttons.town)
	check("map key can be rebound", bindings.assign_key("map", 0, KEY_N).ok)
	await frames()
	check("rebinding preserves map title without a key hint", hud.map_view.title.text == "哗啦啦魔女镇")
	await key(KEY_N)
	await key(KEY_M)
	check("old map key no longer opens map", hud.mode.is_empty() and not paused)
	await key(KEY_N)
	check("new map key opens map", hud.mode == "map" and paused)
	bindings.apply_saved_bindings()
	check("map binding persists independently of progress", bindings.bindings.map == [KEY_N, 0] and Saves.active_slot == 0)
	for locale in ["en", "ja", "zh_TW", "zh_CN"]:
		root.get_node("Localization").set_language(locale)
		await frames()
		check("map language " + locale, hud.map_view.title.text == TranslationServer.translate("全镇总览") and hud.mode == "map" and paused)
		await shot("language_" + locale)
	await key(KEY_ESCAPE)
	bindings.reset_defaults()
	await key(KEY_B)
	await key(KEY_M)
	check("map does not override backpack", hud.mode == "bag" and paused)
	await key(KEY_ESCAPE)
	await key(KEY_H)
	await key(KEY_M)
	check("map does not override dialogue", hud.mode == "dialogue" and paused)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await key(KEY_M)
	check("map does not override pause menu", loop.save_menu.open and hud.mode.is_empty() and paused)
	await key(KEY_ESCAPE)
	loop.enter("home")
	await frames()
	check("furniture catalog opens", loop.builder.open_catalog())
	await key(KEY_M)
	check("map respects furniture session", loop.builder.active() and hud.mode.is_empty() and paused)
	await key(KEY_ESCAPE)
	loop.state.phase = "result"
	loop._refresh()
	await key(KEY_M)
	check("settlement blocks map", hud.mode.is_empty() and not paused)
	lane.queue_free()
	await frames(8)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("MAP VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
