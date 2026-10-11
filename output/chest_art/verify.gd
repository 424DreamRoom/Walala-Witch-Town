extends SceneTree
const Catalog = preload("res://Scenes/Building/furniture_catalog.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://output/chest_art/"
var failures := 0
var checks := 0
var lane
var loop
var capture := false

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("CHEST ART ", title, ": ", "PASS" if ok else "FAIL")

func frames(count := 6) -> void:
	for index in range(count): await process_frame

func shot(title: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	check("capture " + title, pixels.save_png(OUT + title + "_native.png") == OK)
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture scaled " + title, pixels.save_png(OUT + title + ".png") == OK)

func sprite_for(id: int) -> AnimatedSprite2D:
	return loop.area.get_node("Furniture" + str(id)).get_child(0)

func run() -> void:
	root.get_node("Localization").set_language("zh_CN", false)
	check("isolated slot", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.audio.set_music_muted(true)
	loop.audio.set_effects_muted(true)
	loop.state.furniture = Catalog.legacy_data()
	loop.state.furniture.stock.chest = 2
	check("place first real chest", loop.state.place_furniture("chest", Vector2(400, 384), Vector2(320, 405)))
	var first: int = loop.state.furniture.next_id - 1
	check("place second real chest", loop.state.place_furniture("chest", Vector2(256, 384), Vector2(320, 405)))
	var second: int = loop.state.furniture.next_id - 1
	loop.enter("home")
	lane.player.position = Vector2(400, 408)
	await frames()
	var sprite := sprite_for(first)
	var other := sprite_for(second)
	check("original canvas and foot anchor", sprite.sprite_frames.get_frame_texture("closed", 0).get_size() == Vector2(48, 36) and sprite.position == Vector2(0, -18))
	check("collision unchanged", Catalog.footprint("chest", Vector2(400, 384)) in lane.solid_rects)
	check("closed sprite and shared preview", sprite.animation == "closed" and sprite.sprite_frames.get_frame_texture("closed", 0) == Catalog.texture("chest"))
	await shot("room_closed")
	loop.hud.open_chest(first)
	check("storage pauses world", loop.hud.mode == "chest" and paused)
	await create_timer(0.65, true).timeout
	check("animation completes while paused", sprite.animation == "open" and not sprite.is_playing())
	check("other chest stays closed", other.animation == "closed" and not other.opened)
	Items.change(loop.state, {"wood": 9})
	check("storage transfer still works", loop.state.transfer_chest(first, "wood", 5, true) == 5 and loop.state.furniture_by_id(first).items.wood == 5)
	await shot("storage_open")
	loop.hud.modal.hide()
	await shot("room_open")
	loop.hud.modal.show()
	loop.hud.close_modal()
	await create_timer(0.65, true).timeout
	check("close animation settles", sprite.animation == "closed" and not sprite.is_playing() and not paused)
	lane.player.position = Vector2(256, 408)
	await frames()
	loop.hud.open_chest(second)
	await create_timer(0.65, true).timeout
	check("second chest opens independently", other.animation == "open" and sprite.animation == "closed")
	loop.hud.close_modal()
	await create_timer(0.65, true).timeout
	loop.hud.open_map()
	loop.hud.map_view.show_region("home", false)
	await frames()
	check("map shares original chest texture", loop.hud.map_view.canvas.texture_for("home_chest") == Catalog.texture("chest"))
	await shot("map_chests")
	loop.hud.close_modal()
	check("save preserves contents", loop.save_progress().ok and Saves.read_slot(1).ok)
	loop.enter("farm")
	loop.enter("home")
	await frames()
	check("scene reentry restores closed chest and contents", sprite_for(first).animation == "closed" and loop.state.furniture_by_id(first).items.wood == 5)
	lane.queue_free()
	await frames()
	Saves.end_session()
	print("CHEST ART END checks=", checks, " failures=", failures)
	quit(failures)
