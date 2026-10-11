extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Catalog = preload("res://Scenes/Building/furniture_catalog.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://Scenes/Storage/Verification/"
var lane
var loop
var hud
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("STORAGE TEST ", title, ": ", "PASS" if passed else "FAIL")
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

func new_chest(state, point: Vector2 = Vector2(400, 384)) -> int:
	state.furniture.house_level = Catalog.House.MAX_LEVEL
	state.resources.wood += 8
	if not state.craft_furniture("chest", "farm", Vector2(416, 312)) or not state.place_furniture("chest", point, Vector2(320, 405)): return -1
	return state.furniture.next_id - 1

func domain_checks() -> void:
	var state := State.new()
	var old := state.to_save_data()
	old.furniture.stock.erase("chest")
	check("old six-recipe saves migrate with no losses", State.normalize_save_data(old).furniture == state.furniture)
	var id := new_chest(state)
	check("eight wood builds and places an empty chest", id > 0 and state.resources.wood == 0 and state.furniture.stock.chest == 0 and state.furniture_by_id(id).items.is_empty())
	if id < 0: return
	state.raw = [6, 3, 2]
	check("deposit removes exact food from backpack", state.transfer_chest(id, "mushroom", 4, true) == 4 and state.raw[0] == 2 and state.furniture_by_id(id).items.mushroom == 4)
	state.raw = [7, 3, 2]
	check("full backpack rejects withdrawal without loss", state.transfer_chest(id, "mushroom", 4, false) == 0 and state.raw == [7, 3, 2] and state.furniture_by_id(id).items.mushroom == 4)
	state.raw[0] = 5
	check("partial withdrawal respects shared food capacity", state.transfer_chest(id, "mushroom", 4, false) == 2 and state.raw[0] == 7 and state.furniture_by_id(id).items.mushroom == 2)
	state.equipment.bag = 1
	check("upgraded bag capacity is respected", state.transfer_chest(id, "mushroom", 99, false) == 2 and state.raw[0] == 9 and not state.furniture_by_id(id).items.has("mushroom"))
	state.resources.wood = 150
	check("chest stack limit leaves remainder in bag", state.transfer_chest(id, "wood", 150, true) == 99 and state.resources.wood == 51 and state.furniture_by_id(id).items.wood == 99)
	check("full stack never deletes inventory", state.transfer_chest(id, "wood", 1, true) == 0 and state.resources.wood == 51)
	state.resources.wood = 999999999
	check("resource maximum permits only safe partial retrieval", state.transfer_chest(id, "wood", 99, false) == 1 and state.resources.wood == 1000000000 and state.furniture_by_id(id).items.wood == 98)
	state.resources.wood = 51
	check("seed deposit shares real farm inventory", state.transfer_chest(id, "seed", 5, true) == 5 and state.farm.seeds == 7)
	check("seed retrieval restores exact quantity", state.transfer_chest(id, "seed", 3, false) == 3 and state.farm.seeds == 10)
	state.equipment.wand = 2
	check("upgraded tools can be stored", state.transfer_chest(id, "wand", 1, true) == 1 and not state.has_tool("wand") and state.equipment.wand == 2)
	check("stored upgraded tool is valid save data", not State.normalize_save_data(state.to_save_data()).is_empty())
	var restored := State.new()
	check("storage save round trip restores ownership and rank", restored.restore_save_data(JSON.parse_string(JSON.stringify(state.to_save_data()))) and restored.furniture == state.furniture and restored.tools.wand == 0 and restored.equipment.wand == 2)
	check("tool retrieval retains upgrade", state.transfer_chest(id, "wand", 1, false) == 1 and state.tools.wand == 1 and state.equipment.wand == 2)
	var contents: Dictionary = state.furniture_by_id(id).items.duplicate(true)
	check("nonempty chest cannot be packed", not state.store_furniture(id) and state.furniture_by_id(id).items == contents)
	check("filled chest can move without losing contents", state.move_furniture(id, Vector2(432, 384), Vector2(320, 405)) and state.furniture_by_id(id).items == contents)
	var other := new_chest(state, Vector2(384, 384))
	check("separate chests have separate inventories", other > 0 and state.furniture_by_id(other).items.is_empty() and state.furniture_by_id(id).items == contents)
	check("unknown destination and items do not transfer", state.transfer_chest(-1, "wood", 1, true) == 0 and state.transfer_chest(1, "wood", 1, true) == 0 and state.transfer_chest(id, "invalid", 1, true) == 0)
	check("zero and negative quantities cannot duplicate", state.transfer_chest(id, "wood", 0, false) == 0 and state.transfer_chest(id, "wood", -1, false) == 0 and state.furniture_by_id(id).items == contents)
	var before_progress: Dictionary = state.journal.duplicate(true)
	state.transfer_chest(other, "herb", 1, true)
	state.transfer_chest(other, "herb", 1, false)
	check("storage does not count as gathering", state.journal == before_progress)
	state.phase = "night"
	check("chests remain usable at night", state.transfer_chest(other, "seed", 1, true) == 1)
	state.phase = "result"
	check("settlement blocks item mutations", state.transfer_chest(other, "seed", 1, false) == 0)
	state.phase = "day"
	for bad in [-1, 0, 1.5, 100, "3"]:
		var invalid := state.to_save_data()
		invalid.furniture.placed.back().items = {"wood": bad}
		check("save rejects bad chest count " + str(bad), State.normalize_save_data(invalid).is_empty())
	var invalid := state.to_save_data()
	invalid.furniture.placed.back().items = {"unknown": 1}
	check("save rejects unknown item ID", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.furniture.placed.back().items = 3
	check("save rejects non-dictionary contents", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.furniture.placed.back().items = {"wand": 1}
	check("save rejects duplicate owned tools", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.furniture.placed[0]["items"] = {"wood": 1}
	check("save rejects contents attached to other furniture", State.normalize_save_data(invalid).is_empty())
	for item_id in state.furniture_by_id(id).items.keys():
		state.transfer_chest(id, item_id, 99, false)
	check("empty chest packs back to furniture stock", state.store_furniture(id) and state.furniture_by_id(id).is_empty() and state.furniture.stock.chest == 1)
	check("packing twice cannot duplicate chest", not state.store_furniture(id) and state.furniture.stock.chest == 1)

func select_bag(id: String) -> void:
	await click(hud.chest_view.bag_slots[Items.IDS.find(id)])

func select_chest(id: String) -> void:
	await click(hud.chest_view.chest_slots[hud.chest_view.stored_ids().find(id)])

func clean() -> void:
	if is_instance_valid(lane):
		lane.queue_free()
		await frames(6)
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	Saves.end_session()

func run() -> void:
	Preferences.file_path = "user://storage_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://storage_%d" % OS.get_process_id()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--saves="): Saves.directory = argument.trim_prefix("--saves=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("InputBindings").apply_saved_bindings()
	root.get_node("Localization").set_language("zh_CN", false)
	if "--read" not in OS.get_cmdline_user_args(): domain_checks()
	check("isolated slot opens", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(6)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	hud = loop.hud
	loop.audio.set_music_muted(true)
	loop.audio.set_effects_muted(true)
	if "--read" in OS.get_cmdline_user_args():
		var saved: Dictionary = loop.state.furniture.placed.back()
		check("fresh process restores chest, tool and rank", loop.location == "home" and saved.kind == "chest" and saved.items.wood == 42 and saved.items.wand == 1 and loop.state.tools.wand == 0 and loop.state.equipment.wand == 2)
		check("fresh process renders saved chest collision", Catalog.footprint("chest", Catalog.position_of(saved)) in lane.solid_rects)
		check("restored tool can return to bag", loop.state.transfer_chest(saved.id, "wand", 1, false) == 1 and loop.state.equipment.wand == 2 and loop.state.tools.wand == 1)
		await clean()
		print("STORAGE VERIFY END failures=", failures)
		quit(failures)
		return
	loop.enter("home")
	await frames()
	if "--write" in OS.get_cmdline_user_args():
		var id := new_chest(loop.state)
		loop.state.resources.wood = 42
		loop.state.equipment.wand = 2
		loop.state.transfer_chest(id, "wood", 42, true)
		loop.state.transfer_chest(id, "wand", 1, true)
		loop.area.refresh_furniture()
		check("fresh-process fixture saves", loop.save_progress().ok)
		lane.queue_free()
		await frames(6)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
		print("STORAGE VERIFY END failures=", failures)
		quit(failures)
		return
	loop.state.resources.wood = 158
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	loop.builder.open_catalog()
	var builder = loop.builder
	await click(builder.root.get_node("FurnitureCatalog/Recipe_chest"))
	check("chest is visible in real building catalog", builder.selected_kind == "chest" and not builder.detail.get_node("Craft").disabled)
	await shot("chest_recipe")
	await click(builder.detail.get_node("Craft"))
	check("mouse crafts chest using eight wood", loop.state.resources.wood == 150 and loop.state.furniture.stock.chest == 1)
	await click(builder.detail.get_node("Place"))
	await click_at(lane.viewport.get_canvas_transform() * Vector2(400, 384))
	var id: int = loop.state.furniture.next_id - 1
	check("mouse places chest body", builder.mode == "edit" and Catalog.footprint("chest", Vector2(400, 384)) in lane.solid_rects)
	await key(KEY_ESCAPE)
	lane.player.position = Vector2(400, 408)
	await frames()
	check("nearby chest offers mapped interaction", loop.area.nearest_chest().id == id and loop.area.chest_hint.text == "E 打开箱子")
	await shot("chest_in_room")
	await key(KEY_E)
	check("E opens chest and pauses world", hud.mode == "chest" and paused and hud.chest_view.chest_id == id)
	var remaining: float = loop.state.remaining
	var position: Vector2 = lane.player.position
	Input.action_press("move_right")
	await create_timer(0.2, true).timeout
	Input.action_release("move_right")
	check("storage freezes clock and player", loop.state.remaining == remaining and lane.player.position == position)
	await select_bag("wood")
	await click(hud.chest_view.actions.DepositOne)
	check("mouse stores one item", loop.state.resources.wood == 149 and loop.state.furniture_by_id(id).items.wood == 1)
	await click(hud.chest_view.actions.DepositAll)
	check("mouse stores available stack safely", loop.state.resources.wood == 51 and loop.state.furniture_by_id(id).items.wood == 99)
	await select_chest("wood")
	await click(hud.chest_view.actions.TakeOne)
	check("mouse takes one item", loop.state.resources.wood == 52 and loop.state.furniture_by_id(id).items.wood == 98)
	await click(hud.chest_view.actions.TakeAll)
	check("mouse takes stack and clears slot", loop.state.resources.wood == 150 and not loop.state.furniture_by_id(id).items.has("wood"))
	loop.state.raw = [5, 3, 2]
	loop.state.equipment.wand = 2
	hud.chest_view.refresh_language()
	await select_bag("mushroom")
	await click(hud.chest_view.actions.DepositAll)
	loop.state.raw[0] = 7
	hud.chest_view.refresh_language()
	await select_chest("mushroom")
	await click(hud.chest_view.actions.TakeAll)
	check("full bag UI keeps chest items and explains failure", loop.state.furniture_by_id(id).items.mushroom == 5 and hud.chest_view.status.text == "背包已满，无法取出。")
	await select_bag("seed")
	await click(hud.chest_view.actions.DepositOne)
	check("seed transfers use actual farm seed count", loop.state.farm.seeds == 11 and loop.state.furniture_by_id(id).items.seed == 1)
	await select_bag("wand")
	await click(hud.chest_view.actions.DepositOne)
	check("tool UI updates ownership and hotbar", loop.state.tools.wand == 0 and hud.item_counts()[0] == 0 and hud.chest_view.bag_slots[0].disabled)
	await select_bag("wood")
	await click(hud.chest_view.actions.DepositOne)
	await shot("storage_zh_CN")
	for locale in ["en", "ja", "zh_TW", "zh_CN"]:
		root.get_node("Localization").set_language(locale, false)
		await frames()
		check("live storage language " + locale, hud.chest_view.title.text == TranslationServer.translate("木箱 #%d") % id and hud.mode == "chest" and paused)
		await shot("storage_" + locale)
	check("manual save preserves items and upgraded tool", loop.save_progress().ok and Saves.read_slot(1).ok and Saves.read_slot(1).data.state.furniture == loop.state.furniture and Saves.read_slot(1).data.state.equipment.wand == 2)
	await key(KEY_M)
	await key(KEY_J)
	check("storage blocks other modal shortcuts", hud.mode == "chest" and paused)
	await key(KEY_E)
	check("E closes storage and resumes", hud.mode.is_empty() and not paused and not loop.save_menu.open)
	await key(KEY_E)
	await click(hud.chest_view.get_node("CloseChest"))
	check("mouse closes storage", hud.mode.is_empty() and not paused)
	await key(KEY_E)
	await key(KEY_ESCAPE)
	check("Esc closes storage without opening pause menu", hud.mode.is_empty() and not paused and not loop.save_menu.open)
	check("interaction can be rebound", root.get_node("InputBindings").assign_key("interact", 0, KEY_F).ok)
	await frames()
	check("world chest hint follows binding", loop.area.chest_hint.text == "F 打开箱子")
	await key(KEY_E)
	check("old E does not open chest", hud.mode.is_empty())
	await key(KEY_F)
	check("new F opens chest", hud.mode == "chest" and paused)
	await select_chest("wand")
	await click(hud.chest_view.actions.TakeOne)
	check("retrieved tool keeps upgrade", loop.state.tools.wand == 1 and loop.state.equipment.wand == 2)
	await key(KEY_B)
	check("B closes storage", hud.mode.is_empty() and not paused)
	lane.player.position = Vector2(320, 405)
	hud.open_chest(id)
	check("distant chest cannot open remotely", hud.mode.is_empty() and not paused)
	builder.open_catalog()
	builder.selected_id = id
	builder._room("edit")
	check("nonempty chest packing button is disabled", builder.store_button.disabled and builder.status_label.text == "取空箱子后才能收回")
	builder.close()
	var saved: Dictionary = loop.state.furniture.duplicate(true)
	loop.enter("farm")
	loop.enter("home")
	check("scene reentry retains chest contents", loop.state.furniture == saved)
	lane.player.position = Vector2(400, 408)
	await key(KEY_M)
	await click(hud.map_view.region_buttons.home)
	var found := false
	for item in hud.map_view.canvas.region_items("home"):
		if item.kind == "home_chest": found = true
	check("map includes chest in saved room layout", found)
	await shot("map_chest")
	await key(KEY_ESCAPE)
	check("manual save succeeds with chest", loop.save_progress().ok)
	lane.queue_free()
	await frames(6)
	check("saved slot reopens", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(6)
	loop = lane.get_node("GameLoop")
	check("loaded scene restores chest contents and collision", loop.location == "home" and loop.state.furniture == saved and Catalog.footprint("chest", Vector2(400, 384)) in lane.solid_rects)
	await clean()
	print("STORAGE VERIFY END failures=", failures)
	quit(failures)
