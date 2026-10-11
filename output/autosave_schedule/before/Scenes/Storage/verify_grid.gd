extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Session = preload("res://Scenes/Storage/grid_session.gd")
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
	for i in range(count): await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func mouse(point: Vector2, pressed: bool, right: bool = false, shift: bool = false) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var position: Vector2 = container.position + point * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	event.shift_pressed = shift
	event.pressed = pressed
	root.push_input(event, true)
	await frames()

func click(control: Control, right: bool = false, shift: bool = false) -> void:
	for pressed in [true, false]: await mouse(control.get_global_rect().get_center(), pressed, right, shift)

func shot(title: String) -> void:
	if not capture: return
	await create_timer(1.1, true).timeout
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + title, pixels.save_png(OUT + title + ".png") == OK)

func find_slot(slots: Array, id: String) -> int:
	for i in range(slots.size()):
		if slots[i].get("id", "") == id: return i
	return -1

func new_chest(state, point: Vector2 = Vector2(400, 384)) -> int:
	Items.change(state, {"wood": 8})
	if not state.craft_furniture("chest") or not state.place_furniture("chest", point, Vector2(320, 405)): return -1
	return state.furniture.next_id - 1

func filled(state) -> void:
	state.bag_slots = []
	for i in range(state.bag_capacity()): state.bag_slots.append({"id": "mushroom", "count": 99})
	Items.sync(state)

func combined(session) -> Dictionary:
	var amounts := Items.totals(session.slots("bag") + session.slots("chest"))
	if not session.hand.is_empty(): amounts[session.hand.id] = int(amounts.get(session.hand.id, 0)) + session.hand.count
	return amounts

