extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Catalog = preload("res://Scenes/Equipment/equipment_catalog.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://output/project_polish/regressions/equipment/wand_upgrades_"
var lane
var loop
var failures := 0
var capture := false

func _initialize() -> void:
	# Redirect settings before autoloads can read or persist player preferences.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = OUT + "preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = OUT + "saves_%d" % OS.get_process_id()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("EQUIPMENT TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func cast() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = root.get_visible_rect().size / 2.0
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func click(control: Control) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var position := container.position + control.get_global_rect().get_center() * container.scale
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

func shot(name: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("screenshot " + name, pixels.save_png(OUT + name + ".png") == OK)

func rich(state) -> void:
	state.coins = 5000
	state.resources.wood = 99
	state.resources.iron = 99

func domain_checks() -> void:
	migration_checks()
	upgrade_condition_checks()
	var state := State.new()
	check("basic capacities stay compatible", state.bag_capacity() == 12 and state.water_capacity() == 24 and state.equipment == Catalog.DEFAULT_LEVELS)
	var legacy := state.to_save_data()
	legacy.erase("equipment")
	check("old saves receive basic ranks", State.normalize_save_data(legacy).equipment == Catalog.DEFAULT_LEVELS)
	check("insufficient funds do not mutate", not state.upgrade_equipment("wand") and state.coins == 0 and state.resources.iron == 0 and state.equipment.wand == 0)
	rich(state)
	state.tools.wand = 0
	check("missing tool cannot be upgraded", not state.upgrade_equipment("wand") and state.coins == 5000)
	state.tools.wand = 1
	for id in Catalog.IDS:
		for rank in range(3):
			var price := Catalog.cost(id, rank)
			var coins: int = state.coins
			var wood: int = state.resources.wood
			var iron: int = state.resources.iron
			check("exact upgrade cost " + id + str(rank + 1), state.upgrade_equipment(id) and state.equipment[id] == rank + 1 and state.coins == coins - price.coins and state.resources.wood == wood - price.wood and state.resources.iron == iron - price.iron)
		var coins: int = state.coins
		var resources: Dictionary = state.resources.duplicate()
		check("maximum rank cannot charge " + id, not state.upgrade_equipment(id) and state.coins == coins and state.resources == resources)
	check("ownership counts are unchanged by ranks", state.tools == State.STARTING_TOOLS)
	state.farm.water = state.water_capacity()
	state.raw = [30, 3, 3]
	check("upgraded water and full bag validate", not State.normalize_save_data(state.to_save_data()).is_empty())
	var invalid := state.to_save_data()
	invalid.raw = [36, 1, 0]
	check("oversized upgraded bag is rejected", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.farm.water = 73
	check("oversized upgraded water is rejected", State.normalize_save_data(invalid).is_empty())
	for bad in [-1, 4, 0.5, "1"]:
		invalid = state.to_save_data()
		invalid.equipment.wand = bad
		check("invalid rank rejected " + str(bad), State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.equipment.erase("bag")
	check("incomplete ranks rejected", State.normalize_save_data(invalid).is_empty())
	invalid = state.to_save_data()
	invalid.tools.wand = 0
	check("upgraded missing tool rejected", State.normalize_save_data(invalid).is_empty())
	state.phase = "night"
	state.equipment.bag = 0
	var coins: int = state.coins
	check("night upgrades rejected without charge", not state.upgrade_equipment("bag") and state.coins == coins)
	for rank in range(4):
		for kind in ["wood", "ore"]:
			var gather := State.new()
			gather.wand_mode = "red"
			gather.equipment[State.RESOURCE_TOOLS[kind]] = rank
			var hits := 0
			while gather.resource_left("sample") > 0:
				gather.strike_resource("sample", kind)
				hits += 1
			var expected_hits: int = [3, 2, 1, 1][rank]
			var expected_yield: int = (3 if kind == "wood" else 2) + rank
			check("rank changes hits and yield " + kind + str(rank), hits == expected_hits and gather.resources[kind] == expected_yield)
			check("depleted resource cannot pay again " + kind + str(rank), gather.strike_resource("sample", kind) == -1 and gather.resources[kind] == expected_yield)
		var farm := State.new()
		farm.wand_mode = "blue"
		for entry in State.FarmTerrain.layout.props: farm.resource_damage[entry.resource_id] = State.RESOURCE_HITS
		farm.equipment.wand = rank
		check("wand area " + str(rank), farm.work_farm_tile(41) and farm.farm.plots.size() == [1, 3, 9, 15][rank])
		farm.farm.plots.clear()
		farm.work_farm_tile(State.FarmTerrain.indices[Vector2i.ZERO])
		check("wand clips at field edges " + str(rank), farm.farm.plots.size() == [1, 2, 4, 6][rank])
		farm.equipment.wand = rank
		farm.farm.water = 0
		check("refill respects water upgrade " + str(rank), farm.refill_farm_water() and farm.farm.water == Catalog.WATER_CAPACITIES[rank])
		var fishing := State.new()
		fishing.equipment.wand = rank
		for catch_index in range(3 + rank):
			check("upgraded fishing quota " + str(rank) + ":" + str(catch_index), fishing.catch_fish("pond"))
		check("upgraded fishing quota stops without duplicate fish " + str(rank), not fishing.catch_fish("pond") and fishing.resources.fish == 3 + rank)
		var bag := State.new()
		bag.wand_mode = "blue"
		bag.equipment.bag = rank
		var capacity: int = Catalog.BAG_CAPACITIES[rank]
		bag.bag_slots = []
		for i in range(capacity): bag.bag_slots.append({"id": "mushroom", "count": 99})
		bag.bag_slots[-1].count = 98
		Items.sync(bag)
		check("gather fills upgraded capacity " + str(rank), bag.gather(0) and bag.raw[0] == capacity * 99)
		var nodes: Array = bag.nodes.duplicate()
		check("gather overflow keeps node " + str(rank), not bag.gather(1) and bag.nodes == nodes)
		bag.coins = 99
		bag.bag_slots[-1] = {"id": "herb", "count": 98}
		Items.sync(bag)
		check("buy uses upgraded capacity " + str(rank), bag.business_transaction("buy_herb") and bag.coins == 96 and bag.raw[2] == 99)
		check("full upgraded bag cannot be charged " + str(rank), not bag.business_transaction("buy_herb") and bag.coins == 96)
		bag.bag_slots[-1] = {"id": "herb", "count": 98}
		bag.bag_slots[-2] = {"id": "seed", "count": 97}
		Items.sync(bag)
		bag.farm.plots = {"0": {"growth": 3, "watered": true}, "1": {"growth": 3, "watered": true}}
		check("farm harvest uses upgraded capacity " + str(rank), bag.work_farm_tile(0) and bag.raw[2] == 99 and bag.farm.seeds == 99)
		check("full bag preserves mature crop " + str(rank), not bag.work_farm_tile(1) and bag.farm.plots["1"].growth == 3)
		bag.process_raw()
		check("prep preserves full upgraded inventory " + str(rank), bag.materials[0] + bag.materials[1] + bag.materials[2] == (capacity - 1) * 99)
	var farm := State.new()
	farm.wand_mode = "blue"
	for entry in State.FarmTerrain.layout.props: farm.resource_damage[entry.resource_id] = State.RESOURCE_HITS
	farm.equipment.wand = 3
	farm.farm.plots["40"] = {"growth": 2, "watered": true}
	farm.work_farm_tile(41)
	check("wide wand preserves planted crops", farm.farm.plots["40"] == {"growth": 2, "watered": true})
	farm.equipment.bag = 3
	farm.end_phase()
	farm.end_phase()
	farm.next_day()
	check("equipment persists across days", farm.equipment.wand == 3 and farm.bag_capacity() == 36)

func upgrade_condition_checks() -> void:
	var state := State.new()
	for condition in ["coins", "wood", "iron", "wand", "night", "maximum", "invalid"]:
		rich(state)
		state.tools.wand = 1
		state.phase = "day"
		state.equipment.wand = 0
		var id := "wand"
		var reason := "材料不足"
		match condition:
			"coins": state.coins = 19; reason = "金币不足"
			"wood": state.resources.wood = 1
			"iron": state.resources.iron = 0
			"wand": state.tools.wand = 0; reason = "需要法杖。"
			"night": state.phase = "night"; reason = "柜台已打烊。"
			"maximum": state.equipment.wand = 3; reason = "已达最高等级"
			"invalid": id = "unknown"; reason = "未满足升级条件。"
		Items.ensure_bag(state)
		var wallet: int = state.coins
		var inventory: Array = state.bag_slots.duplicate(true)
		var ranks: Dictionary = state.equipment.duplicate()
		check("specific failure without charge " + condition, not state.upgrade_equipment(id) and state.message == reason and state.coins == wallet and state.bag_slots == inventory and state.equipment == ranks)
	state = State.new()
	state.coins = 20
	state.resources.wood = 2
	state.resources.iron = 1
	state.farm.water = 7
	check("exact first cost succeeds and preserves water", state.upgrade_equipment("wand") and state.coins == 0 and state.resources.wood == 0 and state.resources.iron == 0 and state.farm.water == 7 and state.water_capacity() == 36)

func legacy_snapshot() -> Dictionary:
	var state := State.new()
	state.equipment.bag = 1
	var saved := state.to_save_data()
	saved.tools = State.LEGACY_STARTING_TOOLS.duplicate()
	saved.equipment = {"axe": 1, "pickaxe": 2, "hoe": 0, "watering_can": 3, "bag": 1}
	saved.bag_slots = Items.empty_slots(18)
	for index in range(Items.LEGACY_TOOLS.size()):
		saved.bag_slots[index] = {"id": Items.LEGACY_TOOLS[index], "count": 1}
	saved.bag_slots[4] = {"id": "seed", "count": 12}
	saved.bag_slots[11] = {"id": "wood", "count": 17}
	saved.resources.wood = 17
	saved.farm.water = 60
	saved.campaign.rod = 2
	saved.fish_catches = {"pond": 5}
	return saved

func migration_checks() -> void:
	var saved := legacy_snapshot()
	var normalized := State.normalize_save_data(JSON.parse_string(JSON.stringify(saved)))
	check("legacy four tools merge into one wand", not normalized.is_empty() and normalized.tools == {"wand": 1} and normalized.equipment == {"wand": 3, "bag": 1})
	if normalized.is_empty(): return
	check("migration preserves water, fish progress and ordinary slot positions", normalized.farm.water == 60 and normalized.fish_catches.pond == 5 and normalized.campaign.rod == 0 and normalized.bag_slots[4] == saved.bag_slots[4] and normalized.bag_slots[11] == saved.bag_slots[11])
	check("migration frees redundant tool slots", normalized.bag_slots[0].id == "wand" and normalized.bag_slots[1].is_empty() and normalized.bag_slots[2].is_empty() and normalized.bag_slots[3].is_empty())
	check("migrated save is idempotent", State.normalize_save_data(normalized) == normalized)
	# Keep the migration fixture inside the current starter home's floor.
	var chest := {"id": saved.furniture.next_id, "kind": "chest", "x": 384, "y": 384, "slots": Items.empty_slots(12)}
	saved.furniture.next_id += 1
	saved.furniture.placed.append(chest)
	for index in range(4):
		chest.slots[index] = saved.bag_slots[index]
		saved.bag_slots[index] = {}
		saved.tools[Items.LEGACY_TOOLS[index]] = 0
	chest.slots[8] = {"id": "ore", "count": 9}
	Items.sync_chest(chest)
	normalized = State.normalize_save_data(saved)
	check("stored legacy tools stay stored as one upgraded wand", not normalized.is_empty() and normalized.tools.wand == 0 and normalized.furniture.placed.back().items == {"wand": 1, "ore": 9} and normalized.equipment.wand == 3)
	check("stored migration preserves ordinary chest positions", not normalized.is_empty() and normalized.furniture.placed.back().slots[8] == chest.slots[8])
	var invalid := saved.duplicate(true)
	invalid.bag_slots[0] = {"id": "axe", "count": 1}
	invalid.tools.axe = 1
	check("migration rejects duplicate old ownership", State.normalize_save_data(invalid).is_empty())
	invalid = saved.duplicate(true)
	invalid.furniture.placed.back().items.wood = 3
	check("migration rejects mismatched chest mirrors", State.normalize_save_data(invalid).is_empty())
	saved = legacy_snapshot()
	for index in range(4): saved.bag_slots[index] = {}; saved.tools[Items.LEGACY_TOOLS[index]] = 0
	saved.bag_overflow = {"pickaxe": 1, "wood": 101}
	saved.equipment = Catalog.LEGACY_LEVELS.duplicate()
	saved.equipment.bag = 1
	saved.equipment.pickaxe = 2
	saved.campaign.rod = 0
	saved.farm.water = 24
	saved.fish_catches = {}
	normalized = State.normalize_save_data(saved)
	check("overflow migrates without losing deferred resources", not normalized.is_empty() and normalized.bag_overflow == {"wand": 1, "wood": 101} and normalized.equipment.wand == 2)
	saved = legacy_snapshot()
	saved.equipment = Catalog.LEGACY_LEVELS.duplicate()
	saved.equipment.bag = 1
	saved.campaign.rod = 3
	saved.farm.water = 24
	normalized = State.normalize_save_data(saved)
	check("legacy fishing upgrade contributes to wand rank", not normalized.is_empty() and normalized.equipment.wand == 3)
	saved.campaign.rod = 0
	saved.fish_catches = {}
	for index in range(4): saved.bag_slots[index] = {}; saved.tools[Items.LEGACY_TOOLS[index]] = 0
	normalized = State.normalize_save_data(saved)
	check("implicit basic fishing rod migrates when other old tools are absent", not normalized.is_empty() and normalized.tools.wand == 1 and normalized.equipment.wand == 0)
	var state := State.new()
	state.tools.wand = 0
	var plots: Dictionary = state.farm.plots.duplicate(true)
	check("missing wand blocks all gathering actions", state.strike_resource("tree", "wood") == -1 and state.strike_resource("ore", "ore") == -1 and not state.catch_fish("pond") and not state.work_farm_tile(0) and not state.refill_farm_water() and state.farm.plots == plots and state.fish_catches.is_empty())

func check_layout(parent: Node, locale: String) -> void:
	for child in parent.get_children():
		if child is RichTextLabel and child.is_visible_in_tree():
			check("attribute description height fits " + locale + " " + str(child.get_content_height()) + "/" + str(child.size.y), child.get_content_height() <= child.size.y)
			var font: Font = child.get_theme_font("normal_font")
			var font_size: int = child.get_theme_font_size("normal_font_size")
			for line in child.get_parsed_text().split("\n"):
				check("attribute line fits " + locale + " " + line, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= child.size.x)
		if child is Control and child.is_visible_in_tree() and parent is Control:
			check("control stays within panel " + locale + " " + child.name, Rect2(Vector2.ZERO, parent.size).encloses(child.get_rect()))
		if child is Label and child.is_visible_in_tree() and child.autowrap_mode == TextServer.AUTOWRAP_OFF and not child.text.is_empty():
			var width: float = child.get_theme_font("font").get_string_size(child.tr(child.text), HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
			check("label fits " + locale + " " + child.name, width <= child.size.x + 1)
		if child is Button and child.is_visible_in_tree() and not child.text.is_empty():
			var width: float = child.get_theme_font("font").get_string_size(child.tr(child.text), HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
			check("button fits " + locale + " " + child.name, width + 8 <= child.size.x + 1)
		check_layout(child, locale)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	domain_checks()
	check("isolated game slot begins", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("blacksmith")
	await frames()
	check("NPC is installed with collision", loop.area.get_node_or_null("BlacksmithNPC") != null and loop.area.solids.size() == 16)
	lane.player.position = Vector2(48, 420)
	loop.hud.open_equipment_upgrades(loop.area)
	check("NPC service cannot open remotely", loop.hud.mode.is_empty())
	lane.player.position = loop.area.stations.service
	lane.camera.force_update_scroll()
	await shot("blacksmith_npc")
	await cast()
	check("interaction opens smith services", loop.area.service_panel.visible)
	rich(loop.state)
	await shot("smith_upgrade_services")
	await click(loop.area.service_panel.get_node("WandUpgrades"))
	check("NPC upgrade modal pauses world", loop.hud.mode == "upgrades" and paused and not loop.area.service_panel.visible)
	if loop.hud.mode != "upgrades":
		quit(1)
		return
	var panel = loop.hud.modal.get_node("EquipmentUpgrades")
	check("dedicated smith entry selects wand", panel.selected == "wand")
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		await frames()
		check_layout(panel, locale)
		check("all nine wand attributes previewed " + locale, panel.detail.get_node("EquipmentDescription").get_parsed_text().split("\n").size() == 9)
		await shot("wand_preview_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	loop.state.coins = 0
	panel.refresh()
	check("insufficient coins visible and disabled", panel.status.text == "金币不足" and panel.detail.get_node("Upgrade").disabled)
	rich(loop.state)
	loop.state.resources.iron = 0
	panel.refresh()
	check("insufficient materials visible and disabled", panel.status.text == "材料不足" and panel.detail.get_node("Upgrade").disabled)
	rich(loop.state)
	loop.state.tools.wand = 0
	panel.refresh()
	check("missing carried wand visible and disabled", panel.status.text == "需要法杖。" and panel.detail.get_node("Upgrade").disabled)
	loop.state.tools.wand = 1
	panel.refresh()
	loop.hud.close_modal()
	loop.hud.open_equipment_upgrades(loop.area)
	panel.purchase()
	check("queued replaced modal cannot charge", loop.state.equipment.wand == 0 and loop.state.coins == 5000)
	panel = loop.hud.modal.get_node("EquipmentUpgrades")
	var remaining: float = loop.state.remaining
	var position: Vector2 = lane.player.position
	await key(KEY_B)
	check("bag shortcut cannot replace upgrade service", loop.hud.mode == "upgrades")
	for id in Catalog.IDS:
		await click(panel.entries[id])
		for rank in range(3):
			var price := Catalog.cost(id, rank)
			var coins: int = loop.state.coins
			await click(panel.detail.get_node("Upgrade"))
			check("native upgrade " + id + str(rank + 1), loop.state.equipment[id] == rank + 1 and loop.state.coins == coins - price.coins)
			if id == "wand" and rank == 0: await shot("upgrade_zh_CN")
		check("maximum disabled " + id, panel.detail.get_node("Upgrade").disabled)
	var before: Dictionary = loop.state.equipment.duplicate()
	var wallet: int = loop.state.coins
	panel.purchase()
	check("stale maximum click cannot spend", loop.state.equipment == before and loop.state.coins == wallet)
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		await click(panel.entries.wand)
		await frames()
		check_layout(panel, locale)
		check("maximum shows all current wand attributes " + locale, panel.detail.get_node("EquipmentDescription").get_parsed_text().split("\n").size() == 9 and not panel.detail.get_node("EquipmentDescription").text.contains("→"))
		await shot("wand_maximum_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	check("upgrading freezes timers and position", loop.state.remaining == remaining and lane.player.position == position)
	check("NPC purchase waits for scheduled save", Saves.read_slot(1).data.state.equipment != loop.state.equipment)
	check("manual save preserves purchased ranks", loop.save_progress().ok and Saves.read_slot(1).data.state.equipment == loop.state.equipment)
	loop.hud.close_modal()
	panel.purchase()
	check("queued closed service click does nothing", loop.state.coins == wallet)
	await frames()
	check("closing service resumes world", not paused and loop.hud.mode.is_empty())
	loop.area._open_upgrades("wand")
	check("queued hidden counter cannot reopen upgrades", loop.hud.mode.is_empty())
	await cast()
	await click(loop.area.service_panel.get_node("EquipmentUpgrades"))
	check("backpack service selects backpack", loop.hud.modal.get_node("EquipmentUpgrades").selected == "bag")
	loop.hud.close_modal()
	loop.state.phase = "night"
	loop.area._refresh_panel()
	check("both upgrade services closed at night", loop.area.service_panel.get_node("WandUpgrades").disabled and loop.area.service_panel.get_node("EquipmentUpgrades").disabled)
	loop.hud.open_equipment_upgrades(loop.area)
	check("night upgrade modal cannot open", loop.hud.mode.is_empty())
	loop.state.phase = "day"
	loop.hud.open_bag()
	check("backpack UI shows expanded limit", loop.hud.bag_info.text.contains("/ 36"))
	await shot("upgraded_bag")
	await key(KEY_ESCAPE)
	check("mapped interaction key assignment", root.get_node("InputBindings").assign_key("interact", 0, KEY_F).ok)
	await key(KEY_E)
	check("old key does not open NPC service", not loop.area.service_panel.visible)
	loop.state.select_hotbar_slot(9)
	await key(KEY_F)
	check("new key opens NPC service", loop.area.service_panel.visible)
	await key(KEY_ESCAPE)
	Items.ensure_bag(loop.state)
	loop.state.select_hotbar_slot(loop.state.bag_slots.find({"id": "wand", "count": 1}))
	check("reinserted wand is selected for field work", loop.state.is_item_selected("wand"))
	loop.state.wand_mode = "red"
	loop.enter("field")
	var tree = loop.area.resource_nodes.filter(func(node): return node.resource_kind == "wood")[0]
	lane.player.position = tree.anchor
	loop.harvest.paused_for_test = true
	loop.harvest.start(tree)
	loop.harvest.paused_for_test = false
	var wood: int = loop.state.resources.wood
	loop.harvest.advance(0.18)
	check("master wand impacts faster and finishes tree", loop.state.resource_left(tree.resource_id) == 0 and loop.state.resources.wood == wood + 6)
	loop.harvest.advance(0.161)
	check("master animation ends at upgraded duration", not loop.harvest.busy())
	loop.harvest.advance(1.0)
	check("animation cannot repeat resource reward", loop.state.resources.wood == wood + 6)
	loop.enter("dock")
	var pond = loop.area.resource_nodes.filter(func(node): return node.resource_kind == "fish")[0]
	lane.player.position = pond.anchor
	loop.harvest.start(pond)
	check("master fishing uses upgraded waiting time", loop.harvest.wait_seconds >= 1.25 and loop.harvest.wait_seconds <= 2.5)
	loop.harvest.advance(0.46)
	loop.harvest.advance(loop.harvest.wait_seconds + 0.01)
	loop.harvest.advance(2.69)
	check("master fishing keeps extended bite window", loop.harvest.action == "bite")
	loop.harvest.advance(0.02)
	check("master fishing window eventually expires", not loop.harvest.busy() and loop.state.resources.fish == 0)
	loop.harvest.paused_for_test = true
	loop.enter("farm")
	loop.state.wand_mode = "blue"
	for node in loop.area.resource_nodes:
		loop.state.resource_damage[node.resource_id] = State.RESOURCE_HITS
		node.refresh()
	loop.area.refresh_resources()
	lane.player.position = loop.area.tile_center(41) - Vector2(0, 24)
	lane.facing = 0
	loop.area.interact()
	check("master wand affects actual farm area", loop.state.farm.plots.size() == 15)
	check("farm work displays the same held wand actor", loop.harvest.actor.visible and not lane.avatar.visible and loop.harvest.farm_cast_left > 0.0)
	await shot("farm_wand")
	loop.state.farm.water = 0
	lane.player.position = loop.area.stations.refill
	loop.area.action_left = 0.0
	loop.area.interact()
	await frames()
	check("upgraded watering can refills in real scene", loop.state.farm.water == 72)
	loop.state.raw = [30, 3, 3]
	check("expanded state saves", loop.save_progress().ok)
	var expected: Dictionary = loop.state.equipment.duplicate()
	lane.queue_free()
	await frames(5)
	check("saved upgraded slot starts", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	check("reload preserves ranks and expanded inventory", loop.state.equipment == expected and loop.state.raw == [30, 3, 3] and loop.state.farm.water == 72 and loop.state.bag_capacity() == 36)
	check("fresh slot keeps basic equipment", Saves.begin_slot(2).ok and Saves.read_slot(2).data.state.equipment == Catalog.DEFAULT_LEVELS)
	Saves.pending = {}
	lane.queue_free()
	await frames(5)
	for slot in [1, 2]:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(slot) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	Saves.end_session()
	await create_timer(0.2, true).timeout
	print("EQUIPMENT VERIFY END failures=", failures)
	quit(failures)
