extends SceneTree

const OUT := "res://Art/Environment/Hearthwood/Verification/Ambient/"
var lane
var loop
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--ambient-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("AMBIENT TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func active(kind: String = "") -> Array:
	var found := []
	for node in get_nodes_in_group("ambient_props"):
		if node.enabled and (kind.is_empty() or node.kind == kind):
			found.append(node)
	return found

func current_pixels(animation) -> Image:
	var index: int = animation.sprite.frame
	var cell := Vector2i(animation.spec.cell[0], animation.spec.cell[1])
	return animation.atlas.get_image().get_region(Rect2i(Vector2i(index % 12 * cell.x, floori(float(index) / 12) * cell.y), cell))

func visible_equal(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var first := a.get_pixel(x, y)
			var second := b.get_pixel(x, y)
			# Alpha-border import can color fully transparent texels across atlas cells.
			if first.a != second.a or (first.a > 0.0 and first != second):
				return false
	return true

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()

func shot(name: String) -> Image:
	if not capture:
		return null
	await frames()
	RenderingServer.force_draw(false)
	var image: Image = lane.viewport.get_texture().get_image()
	check("capture " + name, image.save_png(OUT + name + ".png") == OK)
	if name in ["town", "home", "field_00"]:
		var window: Image = root.get_texture().get_image()
		check("window capture " + name, window.save_png(OUT + name + "_window.png") == OK)
		var enlarged := image.duplicate() as Image
		enlarged.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		enlarged.convert(window.get_format())
		check("integer window scaling " + name, enlarged.get_data() == window.get_data())
	return image

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lane.ART + "town_layout.json"))
	var expected := 0
	for entry in layout.props:
		if AmbientAnimation.registry.assets.has(entry.kind):
			expected += 1
	check("all town animated kinds attached", active().size() == expected)
	check("town trees animate", active("town_tree").size() == 9)
	check("all lamps animate", active("outdoor_lamp").size() == 6)
	var tree = active("town_tree")[0]
	var anchor: Vector2 = tree.sprite.get_parent().position
	var sprite_position: Vector2 = tree.sprite.position
	var before: int = tree.sprite.frame
	await create_timer(0.7).timeout
	check("tree advances in real time", tree.sprite.frame != before)
	check("tree body and feet stay fixed", tree.sprite.get_parent().position == anchor and tree.sprite.position == sprite_position)
	check("tree never rotates or scales", tree.sprite.rotation == 0.0 and tree.sprite.scale == Vector2.ONE)
	check("tree instances use different phases", absf(tree.elapsed - active("town_tree")[1].elapsed) > 0.01)
	for node in active():
		if node.spec.motion == "wind":
			var bottom: int = node.spec.hinge
			var size := Vector2i(node.spec.source[0], node.spec.source[1])
			var tile := current_pixels(node).get_region(Rect2i(4, bottom, size.x, size.y - bottom))
			var source: Image = node.original.get_image().get_region(Rect2i(0, bottom, size.x, size.y - bottom))
			check("fixed root/pot " + node.kind + str(node.sprite.get_parent().position), visible_equal(tile, source))
	lane.weather.set_weather("rain")
	await frames()
	check("rain selects stronger foliage bank", tree.sprite.frame >= 12)
	lane.weather.set_weather("snow")
	await frames()
	check("snow selects stronger foliage bank", tree.sprite.frame >= 12)
	lane.weather.clear_weather()
	await frames()
	check("clear selects gentle foliage bank", tree.sprite.frame < 12)
	lane.player.position = Vector2(568, 364)
	lane.camera.force_update_scroll()
	await shot("town")
	loop.enter("field")
	await frames()
	lane.set_physics_process(false)
	check("field tree animations", active("outdoor_birch").size() == 7 and active("outdoor_pine").size() == 7)
	check("both field ponds animate", active("outdoor_pond").size() == 2)
	check("field ferns animate", active("outdoor_fern").size() == 6)
	check("detached town stops processing", not lane.world.is_inside_tree() and active("town_tree").is_empty())
	var pond = active("outdoor_pond")[0]
	before = pond.sprite.frame
	await create_timer(0.3).timeout
	check("water advances in real time", pond.sprite.frame != before)
	lane.player.position = Vector2(300, 266)
	lane.camera.force_update_scroll()
	var first: Image
	var changed := false
	if capture:
		for i in range(24):
			var image: Image = await shot("field_%02d" % i)
			if i == 0:
				first = image
			else:
				changed = changed or image.get_region(Rect2i(385, 95, 75, 95)).get_data() != first.get_region(Rect2i(385, 95, 75, 95)).get_data()
			await create_timer(0.2).timeout
		check("rendered canopy pixels move", changed)
	var resource
	for node in loop.area.resource_nodes:
		if node.resource_id == "field_tree_7":
			resource = node
	lane.player.position = resource.anchor
	for hit in range(3):
		await key(KEY_F)
		await create_timer(0.8).timeout
		check("harvest impact " + str(hit), loop.state.resource_left(resource.resource_id) == 2 - hit)
		if hit < 2:
			check("wind and hit shake coexist " + str(hit), resource.ambient.enabled and resource.sprite.texture == resource.ambient.atlas)
	check("felled tree stops wind", not resource.ambient.enabled and resource.sprite.hframes == 1 and resource.sprite.vframes == 1 and resource.sprite.texture == resource.depleted)
	check("felling still awards wood once", loop.state.resources.wood == 3)
	check("stump feet match static art", resource.sprite.position == Vector2(0, -9))
	loop.enter("home")
	await frames()
	check("home has candle animation", active("home_desk").size() == 1)
	check("outdoor objects detached indoors", active().size() == 1)
	var candle = active("home_desk")[0]
	before = candle.sprite.frame
	await create_timer(0.25).timeout
	check("candle flickers in real time", candle.sprite.frame != before)
	check("desk and candle anchor stay fixed", candle.sprite.position == Vector2(0, -36) and candle.sprite.get_parent().position == Vector2(499, 345))
	await shot("home")
	loop.enter("town")
	await frames()
	check("town resumes animation on return", active().size() == expected)
	lane.queue_free()
	await frames()
	print("AMBIENT VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
