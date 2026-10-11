extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://Scenes/Gameplay/Verification/Thoughts/"
var failures := 0
var lane
var loop
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("THOUGHT TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 4) -> void:
	for index in range(count): await process_frame

func shot(title: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + title, pixels.save_png(OUT + title + ".png") == OK)

func run() -> void:
	Preferences.file_path = "user://thoughts_%d.cfg" % OS.get_process_id()
	Saves.directory = "user://thoughts_%d" % OS.get_process_id()
	root.get_node("Localization").apply_saved_language()
	root.get_node("InputBindings").apply_saved_bindings()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	check("isolated new game starts", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(6)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("farm")
	lane.player.position = loop.area.stations.refill
	lane.camera.force_update_scroll()
	loop.state.farm.water = 0
	loop.area.interact()
	await frames()
	check("refill still fills shared watering can", loop.state.farm.water == loop.state.water_capacity())
	check("refill reads as a short character thought", loop.notice.text == "水装满啦。" and loop.notice.visible)
	check("feedback uses a compact bubble", loop.thought_bubble.visible and loop.thought_bubble.size.x <= 184 and loop.backgrounds[2] == loop.thought_bubble)
	var head: Vector2 = lane.player.get_global_transform_with_canvas().origin - Vector2(0, lane.CHARACTER_SIZE.y)
	check("bubble sits above witch", loop.thought_bubble.get_rect().end.y < head.y)
	check("bubble leaves movement input alone", loop.thought_bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE and loop.notice.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await shot("refill_zh_CN")
	var old_x: float = loop.thought_bubble.position.x
	lane.player.position.x += 30
	lane.camera.force_update_scroll()
	await frames()
	check("bubble follows player movement", loop.thought_bubble.position.x > old_x)
	loop.hud.open_bag()
	await frames()
	check("pause hides the thought behind modals", paused and not loop.thought_bubble.visible)
	loop.hud.close_modal()
	await frames()
	check("closing modal restores an unexpired thought", not paused and loop.thought_bubble.visible)
	for locale in ["en", "ja", "zh_TW", "zh_CN"]:
		root.get_node("Localization").set_language(locale, false)
		loop._show_feedback()
		await frames()
		check("live thought translation " + locale, loop.notice.text == String(TranslationServer.translate("水装满啦。")))
		await shot("refill_" + locale)
	loop.state.message = "The little garden feels peaceful today, and the herbs are growing well."
	loop._show_feedback()
	await frames()
	check("long thoughts wrap inside compact bubble", loop.thought_bubble.size.x <= 184 and loop.notice.size.y > 24)
	check("wrapped text remains inside bubble", Rect2(Vector2.ZERO, loop.thought_bubble.size).encloses(loop.notice.get_rect()))
	await shot("wrapped_thought")
	lane.player.position = Vector2(800, 30)
	lane.camera.force_update_scroll()
	await frames()
	var rect: Rect2 = loop.thought_bubble.get_rect()
	check("edge position stays below clock and above hotbar", rect.position.y >= 68 and rect.end.y <= 304 and rect.position.x >= 8 and rect.end.x <= 632)
	await shot("edge_thought")
	loop.message_left = 0.15
	await frames()
	check("thought fades before expiry", loop.thought_bubble.modulate.a < 1.0)
	await create_timer(0.25).timeout
	check("thought disappears automatically", not loop.thought_bubble.visible and not loop.notice.visible)
	loop.state.message = "储水已满。"
	loop._show_feedback()
	await frames()
	check("new thought replaces expired one", loop.notice.text == "已经满满的啦。" and loop.thought_bubble.visible and is_equal_approx(loop.thought_bubble.modulate.a, 1.0))
	check("short thought shrinks after long thought", loop.thought_bubble.size.y < 40 and Rect2(Vector2.ZERO, loop.thought_bubble.size).encloses(loop.notice.get_rect()))
	loop.state.phase = "result"
	loop._refresh()
	check("settlement hides character thought", not loop.thought_bubble.visible)
	Saves.end_session()
	lane.queue_free()
	await frames(6)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("THOUGHT VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
