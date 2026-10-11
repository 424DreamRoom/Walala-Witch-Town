extends SceneTree
const OUT := "res://Art/Environment/Hearthwood/Verification/Businesses/"
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
var lane
var loop
var failures := 0
var capture := "--business-capture" in OS.get_cmdline_user_args()

func _initialize() -> void:
	var old_actor: GDScript = load("res://Scenes/Campaign/resident_actor.gd")
	old_actor.source_code = old_actor.source_code.replace("Art/Characters/NPC32/residents/", "Art/Campaign/npcs/").replace("Vector2.ZERO, 32)", "Vector2.ZERO, 48)")
	assert(old_actor.reload() == OK)

	Preferences.file_path = "res://output/business_npcs/preferences.cfg"
	Saves.directory = "res://output/business_npcs/saves"
	Saves.end_session()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/business_npcs"))
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print(title, ": PASS" if ok else ": FAIL")
	if not ok:
		failures += 1

func frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame
		await physics_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func walk_to(target: Vector2) -> void:
	var arrived: bool = await preload("res://Scenes/LanternLane/verification_navigation.gd").walk(lane, target)
	check("real walk to " + str(target), arrived)

func click(button: Button) -> void:
	if not capture:
		button.pressed.emit()
		await frames()
		return
	var container = lane.viewport.get_parent()
	var point: Vector2 = container.position + (button.global_position + button.size * 0.5) * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await frames(2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames(2)

func shot(title: String) -> void:
	if not capture:
		return
	if title.ends_with("room") or title.ends_with("exterior"):
		loop.state.message = ""
		loop.last_message = ""
		loop.message_left = 0.0
	await frames()
	RenderingServer.force_draw(false)
	var picture: Image = lane.viewport.get_texture().get_image()
	check("capture " + title, picture.save_png(OUT + title + ".png") == OK)
	check("capture window " + title, root.get_texture().get_image().save_png(OUT + title + "_window.png") == OK)

func check_staff_locales() -> void:
	var translated_names := {"zh_CN": "店主 · 露米", "en": "Shopkeeper · Lumi", "ja": "店主・ルミ", "zh_TW": "店主 · 露米"} if loop.location == "store" else {"zh_CN": "铁匠 · 余烬", "en": "Blacksmith · Ember", "ja": "鍛冶屋・エンバー", "zh_TW": "鐵匠 · 餘燼"}
	for locale in translated_names:
		root.get_node("Localization").set_language(locale, false)
		await frames()
		var provider = loop.area
		var caption: Label = provider.service_panel.get_node("StaffCaption")
		check(loop.location + " panel name localizes " + locale, caption.tr(caption.text) == translated_names[locale])
		var fits := true
		for control in provider.service_panel.get_children():
			if control is Label or control is Button:
				var copy: String = control.tr(control.text)
				var width: float = control.get_theme_font("font").get_multiline_string_size(copy,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
				fits = fits and width <= control.size.x + 1 and control.position.x + control.size.x <= provider.service_panel.size.x + 1 and control.position.y + control.size.y <= provider.service_panel.size.y + 1
		check(loop.location + " service text fits " + locale, fits)
		await shot(loop.location + "_npc_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	check("both business markers installed", loop.gate_labels.size() >= 6)
	if "footstep_surfaces" in loop:
		check("smith stone floor sound", loop.footstep_surfaces.resolve("blacksmith", Vector2(294, 335), "snow") == "stone")
		check("smith wooden floor sound", loop.footstep_surfaces.resolve("blacksmith", Vector2(469, 300), "rain") == "wood")
		check("store wooden floor sound", loop.footstep_surfaces.resolve("store", Vector2(352, 314), "snow") == "wood")
	check("business markers hidden at distance", not loop.gate_labels[4].visible and not loop.gate_labels[5].visible)
	if capture:
		await walk_to(loop.BLACKSMITH_GATE + Vector2(112, -90))
		await shot("blacksmith_exterior_full")
	await walk_to(Vector2(624, 420))
	await walk_to(loop.BLACKSMITH_GATE + Vector2(0, 20))
	check("near blacksmith marker", loop.gate_labels[4].visible)
	await shot("blacksmith_exterior")
	lane.weather.set_weather("rain")
	var return_pos: Vector2 = loop.BLACKSMITH_GATE + Vector2(0, 34)
	await walk_to(loop.BLACKSMITH_GATE)
	check("walking to smith door stays outside", loop.location == "town")
	await key(KEY_E)
	check("interacting enters blacksmith", loop.location == "blacksmith")
	if loop.location != "blacksmith":
		quit(1)
		return
	check("town detached inside workshop", not lane.world.is_inside_tree())
	check("workshop Y sorting", loop.area.y_sort_enabled and lane.player.get_parent() == loop.area)
	check("workshop and NPC collisions", loop.area.solids.size() == 16 and loop.area.get_node_or_null("BlacksmithNPC") != null)
	check("Ember staffs the forge with his resident art and panel name", loop.area.staff_id == "ember" and loop.area.staff.sprite.texture.resource_path.ends_with("/ember.png") and loop.area.service_panel.get_node("StaffCaption").text == "铁匠 · 余烬")
	check("smith feet stay clear of furniture", not loop.area.solids[12].intersects(loop.area.solids[-1]))
	check("interior bounds", lane.camera.limit_right == 640 and lane.camera.limit_bottom == 480)
	check("interior weather and rain audio disabled", not lane.weather.visible and not loop.audio.ambient.playing)
	check("interior keeps compact UI", not loop.inventory.visible and not loop.sidebar_title.visible)
	check("counter hidden on entry", not loop.area.service_panel.visible)
	var fire_frame: int = loop.area.fire.frame
	await create_timer(0.21).timeout
	check("furnace fire advances", fire_frame != loop.area.fire.frame)
	await walk_to(loop.area.stations.service)
	check("smith has no overhead name", not loop.area.staff.has_node("ResidentName"))
	await key(KEY_E)
	check("E opens smith service", loop.area.service_panel.visible)
	await check_staff_locales()
	check("insufficient resources disables smelting", loop.area.buttons[0].disabled)
	loop.state.resources.ore = 2
	loop.state.resources.wood = 1
	await frames()
	await click(loop.area.buttons[0])
	check("smelting consumes exact recipe", loop.state.resources.ore == 0 and loop.state.resources.wood == 0 and loop.state.resources.iron == 1)
	await shot("blacksmith_service")
	var before: Dictionary = loop.state.resources.duplicate()
	loop.area.transact("smelt")
	check("insufficient smelting cannot duplicate iron", loop.state.resources == before)
	await key(KEY_ESCAPE)
	check("Escape closes panel", not loop.area.service_panel.visible)
	await walk_to(Vector2(354, 335))
	loop.area.transact("sell_iron")
	check("remote and wrong-shop transaction rejected", loop.state.resources.iron == 1 and loop.state.coins == 0)
	await walk_to(Vector2(354, 240))
	await shot("blacksmith_room")
	var end: Vector2 = await lane._walk(Vector2(469, 270), Vector2.UP, 60)
	check("workbench blocks player", end.y >= 229.8 and end.y < 232)
	await key(KEY_R)
	check("R safe workshop spawn", lane.player.position == loop.area.spawn)
	await walk_to(loop.area.stations.exit)
	check("walking to smith exit stays inside", loop.location == "blacksmith")
	await key(KEY_E)
	check("interacting returns from workshop", loop.location == "town" and lane.player.position.distance_to(return_pos) < 0.1)
	check("rain restored outdoors", lane.weather.visible and loop.audio.current_ambient == "rain")
	lane.weather.clear_weather()
	await walk_to(Vector2(624, 420))
	await walk_to(Vector2(1024, 364))
	if capture:
		await walk_to(loop.STORE_GATE + Vector2(112, -90))
		await shot("store_exterior_full")
	await walk_to(loop.STORE_GATE + Vector2(0, 20))
	await shot("store_exterior")
	return_pos = loop.STORE_GATE + Vector2(0, 34)
	await walk_to(loop.STORE_GATE)
	check("walking to store door stays outside", loop.location == "town")
	await key(KEY_E)
	check("interacting enters store", loop.location == "store")
	if loop.location != "store":
		quit(1)
		return
	check("store fixtures and NPC collide and Y sort", loop.area.solids.size() == 15 and loop.area.y_sort_enabled and loop.area.get_node_or_null("StoreNPC") != null)
	check("Lumi staffs the store with her resident art and panel name", loop.area.staff_id == "lumi" and loop.area.staff.sprite.texture.resource_path.ends_with("/lumi.png") and loop.area.service_panel.get_node("StaffCaption").text == "店主 · 露米" and not loop.area.staff.has_node("ResidentName"))
	check("shopkeeper stands clear of the counter", not loop.area.solids[11].intersects(loop.area.solids[-1]))
	var idle_frame: int = loop.area.staff.sprite.frame
	var animated := false
	for tick in range(12):
		await create_timer(0.15).timeout
		animated = animated or idle_frame != loop.area.staff.sprite.frame
	check("shopkeeper has an idle animation", animated)
	await walk_to(loop.area.stations.service)
	await key(KEY_E)
	check("E opens store counter", loop.area.service_panel.visible)
	await check_staff_locales()
	check("no coins disables purchasing", loop.area.buttons[0].disabled)
	await click(loop.area.buttons[3])
	check("sell iron enters shared wallet", loop.state.coins == 8 and loop.state.resources.iron == 0)
	await click(loop.area.buttons[0])
	check("mouse purchase enters raw backpack", loop.state.raw == [1, 0, 0] and loop.state.coins == 5)
	await click(loop.area.buttons[1])
	check("second ingredient uses same wallet", loop.state.raw == [1, 1, 0] and loop.state.coins == 2)
	check("store stock displays purchased ingredients", loop.area.stock.text.begins_with("蘑菇1  莓果1  香草0"))
	Saves.active_slot = 1
	Saves.created_at = int(Time.get_unix_time_from_system())
	var saved: Dictionary = loop.save_progress()
	var reloaded: Dictionary = Saves.read_slot(1)
	check("NPC purchases persist in the isolated save", saved.ok and reloaded.ok and reloaded.data.state.raw == [1, 1, 0] and reloaded.data.state.coins == 2 and reloaded.data.state.bag_slots == loop.state.bag_slots and reloaded.data.world.location == "store")
	Saves.end_session()
	await shot("store_service")
	check("cannot overspend", not loop.state.business_transaction("buy_herb") and loop.state.coins == 2)
	var seeds_before: int = loop.state.farm.seeds
	await click(loop.area.buttons[5])
	check("store seed button buys four seeds", loop.state.farm.seeds == seeds_before + 4 and loop.state.coins == 0)
	loop.state.raw[2] = 1
	await frames()
	await click(loop.area.buttons[6])
	check("store herb button sells harvested inventory", loop.state.raw[2] == 0 and loop.state.coins == 3)
	await shot("store_farming_service")
	loop.state.coins = 20
	var original_slots: Array = loop.state.bag_slots.duplicate(true)
	for i in range(loop.state.bag_slots.size()):
		if loop.state.bag_slots[i].is_empty(): loop.state.bag_slots[i] = {"id": "mushroom", "count": Items.STACK_SIZE}
	Items.sync(loop.state)
	var full_slots: Array = loop.state.bag_slots.duplicate(true)
	check("full bag purchase has no side effects", not loop.state.business_transaction("buy_herb") and loop.state.coins == 20 and loop.state.bag_slots == full_slots)
	loop.state.bag_slots = original_slots
	Items.sync(loop.state)
	await walk_to(Vector2(225, 314))
	check("walking away closes counter", not loop.area.service_panel.visible)
	var remote_raw: Array = loop.state.raw.duplicate()
	loop.area.transact("buy_mushroom")
	check("shopkeeper cannot sell from a distance", loop.state.raw == remote_raw and loop.state.coins == 20)
	await walk_to(Vector2(225, 240))
	await shot("store_room")
	end = await lane._walk(Vector2(352, 330), Vector2.UP, 60)
	check("store counter blocks player", end.y >= 290.8 and end.y < 293)
	await key(KEY_R)
	check("R safe store spawn", lane.player.position == loop.area.spawn)
	await walk_to(loop.area.stations.exit)
	check("walking to store exit stays inside", loop.location == "store")
	await key(KEY_E)
	check("store returns to safe doorstep", loop.location == "town" and lane.player.position.distance_to(return_pos) < 0.1)
	check("town bounds restored", lane.camera.limit_right == lane.world_size.x and lane.camera.limit_bottom == lane.world_size.y)
	loop.enter("store")
	loop.state.resources.iron = 2
	loop.state.tick(loop.state.remaining)
	loop._sync_phase()
	check("business sunset returns for preparation", loop.location == "restaurant" and loop.state.phase == "day")
	loop.state.set_menu_dish(0, true)
	loop.end_phase()
	await frames()
	check("business day end enters restaurant", loop.location == "restaurant" and loop.state.phase == "night")
	check("night transaction rejected", not loop.state.business_transaction("sell_iron") and loop.state.resources.iron == 2)
	check("night buying rejected", not loop.state.business_transaction("buy_mushroom") and loop.state.coins == 20)
	loop.end_phase()
	loop.end_phase()
	await frames()
	check("next day keeps iron and wallet", loop.state.resources.iron == 2 and loop.state.coins == 20 and loop.state.day == 2)
	check("next day normal town entry", loop.location == "town" and lane.player.get_parent() == lane.actors)
	loop.state.resources.ore = 1
	loop.state.resources.wood = 1
	loop.state.resources.fish = 1
	check("ore sale pays exact amount", loop.state.business_transaction("sell_ore") and loop.state.resources.ore == 0 and loop.state.coins == 23)
	check("wood sale pays exact amount", loop.state.business_transaction("sell_wood") and loop.state.resources.wood == 0 and loop.state.coins == 24)
	check("fish sale pays exact amount", loop.state.business_transaction("sell_fish") and loop.state.resources.fish == 0 and loop.state.coins == 28)
	check("empty sale cannot duplicate coins", not loop.state.business_transaction("sell_fish") and loop.state.coins == 28)
	loop.enter("home")
	check("existing home still enters", loop.location == "home" and not lane.weather.visible)
	loop.enter("town")
	lane.queue_free()
	await frames()
	print("BUSINESS VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
