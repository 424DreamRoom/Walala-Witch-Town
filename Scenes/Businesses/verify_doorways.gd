extends SceneTree
## Isolated pixel-preservation, real movement and rendered doorway checks.
const OUT := "res://output/shop_doorway_fix/"
const ART := "res://Art/Environment/Hearthwood/"
const Ground = preload("res://Art/Source/tile_ground.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
var lane
var loop
var checks := 0
var failures := 0
var capture := "--capture" in OS.get_cmdline_user_args()
var pictures: Array[Image] = []

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	preload("res://Scenes/Campaign/campaign_state.gd").pending_intro = false
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("DOORWAY ", title, ": ", "PASS" if passed else "FAIL")

func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func authored_picture(tiles: TileMapLayer) -> Image:
	# Independent reference renderer, including the authored tile transforms.
	var result := Image.create(640, 480, false, Image.FORMAT_RGBA8)
	for cell in tiles.get_used_cells():
		var atlas: TileSetAtlasSource = tiles.tile_set.get_source(tiles.get_cell_source_id(cell))
		var tile := atlas.texture.get_image().get_region(atlas.get_tile_texture_region(tiles.get_cell_atlas_coords(cell)))
		var transform := tiles.get_cell_alternative_tile(cell)
		if transform & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
			tile.rotate_90(CLOCKWISE)
			tile.flip_x()
		if transform & TileSetAtlasSource.TRANSFORM_FLIP_H: tile.flip_x()
		if transform & TileSetAtlasSource.TRANSFORM_FLIP_V: tile.flip_y()
		result.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), cell * tiles.tile_set.tile_size)
	return result

func verify_pixels(kind: String) -> void:
	var scene := ART + kind + "_compact_ground.tilemap.tscn"
	var original := (load(scene) as PackedScene).instantiate() as TileMapLayer
	var before := authored_picture(original)
	var count := original.tile_set.get_source_count()
	var fixed := Ground.preview(ART + kind + "_ground.aseprite", scene).get_image()
	var background := before.get_pixel(0, 0)
	var opening := Rect2i(262, 408, 116, 12)
	var changed := 0
	var only_gap := true
	var copied_steps := true
	var connected := true
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			var at := Vector2i(x, y)
			var old := before.get_pixelv(at)
			var now := fixed.get_pixelv(at)
			if old != now:
				changed += 1
				only_gap = only_gap and opening.has_point(at) and old == background
				copied_steps = copied_steps and now == before.get_pixel(x, y + 12)
			if opening.has_point(at) and now == background: connected = false
	check(kind + " fills the existing gap", changed > 0 and connected)
	check(kind + " preserves every non-gap pixel", only_gap)
	check(kind + " reuses the original stair pixels", copied_steps)
	var again := (load(scene) as PackedScene).instantiate() as TileMapLayer
	check(kind + " leaves the shared source tileset untouched", count == original.tile_set.get_source_count() and count == again.tile_set.get_source_count())
	original.free()
	again.free()
	# Non-compact maps also cover the shared preview renderer regression.
	var plain := (load(ART + kind + "_ground.tilemap.tscn") as PackedScene).instantiate() as TileMapLayer
	check(kind + " original preview unchanged", authored_picture(plain).get_data() == Ground.preview(ART + kind + "_ground.aseprite").get_image().get_data())
	plain.free()

func walk(start: Vector2, direction: Vector2, ticks: int = 30) -> Vector2:
	lane.test_direction = Vector2.ZERO
	lane.player.position = start
	lane.player.force_update_transform()
	lane.set_physics_process(true)
	await frames()
	lane.test_direction = direction
	for i in range(ticks): await physics_frame
	lane.test_direction = Vector2.ZERO
	await frames()
	return lane.player.position