func domain_checks() -> void:
	var state := State.new()
	Items.ensure_bag(state)
	check("starter items occupy five of twelve slots", state.bag_slots.size() == 12 and Items.totals(state.bag_slots).size() == 5)
	check("151 wood forms separate stacks", Items.change(state, {"wood": 151}) and state.bag_slots[5].count == 99 and state.bag_slots[6].count == 52)
	var id := new_chest(state)
	check("eight wood crafts twelve-slot chest", id > 0 and state.resources.wood == 151 and state.furniture_by_id(id).slots.size() == 12)
	var session := Session.new(state, id)
	check("right click takes rounded-up half", session.click("bag", 5, true) and session.hand.count == 50 and state.bag_slots[5].count == 49)
	check("right click places one", session.click("chest", 0, true) and session.hand.count == 49 and session.slots("chest")[0].count == 1)
	check("left click merges remainder", session.click("chest", 0) and session.hand.is_empty() and state.resources.wood == 101)
	session.slots("chest")[1] = {"id": "berry", "count": 10}
	Items.sync_chest(state.furniture_by_id(id))
	session.click("bag", 5)
	check("different items swap", session.click("chest", 1) and session.hand.id == "berry" and session.slots("chest")[1].count == 49)
	session.click("bag", 5)
	check("swapped stack returns to bag", state.bag_slots[5] == {"id": "berry", "count": 10} and session.hand.is_empty())
	session.slots("chest")[0].count = 98
	Items.sync_chest(state.furniture_by_id(id))
	session.click("bag", 6)
	check("merge stops at 99", session.click("chest", 0) and session.slots("chest")[0].count == 99 and session.hand.count == 51)
	session.click("chest", 2)
	check("same item uses independent chest slots", session.slots("chest")[1].count == 49 and session.slots("chest")[2].count == 51)
	state.equipment.axe = 2
	check("quick move stores upgraded tool", session.click("bag", 0, false, true) and not state.has_tool("axe") and state.equipment.axe == 2)
	var saved := state.to_save_data()
	var restored := State.new()
	check("JSON round trip preserves exact positions", restored.restore_save_data(JSON.parse_string(JSON.stringify(saved))) and restored.bag_slots == state.bag_slots and restored.furniture == state.furniture)
	check("quick retrieval retains tool rank", session.click("chest", find_slot(session.slots("chest"), "axe"), false, true) and state.has_tool("axe") and state.equipment.axe == 2)
	var before := state.to_save_data()
	session.click("chest", 2)
	session.click("bag", 7, true)
	var interrupted := state.to_save_data()
	check("save while holding retains last commit", interrupted.bag_slots == before.bag_slots and interrupted.furniture == before.furniture and not State.normalize_save_data(interrupted).is_empty())
	session.finish()
	check("closing returns remainder and keeps placed item", state.bag_slots[7] == {"id": "wood", "count": 1} and session.slots("chest")[2].count == 50 and state.inventory_pending.is_empty())
	check("nonempty chest cannot be packed", not state.store_furniture(id))
	var contents: Array = session.slots("chest").duplicate(true)
	check("moving chest preserves slot positions", state.move_furniture(id, Vector2(432, 384), Vector2(320, 405)) and session.slots("chest") == contents)
	var other := new_chest(state, Vector2(384, 384))
	check("separate chests retain separate grids", other > 0 and state.furniture_by_id(other).items.is_empty() and session.slots("chest") == contents)
	for i in range(12): session.slots("chest")[i] = {"id": "ore", "count": 99}
	session.slots("chest")[11] = {"id": "wood", "count": 98}
	Items.sync_chest(state.furniture_by_id(id))
	Items.change(state, {"wood": 10})
	var wood: int = state.resources.wood
	check("quick transfer fills partial destination", session.click("bag", find_slot(state.bag_slots, "wood"), false, true) and state.resources.wood == wood - 1 and session.slots("chest")[11].count == 99)
	check("full chest keeps remainder in bag", not session.click("bag", find_slot(state.bag_slots, "wood"), false, true) and state.resources.wood == wood - 1)
	var full := State.new()
	filled(full)
	var nodes: Array = full.nodes.duplicate()
	check("full grid preserves gather nodes", not full.gather(0) and full.nodes == nodes)
	full.bag_slots[11].count = 98
	Items.sync(full)
	check("full grid accepts matching partial stack", full.gather(0) and full.bag_slots[11].count == 99)
	check("full grid keeps fishing allowance", not full.catch_fish("sample") and full.fish_left("sample") == 3)
	full.coins = 100
	check("failed purchase keeps coins", not full.business_transaction("buy_seeds") and full.coins == 100)
	full.farm.plots["0"] = {"growth": 3, "watered": true}
	check("failed harvest preserves crop and seeds", not full.work_farm_tile(0) and full.farm.plots["0"].growth == 3 and full.farm.seeds == 0)
	full.bag_slots[0] = {"id": "axe", "count": 1}
	Items.sync(full)
	full.resource_damage.sample = 2
	check("full grid preserves final resource hit", full.strike_resource("sample", "wood") == -1 and full.resource_damage.sample == 2)
	full.bag_slots[1] = {"id": "ore", "count": 2}
	full.bag_slots[2] = {"id": "wood", "count": 1}
	Items.sync(full)
	check("smelting uses freed ingredient slots", full.business_transaction("smelt") and full.resources.iron == 1 and full.resources.wood == 0 and full.resources.ore == 0)
	full.equipment.bag = 3
	Items.ensure_bag(full)
	check("upgrade expands grid preserving positions", full.bag_slots.size() == 36 and full.bag_slots[0].id == "axe")
	var bag_session := Session.new(full)
	check("bag Shift transfers between rows", bag_session.click("bag", 0, false, true) and full.bag_slots[0].is_empty() and full.bag_slots[12].id == "axe")
	var legacy := State.new().to_save_data()
	legacy.erase("bag_slots")
	legacy.erase("bag_overflow")
	legacy.resources.wood = 1000000000
	var migrated := State.new()
	check("legacy unlimited inventory is preserved", migrated.restore_save_data(legacy) and migrated.resources.wood + int(migrated.bag_overflow.get("wood", 0)) == 1000000000)
	var retained: int = migrated.bag_overflow.wood
	Items.change(migrated, {"wood": -99})
	check("overflow claims use freed slots", Items.claim_overflow(migrated) == 99 and migrated.bag_overflow.wood == retained - 99)
	check("overflow remains valid save data", not State.normalize_save_data(migrated.to_save_data()).is_empty())
	for slot in [{"id": "unknown", "count": 1}, {"id": "wood", "count": 100}, {"id": "wood", "count": 1.5}, {"id": "axe", "count": 2}]:
		var invalid := saved.duplicate(true)
		invalid.bag_slots[11] = slot
		check("reject invalid slot " + str(slot), State.normalize_save_data(invalid).is_empty())
	var invalid := saved.duplicate(true)
	invalid.raw[0] += 1
	check("reject mismatched quantity mirrors", State.normalize_save_data(invalid).is_empty())
	invalid = saved.duplicate(true)
	invalid.bag_slots.pop_back()
	check("reject incorrect grid length", State.normalize_save_data(invalid).is_empty())
	invalid = saved.duplicate(true)
	invalid.bag_slots[11] = {"id": "axe", "count": 1}
	invalid.tools.axe = 1
	check("reject duplicated tool across containers", State.normalize_save_data(invalid).is_empty())
	var old_chest := saved.duplicate(true)
	for item in old_chest.furniture.placed:
		if item.kind == "chest":
			item.erase("slots")
			if item.items.has("wood"): item.items.wood = 50
	check("old chest dictionaries migrate", not State.normalize_save_data(old_chest).is_empty())
	var random_state := State.new()
	var random_id := new_chest(random_state)
	Items.change(random_state, {"wood": 200, "berry": 60, "herb": 123})
	var random_session := Session.new(random_state, random_id)
	var original := combined(random_session)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1747
	var conserved := true
	for i in range(1000):
		random_session.click("bag" if rng.randf() < 0.5 else "chest", rng.randi_range(0, 11), rng.randf() < 0.4, rng.randf() < 0.2)
		conserved = conserved and combined(random_session) == original
		conserved = conserved and Items.normalize_slots(random_session.slots("bag"), 12).ok and Items.normalize_slots(random_session.slots("chest"), 12).ok
		if i % 37 == 0: conserved = conserved and not State.normalize_save_data(random_state.to_save_data()).is_empty()
	random_session.finish()
	check("1000 mixed slot actions conserve every item", conserved and combined(random_session) == original and not State.normalize_save_data(random_state.to_save_data()).is_empty())

