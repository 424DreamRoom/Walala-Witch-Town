extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const Guide = preload("res://Scenes/Campaign/guide_profile.gd")
const Onboarding = preload("res://Scenes/Campaign/onboarding.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const I18n = preload("res://Localization/localized_text.gd")
const OUT := "res://output/guide_npc/"
var failures := 0
var checks := 0
var capture := false
var lane
var loop

func _initialize() -> void:
	var profile := OUT + str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile + "/preferences.cfg"
	Saves.directory = profile + "/saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(caption: String, result: bool) -> void:
	checks += 1
	if not result: failures += 1
	print("GUIDE ", caption, ": PASS" if result else ": FAIL")

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func shot(filename: String) -> void:
	if not capture: return
	await frames(4)
	await RenderingServer.frame_post_draw
	check("capture " + filename, lane.viewport.get_texture().get_image().save_png(OUT + filename + ".png") == OK)

func finish_lines() -> void:
	while loop.hud.line_index + 1 < loop.hud.lines.size():
		loop.hud.dialogue_text.visible_characters = -1
		loop.hud.advance_dialogue()
	loop.hud.dialogue_text.visible_characters = -1
	loop.hud._line_complete()

func run() -> void:
	var old := State.new().to_save_data()
	old.campaign.erase("guide_met")
	old.campaign.introduced = true
	old.campaign.player_name = "Aster"
	var restored := State.normalize_save_data(old)
	check("named old save avoids new popup", not restored.is_empty() and restored.campaign.guide_met)
	old.campaign.player_name = ""
	check("unfinished old opening retains welcome", not State.normalize_save_data(old).campaign.guide_met)
	old.campaign.guide_met = "yes"
	check("invalid welcome state rejected", State.normalize_save_data(old).is_empty())
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(8)
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	var controller = loop.campaign_controller
	var guide = controller.guide
	check("guide is separate from ten residents", controller.actors.size() == 10 and guide.get_parent() == lane.actors and guide.has_node("FeetCollision"))
	check("guide uses native 32x32 frames on the pixel grid", guide.sprite.texture.get_size() == Vector2(21*32,32) and guide.sprite.hframes == 21 and guide.sprite.frame == 16 and guide.sprite.scale == Vector2.ONE and guide.sprite.offset == Vector2(0,-16) and guide.sprite.position == Vector2.ZERO)
	var clear := true
	for rect in controller.routines.obstacles:
		if rect.intersects(Rect2(guide.position - Vector2(5,6), Vector2(10,6))): clear = false
	check("guide stands in a reachable clear spot", clear and not controller.routines.route(lane.SPAWN, guide.position + Vector2(24,0)).is_empty())
	check("residents include guide in avoidance", guide.position in controller.routines._actor_blockers(controller.actors[0]))
	lane.player.position = guide.position + Vector2(20,0)
	lane.camera.position = guide.position
	lane.camera.reset_smoothing()
	await shot("town_yingluo")
	check("nearby guide opens real dialogue", controller.try_interact() and loop.hud.mode == "dialogue" and paused)
	var portrait: TextureRect = loop.hud.modal.find_child("DialoguePortrait", true, false)
	check("native 32x32 portrait matches guide source", portrait.texture.resource_path == Guide.PORTRAIT and portrait.texture.get_size() == Vector2(32,32))
	var remaining: float = loop.state.remaining
	await frames(6)
	check("dialogue freezes clock", loop.state.remaining == remaining)
	loop.hud.close_modal()
	check("closing dialogue resumes world", not paused)
	controller.show_guide_topics()
	check("first chapter reveals only first topic", loop.hud.choices.size() == 2 and loop.hud.choices[0].text == Guide.TOPICS[0].name)
	loop.hud.close_modal()
	controller._complete_guide_chapter(0)
	check("unfinished goal pays nothing", loop.state.campaign.chapter == 0 and loop.state.coins == 0)
	loop.hud.close_modal()
	loop.state.journal.gather = 3
	controller.show_guide()
	var reward_action: Callable = loop.hud.choices[0].action
	check("completed goal offers dialogue hand-in", loop.hud.choices[0].text == "完成")
	reward_action.call()
	check("hand-in advances one chapter and pays once", loop.state.campaign.chapter == 1 and loop.state.coins == 30 and loop.hud.mode == "dialogue" and paused)
	loop.state.journal.serve = 3
	reward_action.call()
	check("stale choice cannot complete the next ready chapter", loop.state.campaign.chapter == 1 and loop.state.coins == 30)
	loop.hud.close_modal()
	controller.open("故事")
	controller.complete_chapter()
	check("journal hand-in uses Yingluo too", loop.state.campaign.chapter == 2 and loop.state.coins == 70 and loop.hud.lines[0] == C.D.quests[1].name)
	loop.hud.close_modal()
	# Every chapter gets current-only dialogue, measured in all four locales.
	var service = root.get_node("Localization")
	for language in ["zh_CN", "en", "ja", "zh_TW"]:
		service.set_language(language, false)
		for chapter in range(Guide.CHAPTERS.size()):
			loop.state.campaign.chapter = chapter
			controller.show_guide_goal()
			for index in range(loop.hud.lines.size()):
				loop.hud.line_index = index
				loop.hud._show_line()
				await frames(1)
				check("line fits " + language + " " + str(chapter) + "/" + str(index), loop.hud.dialogue_text.get_content_height() <= loop.hud.dialogue_text.size.y)
			loop.hud.close_modal()
		loop.state.campaign.chapter = 2
		controller.show_guide_goal()
		loop.hud.line_index = 1
		loop.hud._show_line()
		service.set_language("en" if language != "en" else "ja", false)
		var step := Onboarding.current(loop.state)
		check("dynamic goal switches language " + language, loop.hud.dialogue_text.text == I18n.format("当前目标：%s · %d/%d", [step.objective, step.progress, step.goal]))
		service.set_language(language, false)
		finish_lines()
		await shot("goal_" + language)
		loop.hud.close_modal()
		controller.show_guide(true)
		loop.hud.dialogue_text.visible_characters = -1
		await shot("welcome_" + language)
		loop.hud.close_modal()
	loop.state.campaign.chapter = 12
	controller.show_guide_topics()
	check("all unlocked topics fit above dialogue", loop.hud.choices.size() == 4)
	var next_topic: Callable = loop.hud.choices[2].action
	next_topic.call()
	check("topic pages reach later lessons", loop.hud.choices[0].text == Guide.TOPICS[2].name and loop.hud.choices.size() == 4)
	next_topic = Callable()
	finish_lines()
	var body_rect: Rect2 = loop.hud.dialogue_text.get_parent().get_global_rect()
	check("four choices align above body and inside right frame", loop.hud.choices_root.get_global_rect().end == Vector2(body_rect.end.x - 4,body_rect.position.y - 2))
	await shot("topics_zh_TW")
	loop.hud.close_modal()
	controller.show_guide()
	check("final dialogue has no repeated reward", loop.hud.lines == [Guide.FAREWELL] and loop.hud.choices[0].text == "当前目标")
	loop.hud.close_modal()
	loop.state.phase = "night"
	controller._process(0.0)
	check("guide has no invisible night collider", not guide.visible and guide.collision_layer == 0 and not controller.try_interact())
	loop.state.phase = "day"
	controller._process(0.0)
	check("guide returns the next day", guide.visible and guide.collision_layer == 2)
	Saves.active_slot = 1
	Saves.created_at = int(Time.get_unix_time_from_system())
	check("save writes welcome and chapter", loop.save_progress().ok)
	var disk: Dictionary = Saves.read_slot(1)
	check("disk roundtrip keeps guide progress", disk.ok and disk.data.state.campaign.guide_met and disk.data.state.campaign.chapter == 12)
	Saves.end_session()
	reward_action = Callable()
	portrait = null
	lane.queue_free()
	await frames(5)
	controller = null
	guide = null
	loop = null
	lane = null
	await create_timer(0.25).timeout
	print("GUIDE COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
