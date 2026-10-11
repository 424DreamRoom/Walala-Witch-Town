extends SceneTree

const OUT := "res://output/witch-v2/"
var lane
var failures := 0

func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = OUT + "profile/preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = OUT + "profile/saves"
	preload("res://Scenes/Save/save_store.gd").end_session()
	run.call_deferred()

func frames(count := 3) -> void:
	for i in range(count): await process_frame

func shot(label: String, sprite: Sprite2D) -> void:
	await frames()
	RenderingServer.force_draw(false)
	var image: Image = lane.viewport.get_texture().get_image()
	image.save_png(OUT + label + ".png")
	var source: Image = sprite.texture.get_image().get_region(Rect2i(sprite.frame % 5 * 32, sprite.frame / 5 * 48, 32, 48))
	var corner := Vector2i((sprite.get_global_transform_with_canvas() * Vector2(-16, -24)).round())
	var opaque := 0
	var matching := 0
	for y in range(48):
		for x in range(32):
			if source.get_pixel(x, y).a == 1.0:
				opaque += 1
				if source.get_pixel(x, y) == image.get_pixel(corner.x + x, corner.y + y): matching += 1
	var ok := matching > opaque * 0.95
	if not ok: failures += 1
	print("WITCH V2 RENDER ", label, " pixels=", matching, "/", opaque, " ", "PASS" if ok else "FAIL")
	image.get_region(Rect2i(corner - Vector2i(8, 8), Vector2i(48, 64))).save_png(OUT + label + "-crop.png")

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.set_process(false)
	lane.set_physics_process(false)
	lane.player.position = Vector2(620, 500)
	lane.weather.clear_weather()
	await frames(4)
	for row in range(4):
		lane.avatar.frame = row * 5
		await shot(["down", "up", "right", "left"][row], lane.avatar)
	for column in range(1, 5):
		lane.avatar.frame = column
		await shot("walk-" + str(column), lane.avatar)
	lane.avatar.visible = false
	var action := Sprite2D.new()
	action.texture = load("res://Art/Character/Storybook/WalalaToolsV2/witch-tools-v2.png")
	action.hframes = 5
	action.vframes = 12
	action.position = lane.WITCH_FOOT_OFFSET
	lane.player.add_child(action)
	for index in [10, 26, 38, 47]:
		action.frame = index
		await shot("tool-" + str(index), action)
	var menu = preload("res://Scenes/MainMenu/menu_backdrop.gd").new()
	menu.visible = false
	root.add_child(menu)
	await frames()
	if menu.witch.texture.resource_path != lane.WITCH_TEXTURE: failures += 1
	menu.queue_free()
	print("WITCH V2 RENDER END failures=", failures)
	quit(0 if failures == 0 else 1)
