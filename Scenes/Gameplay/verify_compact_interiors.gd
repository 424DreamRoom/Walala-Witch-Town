extends SceneTree
## Exercise real physics, full restaurant occupancy and old saves in isolation.
const OUT := "res://output/compact_interiors/"
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
var lane
var loop
var failures := 0
var checks := 0
var capture := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = OUT + "preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = OUT + "saves_%d" % OS.get_process_id()
	Saves.end_session()
	preload("res://Scenes/Campaign/campaign_state.gd").pending_intro = false
	capture = "--compact-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("COMPACT TEST ", title, ": ", "PASS" if passed else "FAIL")

func frames() -> void:
	for i in range(3):
		await physics_frame
		await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()
	if root.get_node("SceneTransition").active:
		await root.get_node("SceneTransition").finished

func shot(title: String) -> void:
	if not capture: return
	loop.state.message = ""
	loop.message_left = 0.0
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)

func restore_position(kind: String, point: Vector2) -> void:
	loop._restore_world({"location": kind, "position": [point.x, point.y], "town_position": [408, 364], "farm_position": [416, 448], "weather": "clear", "facing": 0})
	await frames()

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	loop.enter("home")
	await shot("home_reference")
	for kind in ["store", "blacksmith", "furniture_store"]:
		loop.enter(kind)
		await frames()
		check(kind + " compact floor", loop.area.walkable_regions[0].size == Vector2(328, 202))
		check(kind + " real walk to service", await Navigation.walk(lane, loop.area.stations.service))
		await key(KEY_E)
		check(kind + " service opens", loop.hud.mode == "housing" if kind == "furniture_store" else loop.area.service_panel.visible)
		if kind == "furniture_store": loop.hud.close_modal()
		else: await key(KEY_ESCAPE)
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Environment/Hearthwood/" + kind + "_layout.json"))
		for item in layout.furniture:
			check(kind + " fixture accessible " + item.kind, await Navigation.walk(lane, Vector2(item.x, item.y + 14)))
		var staff_feet := preload("res://Scenes/Gameplay/actor_collision.gd").footprint(loop.area.staff_position)
		check(kind + " staff clear of fixtures", not loop.area.solids.slice(0, -1).any(func(rect): return rect.intersects(staff_feet)))
		lane.player.position = loop.area.spawn
		await shot(kind)
		await restore_position(kind, Vector2(550, 380))
		check(kind + " old outside save recovers", lane.player.position == loop.area.spawn)
		await restore_position(kind, Vector2(layout.furniture[0].x, layout.furniture[0].y - 8))
		check(kind + " old blocked save recovers", lane.player.position == loop.area.spawn)
		var safe: Vector2 = loop.area.stations.service
		await restore_position(kind, safe)
		check(kind + " valid save stays", lane.player.position == safe)
		check(kind + " real walk to exit", await Navigation.walk(lane, loop.area.stations.exit))
		await key(KEY_E)
		check(kind + " exits to town", loop.location == "town")
	loop.state.campaign.restaurant = 4
	loop.enter("restaurant")
	await frames()
	check("restaurant compact floor", loop.area.walkable_regions[0].size == Vector2(328, 198))
	check("restaurant prep accessible", await Navigation.walk(lane, loop.area.stations.prep))
	check("restaurant kitchen accessible", await Navigation.walk(lane, loop.area.stations.kitchen))
	loop.state.phase = "night"
	loop.last_phase = "night"
	loop.state.menu[0] = true
	loop.state.customers.clear()
	for i in range(6):
		loop.state.customers.append({"seat": i, "dish": 0, "patience": 25.0, "status": "waiting", "variant": i})
	await frames()
	check("six tables and customers retained", loop.area.table_count == 6 and loop.area.customer_sprites.all(func(guest): return guest.visible))
	for seat in loop.area.seats:
		lane.solid_rects.append(preload("res://Scenes/Gameplay/actor_collision.gd").footprint(seat))
	for i in range(6):
		var approach: Vector2 = loop.area.seats[i] + Vector2(-20, 8)
		check("full restaurant delivery route " + str(i), await Navigation.walk(lane, approach) and loop.near(loop.area.seats[i]))
		loop.state.held = 0
		await key(KEY_E)
		check("full restaurant serves " + str(i), loop.state.customer_at(i).status == "eating")
	lane.player.position = loop.area.spawn
	await shot("restaurant_full")
	loop.state.customers.clear()
	await restore_position("restaurant", Vector2(400, 280))
	check("restaurant old outside save recovers", lane.player.position == loop.area.spawn)
	check("restaurant real walk to exit", await Navigation.walk(lane, loop.area.stations.exit))
	await key(KEY_E)
	check("restaurant exits to town", loop.location == "town")
	lane.queue_free()
	await frames()
	print("COMPACT VERIFY END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