func clean() -> void:
	if is_instance_valid(lane):
		lane.queue_free()
		await frames(6)
		await create_timer(0.2, true).timeout
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + suffix))
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
	loop.paused_for_test = true
	loop.audio.set_music_muted(true)
	loop.audio.set_effects_muted(true)
	if "--read" in OS.get_cmdline_user_args():
		var chest: Dictionary = loop.state.furniture.placed.back()
		check("fresh process preserves same-item stacks", loop.location == "home" and chest.slots[5] == {"id": "wood", "count": 41} and chest.slots[8] == {"id": "wood", "count": 1})
		check("fresh process restores upgraded tool", chest.slots[11].id == "axe" and loop.state.tools.axe == 0 and loop.state.equipment.axe == 2)
		check("fresh process preserves bag positions", loop.state.bag_slots[9] == {"id": "seed", "count": 12} and loop.state.bag_slots[4].is_empty())
		check("restored chest keeps collision", Catalog.footprint("chest", Catalog.position_of(chest)) in lane.solid_rects)
		await clean()
		print("STORAGE VERIFY END failures=", failures)
		quit(failures)
		return
	loop.enter("home")
	var id := new_chest(loop.state)
	loop.area.refresh_furniture()
	lane.player.position = Vector2(400, 408)
	if "--write" in OS.get_cmdline_user_args():
		var session := Session.new(loop.state, id)
		Items.change(loop.state, {"wood": 42})
		session.click("bag", find_slot(loop.state.bag_slots, "wood"))
		session.click("chest", 8, true)
		session.click("chest", 5)
		loop.state.equipment.axe = 2
		session.click("bag", 0)
		session.click("chest", 11)
		session.click("bag", 4)
		session.click("bag", 9)
		check("fresh-process fixture saves", loop.save_progress().ok)
		lane.queue_free()
		await frames(6)
		await create_timer(0.2, true).timeout
		print("STORAGE VERIFY END failures=", failures)
		quit(failures)
		return
	Items.change(loop.state, {"wood": 151, "mushroom": 5, "berry": 3, "herb": 2})
	loop._refresh()
	await key(KEY_E)
	check("E opens native paused storage", hud.mode == "chest" and paused)
	var view = hud.chest_view
	check("square chest and bag cells created", view.chest_slots.size() == 12 and view.bag_slots.size() == 36 and view.bag_slots[0].size == Vector2(40, 40))
	check("upgrade cells are locked", not view.bag_slots[11].disabled and view.bag_slots[12].disabled)
	var index := find_slot(loop.state.bag_slots, "wood")
	await click(view.bag_slots[index], true)
	check("native right click takes half", view.session.hand.count == 50 and loop.state.bag_slots[index].count == 49)
	await shot("storage_grid_split")
	await click(view.chest_slots[0], true)
	check("native right click places one", view.session.hand.count == 49 and view.session.slots("chest")[0].count == 1)
	await click(view.chest_slots[1])
	check("native left click places remainder", view.session.hand.is_empty() and view.session.slots("chest")[1].count == 49)
	await click(view.bag_slots[index], false, true)
	check("native Shift transfers stack", loop.state.bag_slots[index].is_empty() and view.session.slots("chest")[0].count == 50)
	var source := find_slot(loop.state.bag_slots, "wood")
	await mouse(view.bag_slots[source].get_global_rect().get_center(), true)
	await mouse(view.chest_slots[3].get_global_rect().get_center(), false)
	check("native drag drops at chosen position", view.session.hand.is_empty() and view.session.slots("chest")[3].count == 52 and loop.state.resources.wood == 0)
	await click(view.chest_slots[3])
	await click(view.bag_slots[0])
	check("native click swaps unlike items", view.session.hand.id == "axe" and loop.state.bag_slots[0].id == "wood")
	await click(view.chest_slots[3])
	check("tool transfer updates gameplay ownership", not loop.state.has_tool("axe") and loop.state.furniture_by_id(id).items.axe == 1)
	check("hotbar follows real first-row slot", hud.base.get_node("InventorySlot0/Icon").kind == "wood" and hud.slot_counts[0].text == "52")
	await shot("storage_grid_zh_CN")
	for locale in ["en", "ja", "zh_TW", "zh_CN"]:
		root.get_node("Localization").set_language(locale, false)
		await frames()
		check("grid language " + locale, view.title.text == TranslationServer.translate("木箱 #%d") % id)
		await shot("storage_grid_" + locale)
	await click(view.chest_slots[0])
	check("save while holding stays valid", loop.save_progress().ok)
	await key(KEY_ESCAPE)
	check("Esc returns hand and resumes", hud.mode.is_empty() and not paused and not loop.save_menu.open and loop.state.inventory_pending.is_empty())
	await key(KEY_B)
	check("B opens same backpack grid", hud.mode == "bag" and hud.chest_view.chest_slots.is_empty() and paused)
	view = hud.chest_view
	await click(view.bag_slots[0])
	await click(view.bag_slots[11])
	check("backpack rearranges into empty slot", loop.state.bag_slots[0].is_empty() and loop.state.bag_slots[11].id == "wood" and hud.base.get_node("InventorySlot11/Icon").kind == "wood")
	await shot("backpack_grid")
	await key(KEY_B)
	check("B closes grid", hud.mode.is_empty() and not paused)
	check("autosave preserves exact positions", Saves.read_slot(1).ok and Saves.read_slot(1).data.state.bag_slots == loop.state.bag_slots)
	await clean()
	print("STORAGE VERIFY END failures=", failures)
	quit(failures)
