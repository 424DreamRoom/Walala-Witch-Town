extends SceneTree
## Verify actual GPU pixels and current world bindings using isolated progress.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Campaign = preload("res://Scenes/Campaign/campaign_state.gd")
const ART := "res://Art/Characters/NPC32/"
const OUT := "res://output/npc32/"
var checks := 0
var failures := 0

func _initialize() -> void:
	Preferences.file_path = OUT + "art_preferences.cfg"
	Saves.directory = OUT + "art_saves"
	Saves.end_session()
	Campaign.pending_intro = false
	run.call_deferred()

func check(caption: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("NPC32 ", caption, ": PASS" if ok else ": FAIL")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func shot(lane, filename: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	check(filename, lane.viewport.get_texture().get_image().save_png(OUT + filename + ".png") == OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "manifest.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(704,544)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for row in range(manifest.assets.size()):
		var entry: Dictionary = manifest.assets[row]
		var sprite := Sprite2D.new()
		sprite.texture = load(ART + entry.png)
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(0,row*32)
		viewport.add_child(sprite)
		check(entry.id + " frame size", sprite.texture.get_size() == Vector2(entry.frames*32,32))
	await frames(4)
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	for row in range(manifest.assets.size()):
		var entry: Dictionary = manifest.assets[row]
		var expected := Image.load_from_file(ART + entry.png)
		expected.convert(Image.FORMAT_RGBA8)
		var actual := rendered.get_region(Rect2i(0,row*32,entry.frames*32,32))
		actual.convert(Image.FORMAT_RGBA8)
		check(entry.id + " all rendered frames match native Aseprite PNG", actual.get_data() == expected.get_data())
	rendered.save_png(OUT + "all-257-frames-rendered.png")
	viewport.queue_free()
	var lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.automation = true
	lane.test_running = true
	lane.set_physics_process(false)
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.set_process(false)
	loop.campaign_controller.set_process(false)
	loop.enter("town")
	for actor in loop.campaign_controller.routines.actors:
		check(actor.resident_id + " world native size and feet", actor.sprite.texture.get_height() == 32 and actor.sprite.hframes == 22 and actor.sprite.offset == Vector2(0,-16) and actor.sprite.scale == Vector2.ONE and actor.sprite.texture.resource_path.begins_with(ART))
		for direction in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
			actor.face(direction)
			actor.elapsed = 0.0
			actor.pose(0.0,true)
			check(actor.resident_id + " four-direction frame " + str(actor.facing), actor.sprite.frame == actor.facing*4)
	var guide = loop.campaign_controller.guide
	check("guide source installed", guide.sprite.texture.resource_path == ART + "guides/yingluo.aseprite" and guide.sprite.hframes == 21 and guide.sprite.frame == 16 and guide.sprite.offset == Vector2(0,-16))
	await shot(lane,"town")
	loop.campaign_controller.show_resident("mori")
	await frames()
	var portrait: TextureRect = loop.hud.modal.find_child("DialoguePortrait",true,false)
	check("dialogue uses full 32x32 idle source", portrait.texture.get_size() == Vector2(32,32))
	await shot(lane,"dialogue")
	loop.hud.close_modal()
	for place in ["blacksmith","store"]:
		loop.enter(place)
		await frames()
		check(place + " staff source and feet", loop.area.staff.sprite.texture.resource_path.begins_with(ART) and loop.area.staff.sprite.offset == Vector2(0,-16))
		await shot(lane,place)
	loop.enter("restaurant")
	await frames()
	loop.state.campaign.restaurant = 2
	for entry in manifest.assets:
		if entry.kind == "guide": continue
		var customer := {"seat":0,"dish":0,"patience":90.0,"variant":0,"status":"waiting","eating_left":3.0}
		if entry.kind == "resident":
			for i in range(Campaign.D.npcs.size()):
				if Campaign.D.npcs[i].id == entry.id: customer.npc = i
		else:
			customer.variant = loop.area.CUSTOMER_PATHS.find(entry.id)
		loop.state.customers = [customer]
		# Guests walk in first; skip the cosmetic arrival so the seated pose is testable.
		loop.area.arrival_clock[0] = 0.0
		loop.area._process(0.0)
		var guest: Sprite2D = loop.area.customer_sprites[0]
		check(entry.id + " restaurant waiting and feet", guest.visible and guest.texture.get_height() == 32 and guest.offset == Vector2(0,-16) and (guest.frame in [16,17] if entry.kind == "resident" else guest.frame == 0))
		for f in range(4):
			customer.status = "eating"
			customer.eating_left = 3.0-f*0.5
			loop.area.arrival_clock[0] = 0.0
			loop.area._process(0.0)
			check(entry.id + " eating frame " + str(f), guest.frame == (18 if entry.kind == "resident" else 2)+f)
	loop.state.customers.clear()
	for i in range(6):
		loop.state.customers.append({"seat":i,"dish":0,"patience":90.0,"variant":i,"status":"eating","eating_left":2.0})
	loop.area._process(0.0)
	for i in range(6):
		loop.area.arrival_clock[i] = 0.0
	loop.area._process(0.0)
	await shot(lane,"restaurant")
	lane.queue_free()
	await frames()
	Saves.end_session()
	print("NPC32 VERIFY END checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
