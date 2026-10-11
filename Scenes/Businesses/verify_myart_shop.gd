extends SceneTree
## All settings and progress for this preview stay in a PID-specific test profile.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Food = preload("res://Scenes/Businesses/food_catalog.gd")
const OUT := "res://output/myart_shop/"
var failures := 0
var checks := 0
var lane
var loop
var capture := "--myart-capture" in OS.get_cmdline_user_args()
var preview := "--myart-preview" in OS.get_cmdline_user_args()

func _initialize() -> void:
	var profile := OUT + "session_%d/" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile + "preferences.cfg"
	Saves.directory = profile + "saves"
	Saves.end_session()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print(title, ": PASS" if ok else ": FAIL")

func frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame
		await physics_frame

func click(button: Button) -> void:
	if not capture and not preview:
		button.pressed.emit()
		await frames()
		return
	var container = lane.viewport.get_parent()
	var point: Vector2 = container.position + (button.global_position + button.size * 0.5) * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames(2)

func shot(title: String) -> void:
	if not capture and not preview: return
	loop.state.message = ""
	loop.last_message = ""
	loop.message_left = 0.0
	loop.thought_bubble.hide()
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + title, root.get_texture().get_image().save_png(OUT + title + ".png") == OK)
	check("capture native " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + "_native.png") == OK)

func text_fits(control: Node) -> bool:
	var fits := true
	for child in control.get_children():
		if child is Label or child is Button:
			var copy: String = child.tr(child.text)
			var width: float = child.get_theme_font("font").get_multiline_string_size(copy, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
			fits = fits and width <= child.size.x + 1
			if child.get_parent() is Control:
				fits = fits and child.position.x >= 0 and child.position.y >= 0 and child.position.x + child.size.x <= child.get_parent().size.x + 1 and child.position.y + child.size.y <= child.get_parent().size.y + 1
		fits = text_fits(child) and fits
	return fits

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Icon/MyArt/manifest.json"))
	for id in Food.DATA:
		check(id + " source hash unchanged", FileAccess.get_sha256(manifest[id].source) == manifest[id].source_sha256)
		check(id + " native 16px texture", Food.DATA[id].texture.get_size() == Vector2(16, 16))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	loop.enter("store")
	lane.player.position = loop.area.stations.service
	loop.state.coins = 100
	await frames()
	loop.area.interact()
	check("store has three cards and all seven existing trades", loop.area.buttons.size() == 10 and loop.area.service_panel.visible)
	var separate_rows := true
	for i in range(1, 7):
		separate_rows = separate_rows and loop.area.buttons[i - 1].position.y + loop.area.buttons[i - 1].size.y <= loop.area.buttons[i].position.y
	check("compact trade rows do not overlap", separate_rows)
	check("food display belongs to the existing colliding counter", loop.area.get_node("store_counter/MyArtFoodDisplay").get_child_count() == 3 and loop.area.solids.size() == 15)
	for id in Food.DATA:
		var button: Button = loop.area.service_panel.get_node("Food_" + id)
		check(id + " card uses authored icon with nearest filtering", button.get_node("FoodIcon").texture == Food.DATA[id].texture and button.get_node("FoodIcon").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		var coins_before: int = loop.state.coins
		await click(button)
		check(id + " actual purchase enters bag and deducts exact price", Items.count(loop.state, id) == 1 and loop.state.coins == coins_before - Food.DATA[id].price)
		Items.ensure_bag(loop.state)
		check(id + " stack survives repeated inventory sync", Items.count(loop.state, id) == 1)
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		await frames()
		check("all shop labels fit " + locale, text_fits(loop.area.service_panel))
		await shot("store_" + locale)
	root.get_node("Localization").set_language("zh_CN", false)
	Saves.active_slot = 1
	Saves.created_at = int(Time.get_unix_time_from_system())
	var saved: Dictionary = loop.save_progress()
	var loaded: Dictionary = Saves.read_slot(1)
	check("new foods round trip through isolated disk save", saved.ok and loaded.ok and loaded.data.state.bag_slots == loop.state.bag_slots)
	Saves.end_session()
	var state := State.new()
	check("new foods restore through validated state", state.restore_save_data(loaded.data.state) and Items.count(state, "bread") == 1 and Items.count(state, "egg") == 1 and Items.count(state, "tomato") == 1)
	var chest := {"id": state.furniture.next_id, "kind": "chest", "x": 300, "y": 300, "items": {}, "slots": Items.empty_slots(Items.CHEST_SLOTS)}
	state.furniture.placed.append(chest)
	state.furniture.next_id += 1
	for id in Food.DATA:
		check(id + " chest deposit and withdrawal conserve quantity", state.transfer_chest(chest.id, id, 1, true) == 1 and Items.count(state, id) == 0 and state.transfer_chest(chest.id, id, 1, false) == 1 and Items.count(state, id) == 1)
	state.coins = 0
	check("insufficient funds do not deduct or add food", not state.business_transaction("buy_bread") and state.coins == 0 and Items.count(state, "bread") == 1)
	state.coins = 100
	state.phase = "night"
	check("night purchases rejected", not state.business_transaction("buy_egg") and state.coins == 100 and Items.count(state, "egg") == 1)
	state.phase = "day"
	for i in range(state.bag_capacity()): state.bag_slots[i] = {"id": "mushroom", "count": 99}
	Items.sync(state)
	var full := state.bag_slots.duplicate(true)
	check("full bag rejects food without charge", not state.business_transaction("buy_tomato") and state.coins == 100 and state.bag_slots == full)
	state.bag_slots[0] = {"id": "bread", "count": 98}
	Items.sync(state)
	check("food stacks to 99 even with no empty slot", state.business_transaction("buy_bread") and Items.count(state, "bread") == 99 and state.coins == 94)
	check("full food stack rejects without charge", not state.business_transaction("buy_bread") and Items.count(state, "bread") == 99 and state.coins == 94)
	var before: int = loop.state.coins
	lane.player.position = loop.area.spawn
	loop.area.transact("buy_bread")
	check("remote food purchase rejected", loop.state.coins == before and Items.count(loop.state, "bread") == 1)
	lane.player.position = loop.area.stations.service
	await frames()
	if not loop.area.service_panel.visible: loop.area.interact()
	if capture or preview: await create_timer(3.0).timeout
	await shot("store_preview")
	loop.area.service_panel.hide()
	loop.hud.open_bag()
	await frames()
	await shot("bag_preview")
	loop.hud.close_modal()
	loop.area.interact()
	for id in Food.DATA:
		check(id + " source still unchanged after engine verification", FileAccess.get_sha256(manifest[id].source) == manifest[id].source_sha256)
	print("MYART SHOP VERIFY END failures=", failures, " checks=", checks)
	if preview and failures == 0:
		lane.automation = false
		loop.paused_for_test = false
		return
	loop.enter("town")
	lane.queue_free()
	await frames()
	quit(0 if failures == 0 else 1)
