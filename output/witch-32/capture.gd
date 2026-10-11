extends SceneTree

const OUT := "res://output/witch-32/"
var lane
var failures := 0
var checked_frames := 0

func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = OUT + "profile/preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = OUT + "profile/saves"
	preload("res://Scenes/Save/save_store.gd").end_session()
	run.call_deferred()

func frames(count := 3) -> void:
	for i in range(count): await process_frame

func check(label: String, ok: bool) -> void:
	if not ok: failures += 1
	print("WITCH 32 TEST ", label, ": ", "PASS" if ok else "FAIL")

func shot(label: String, sprite: Sprite2D, save: bool) -> void:
	await frames(2)
	RenderingServer.force_draw(false)
	var image: Image = lane.viewport.get_texture().get_image()
	var source: Image = sprite.texture.get_image().get_region(Rect2i(sprite.frame % 5 * 32, sprite.frame / 5 * 32, 32, 32))
	var corner := Vector2i((sprite.get_global_transform_with_canvas() * Vector2(-16, -16)).round())
	var opaque := 0
	var matching := 0
	for y in range(32):
		for x in range(32):
			if source.get_pixel(x, y).a == 1.0:
				opaque += 1
				if source.get_pixel(x, y) == image.get_pixel(corner.x + x, corner.y + y): matching += 1
	check(label + " exact pixels " + str(matching) + "/" + str(opaque), matching == opaque and opaque > 0)
	checked_frames += 1
	if save:
		check(label + " screenshot", image.save_png(OUT + label + ".png") == OK)
		image.get_region(Rect2i(corner - Vector2i(8, 8), Vector2i(48, 48))).save_png(OUT + label + "-crop.png")

func player_portrait(node: Node) -> AtlasTexture:
	if node is TextureRect and node.texture is AtlasTexture:
		return node.texture
	for child in node.get_children():
		var found := player_portrait(child)
		if found != null: return found
	return null

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.set_process(false)
	lane.set_physics_process(false)
	lane.player.position = Vector2(620, 500)
	lane.avatar.position = lane.WITCH_FOOT_OFFSET
	lane.weather.clear_weather()
	await frames(4)
	check("native main canvas", lane.avatar.get_rect().size == Vector2(32, 32))
	check("main foot anchor", lane.avatar.position == Vector2(0, -16))
	for index in range(20):
		lane.avatar.frame = index
		await shot("main-" + str(index), lane.avatar, index % 5 == 0)
	lane.avatar.visible = false
	var action := Sprite2D.new()
	action.texture = load("res://Art/Character/Storybook/WalalaTools32/witch-tools-32.png")
	action.hframes = 5
	action.vframes = 12
	action.position = lane.WITCH_FOOT_OFFSET
	lane.player.add_child(action)
	check("native action canvas", action.get_rect().size == Vector2(32, 32))
	check("action foot anchor", action.position == Vector2(0, -16))
	for index in range(60):
		action.frame = index
		await shot("tool-" + str(index), action, index in [10, 26, 38, 47])
	var menu = preload("res://Scenes/MainMenu/menu_backdrop.gd").new()
	menu.visible = false
	root.add_child(menu)
	await frames()
	menu.set_process(false)
	menu.elapsed = 0.0
	menu._update_witch()
	check("menu uses 32x32 player", menu.witch.texture.resource_path == lane.WITCH_TEXTURE and menu.witch.get_rect().size == Vector2(32, 32))
	check("menu feet stay on ground", menu.witch.position == Vector2(463, 312))
	var audio = load("res://Sounds/Walala/audio_manager.gd").new()
	root.add_child(audio)
	var naming = preload("res://Scenes/Campaign/player_naming.gd").new()
	naming.audio = audio
	naming.visible = false
	root.add_child(naming)
	await frames()
	var portrait := player_portrait(naming)
	check("naming portrait shows whole 32x32 player", portrait != null and portrait.atlas.resource_path == lane.WITCH_TEXTURE and portrait.region == Rect2(0, 0, 32, 32))
	var report := {"status": "PASS" if failures == 0 else "FAIL", "rendered_frames": checked_frames, "exact_source_pixels": failures == 0, "failures": failures, "isolated_profile": true, "renderer": "gl_compatibility"}
	var file := FileAccess.open("res://Art/Character/Storybook/WalalaWitch32/runtime-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	portrait = null
	naming.queue_free()
	menu.queue_free()
	audio.queue_free()
	lane.queue_free()
	await frames(5)
	print("WITCH 32 RENDER END frames=", checked_frames, " failures=", failures)
	quit(0 if failures == 0 else 1)