func shot(kind: String, stage: int, feet_y: float) -> void:
	if not capture: return
	lane.set_physics_process(false)
	lane.player.position = Vector2(320, feet_y)
	await frames()
	lane.camera.force_update_scroll()
	RenderingServer.force_draw(false)
	var picture: Image = lane.viewport.get_texture().get_image()
	check(kind + " capture " + str(stage), picture.save_png(OUT + kind + "_" + str(stage) + ".png") == OK)
	pictures.append(picture)
	lane.set_physics_process(true)

func verify_actor_pixels(kind: String) -> void:
	if not capture: return
	lane.set_physics_process(false)
	loop.set_process(false)
	var lighting: Color = loop.day_night.modulation.color
	loop.day_night.modulation.color = Color.WHITE
	var visibility := {}
	for child in lane.player.get_children():
		if child is CanvasItem:
			visibility[child] = child.visible
			child.hide()
	var probe := Polygon2D.new()
	probe.polygon = PackedVector2Array([Vector2(-6, -20), Vector2(6, -20), Vector2(6, -2), Vector2(-6, -2)])
	probe.color = Color.MAGENTA
	lane.player.add_child(probe)
	for feet_y in [410.0, 417.0, 423.0, 427.0, 431.0, 440.0]:
		lane.player.position = Vector2(320, feet_y)
		await frames()
		lane.camera.force_update_scroll()
		RenderingServer.force_draw(false)
		var picture: Image = lane.viewport.get_texture().get_image()
		var visible := true
		for height in [6.0, 10.0, 14.0]:
			var screen: Vector2 = lane.viewport.get_canvas_transform() * (lane.player.position + Vector2(0.5, -height + 0.5))
			visible = visible and picture.get_pixelv(Vector2i(screen.floor())).is_equal_approx(Color.MAGENTA)
		check(kind + " actor stays above doorway floor at " + str(feet_y), visible)
	probe.free()
	for child in visibility: child.visible = visibility[child]
	loop.day_night.modulation.color = lighting
	loop.set_process(true)
	lane.set_physics_process(true)

func run() -> void:
	for kind in ["store", "blacksmith"]: verify_pixels(kind)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	lane.test_running = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.campaign_controller.set_process(false)
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	for kind in ["store", "blacksmith", "furniture_store"]:
		loop.enter(kind)
		await frames()
		check(kind + " walks from room onto steps", await Navigation.walk(lane, Vector2(320, 448)))
		check(kind + " walks back into room", await Navigation.walk(lane, loop.area.spawn))
		var left := await walk(Vector2(280, 440), Vector2.LEFT)
		check(kind + " left stair rail blocks feet", left.x >= 266.8 and left.x < 267.2)
		var right := await walk(Vector2(360, 440), Vector2.RIGHT)
		check(kind + " right stair rail blocks feet", right.x <= 373.2 and right.x > 372.8)
		var bottom := await walk(Vector2(320, 450), Vector2.DOWN)
		check(kind + " bottom stair edge blocks feet", bottom.y <= 460.2 and bottom.y > 459.7)
		var sill := await walk(Vector2(240, 400), Vector2.DOWN)
		check(kind + " wall beside doorway blocks feet", sill.y <= 408.2 and sill.y > 407.7)
		await verify_actor_pixels(kind)
		for i in range(3): await shot(kind, i, [410.0, 427.0, 440.0][i])
		lane.player.position = loop.area.spawn
		await frames()
		check(kind + " real walk to exit", await Navigation.walk(lane, loop.area.stations.exit))
		loop.interact()
		await frames()
		if root.get_node("SceneTransition").active: await root.get_node("SceneTransition").finished
		await frames()
		check(kind + " returns to town", loop.location == "town")
	if capture:
		var overview := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
		for i in range(pictures.size()): overview.blit_rect(pictures[i], Rect2i(0, 0, 640, 360), Vector2i((i % 3) * 640, (i / 3) * 360))
		check("saves doorway overview", overview.save_png(OUT + "overview.png") == OK)
	lane.queue_free()
	await frames()
	print("DOORWAY END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
