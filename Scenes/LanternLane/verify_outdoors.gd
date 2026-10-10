extends SceneTree

const OUT := "res://Art/Environment/Hearthwood/Verification/"
var lane
var loop
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--outdoor-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("OUTDOOR TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()

func walk_to(target: Vector2) -> void:
	var count := 0
	while lane.player.position.distance_to(target) > 2.0 and count < 400:
		var difference: Vector2 = target - lane.player.position
		lane.test_direction = Vector2(signf(difference.x), 0) if absf(difference.x) > 1.5 else Vector2(0, signf(difference.y))
		await physics_frame
		count += 1
	lane.test_direction = Vector2.ZERO
	await physics_frame
	check("walk " + str(target), lane.player.position.distance_to(target) < 3.0)

func shot(title: String) -> Image:
	if not capture:
		return null
	await frames()
	RenderingServer.force_draw(false)
	var image: Image = lane.viewport.get_texture().get_image()
	check("capture " + title, image.save_png(OUT + title + ".png") == OK)
	check("capture window " + title, root.get_texture().get_image().save_png(OUT + title + "_window.png") == OK)
	return image

func visible_hero_pixels(image: Image, feet: Vector2i) -> int:
	var source: Image = lane.avatar.texture.get_image().get_region(Rect2i(0, 0, 32, 48))
	var count := 0
	for y in range(48):
		for x in range(32):
			var color := source.get_pixel(x, y)
			if color.a == 1.0 and image.get_pixel(feet.x - 16 + x, feet.y - 48 + y) == color:
				count += 1
	return count

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lane.ART + "town_layout.json"))
	check("town decorations loaded", lane.actors.get_child_count() == layout.buildings.size() + layout.props.size() + 4)
	check("building weather cover", lane.weather.roof_rects.size() == 9)
	check("town Y sorting", lane.actors.y_sort_enabled)
	await shot("outdoor_town_entry")
	if capture:
		lane.player.position = Vector2(300, 364)
		lane.camera.force_update_scroll()
		await shot("outdoor_home_garden")
		lane.player.position = Vector2(568, 364)
		lane.camera.force_update_scroll()
		await shot("outdoor_pond_street")
		lane.player.position = Vector2(808, 684)
		lane.camera.force_update_scroll()
		await shot("outdoor_south_street")
	lane.player.position = lane.SPAWN
	await walk_to(loop.FIELD_GATE)
	await key(KEY_E)
	check("field entrance works", loop.location == "field")
	if loop.location != "field":
		quit(1)
		return
	check("field Y sorting shares player parent", loop.area.y_sort_enabled and lane.player.get_parent() == loop.area)
	var field_layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lane.ART + "field_layout.json"))
	var solid_count := 4
	for entry in field_layout.props:
		if entry.get("solid", true):
			solid_count += 1
	check("field solid footprints", loop.area.solids.size() == solid_count)
	check("gather labels stay above foliage", loop.area.field_labels.z_index > 0)
	await shot("outdoor_field_entry")
	await walk_to(Vector2(60, 115))
	for row in range(3):
		for column in range(3):
			var index := row * 3 + (column if row % 2 == 0 else 2 - column)
			await walk_to(loop.area.points[index])
			await key(KEY_E)
			check("gather reachable " + str(index), loop.state.nodes[index] == 1)
		if row == 0:
			await shot("outdoor_field_gathering")
	check("all nine ingredients gathered", loop.state.raw == [3, 3, 3])
	var end: Vector2 = await lane._walk(Vector2(177, 232), Vector2.UP, 35)
	check("fallen log blocks feet", end.y >= 211.8 and end.y < 214)
	if capture:
		lane.set_physics_process(false)
		lane.facing = 0
		lane._animate(false, false, 0.0)
		lane.avatar.position = lane.WITCH_FOOT_OFFSET
		lane.player.position = Vector2(422, 190)
		var behind: Image = await shot("outdoor_field_behind_tree")
		var behind_count := visible_hero_pixels(behind, Vector2i(422, 190))
		lane.player.position = Vector2(422, 235)
		var front: Image = await shot("outdoor_field_front_tree")
		var front_count := visible_hero_pixels(front, Vector2i(422, 235))
		var source: Image = lane.avatar.texture.get_image().get_region(Rect2i(0, 0, 32, 48))
		var opaque_count := 0
		for y in range(48):
			for x in range(32):
				if source.get_pixel(x, y).a == 1.0:
					opaque_count += 1
		check("tree covers character from behind", behind_count < opaque_count / 2)
		check("character covers tree from front", front_count == opaque_count)
		lane.set_physics_process(true)
	lane.player.position = Vector2(60, 280)
	await key(KEY_E)
	check("field exit works", loop.location == "town")
	lane.queue_free()
	await frames()
	print("OUTDOOR VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
