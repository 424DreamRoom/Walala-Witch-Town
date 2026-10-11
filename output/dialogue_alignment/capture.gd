extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/dialogue_alignment/"
var lane

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = OUT + "saves_%d" % OS.get_process_id()
	Saves.end_session()
	run.call_deferred()

func frames() -> void:
	for i in range(5): await process_frame

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	lane.player.position = loop.campaign_controller.guide.position + Vector2(0,36)
	lane.camera.position = lane.player.position
	lane.camera.reset_smoothing()
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		loop.campaign_controller.show_guide()
		loop.hud.dialogue_text.visible_characters = -1
		loop.hud._line_complete()
		await frames()
		await RenderingServer.frame_post_draw
		var pixels: Image = lane.viewport.get_texture().get_image()
		pixels.resize(1920,1080,Image.INTERPOLATE_NEAREST)
		pixels.save_png(OUT + "aligned_" + locale + ".png")
		print("ALIGNMENT ", locale, " CHOICES ", loop.hud.choices_root.get_global_rect())
		loop.hud.close_modal()
	lane.queue_free()
	await frames()
	quit()
