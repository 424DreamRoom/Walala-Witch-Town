extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const Goals = preload("res://Scenes/Campaign/onboarding.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/story_rebuild_integration/"
var checks := 0
var failures := 0
var lane
var loop
var controller
var capture := false

func _initialize() -> void:
	var profile := OUT + "profile_" + str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile + "/preferences.cfg"
	Saves.directory = profile + "/saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(caption: String, result: bool) -> void:
	checks += 1
	if not result: failures += 1
	print("REBUILT ", caption, ": PASS" if result else ": FAIL")

func frames(count: int = 2) -> void:
	for i in range(count): await process_frame

func shot(filename: String) -> void:
	if not capture: return
	if loop != null and loop.hud.mode == "dialogue":
		loop.hud.dialogue_text.visible_characters = -1
		loop.hud._line_complete()
	await frames(3)
	await RenderingServer.frame_post_draw
	check("capture " + filename, lane.viewport.get_texture().get_image().save_png(OUT + filename + ".png") == OK)

func mark_introduced(s) -> void:
	s.campaign.introduced = true
	s.campaign.guide_met = true
	s.campaign.opening_stage = 3
	s.restaurant_leased = true

func ready_chapter(s, index: int) -> void:
	s.campaign.chapter = index
	s.campaign.pending_scene = -1
	var q: Dictionary = C.D.quests[index]
	match q.metric:
		"serve", "fish": s.journal[q.metric] = q.goal
		"restaurant": s.campaign.restaurant = q.goal
		"repair_stock":
			for id in q.cost: s.campaign.pantry[id] = q.cost[id]
		_: s.campaign.stats[q.metric] = q.goal

func load_game() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(8)
	loop = lane.get_node("GameLoop")
	controller = loop.campaign_controller
	controller.set_process(false)

func unload_game() -> void:
	paused = false
	lane.queue_free()
	await frames(5)

func state_checks() -> void:
	check("ten full chapters", C.D.quests.size() == 10 and C.D.opening.size() == 3)
	var lines := 0
	for scene in C.D.opening: lines += scene.dialogue.size()
	for q in C.D.quests: lines += q.dialogue.size()
	check("all 436 manuscript lines compiled", lines == 436)
	check("new state roundtrip", not C.normalize(C.initial()).is_empty())
	for old_chapter in range(13):
		var s = State.new()
		mark_introduced(s)
		s.coins = 321
		s.campaign.chapter = old_chapter
		s.campaign.pantry.scrap = 9
		s.campaign.residents.mori.affinity = 444
		var old: Dictionary = s.to_save_data()
		for key in ["story_version", "legacy_chapter", "opening_stage", "pending_scene"]: old.campaign.erase(key)
		var restored = State.new()
		check("migrate legacy " + str(old_chapter), restored.restore_save_data(old) and restored.coins == 321 and restored.campaign.chapter == 0 and restored.campaign.legacy_chapter == old_chapter and restored.campaign.pantry.scrap == 9 and restored.campaign.residents.mori.affinity == 444 and restored.campaign.opening_stage == 3)
		for region in C.D.regions:
			if old_chapter >= region.legacy_chapter: check("retain unlock " + str(old_chapter) + region.id, C.region_unlocked(restored, region))
	var s = State.new()
	mark_introduced(s)
	check("preparation belongs to first chapter", Goals.current(s).id == "prepare")
	for index in range(10):
		ready_chapter(s, index)
		var before: int = s.coins
		check("complete once " + str(index), C.complete_chapter(s) and s.coins == before + C.D.quests[index].reward and s.campaign.pending_scene == index)
		check("pending scene blocks duplicate and next reward " + str(index), not C.complete_chapter(s) and s.coins == before + C.D.quests[index].reward)
		var restored = State.new()
		check("pending scene roundtrip " + str(index), restored.restore_save_data(s.to_save_data()) and restored.campaign.pending_scene == index)
		if index == 7: check("repair costs consumed exactly", s.campaign.pantry.iron == 0 and s.campaign.pantry.scrap == 0 and s.campaign.pantry.crystal == 0)
		s.campaign.pending_scene = -1
	check("ending leaves free play", C.current_main(s).is_empty() and s.phase == "day")
	ready_chapter(s, 7)
	s.campaign.pantry.iron = 3
	s.campaign.pantry.crystal = 100
	check("excess crystals cannot replace missing iron", C.metric(s, "repair_stock") == 13 and not C.complete_chapter(s))
	var invalid := C.initial()
	invalid.pending_scene = 0
	check("invalid pending scene rejected", C.normalize(invalid).is_empty())
	invalid = C.initial()
	invalid.opening_stage = 3
	check("inconsistent opening rejected", C.normalize(invalid).is_empty())

func run() -> void:
	state_checks()
	check("isolated new slot", Saves.begin_slot(1).ok)
	C.pending_intro = true
	await load_game()
	check("opening film pauses", paused and is_instance_valid(controller.intro))
	check("public notice replaces letter", C.D.intro.map(func(value): return value.scene) == ["kitchen", "notice", "road", "town", "home"])
	controller.intro_elapsed = 9.0
	controller._render_intro()
	await shot("public_notice")
	controller.finish_intro()
	check("film skip keeps dock dialogue", loop.location == "dock" and loop.hud.mode == "dialogue" and loop.hud.lines.size() == 10 and paused)
	check("Nagi present on dock", controller.opening_cast.size() == 1 and controller.opening_cast[0].visible)
	var next := InputEventAction.new()
	next.action = "dialogue_next"
	next.pressed = true
	loop.hud.dialogue_text.visible_characters = -1
	loop.hud._input(next)
	check("opening dialogue accepts gameplay input", loop.hud.line_index == 1)
	check("opening still blocks inventory", not loop.hud._begin_modal("bag"))
	await shot("opening_dock")
	controller._finish_opening_stage(0)
	check("guide approaches on farm", loop.location == "farm" and controller.arrival_active and paused)
	controller._process(0.5)
	check("guide actually walks", controller.arrival_actor.position != controller.ARRIVAL_PATH[0])
	controller._process(10.0)
	check("farm dialogue has fifteen lines", loop.hud.mode == "dialogue" and loop.hud.lines.size() == 15 and not controller.arrival_active)
	await shot("opening_farm")
	controller._finish_opening_stage(1)
	check("lease scene opens kitchen without a second fee", loop.location == "restaurant" and loop.state.restaurant_leased and loop.hud.lines.size() == 18 and paused)
	check("lease cast present", controller.opening_cast.size() == 3)
	await shot("opening_lease")
	controller._finish_opening_stage(2)
	check("opening releases control", not paused and loop.hud.mode.is_empty() and loop.state.campaign.guide_met and not controller.opening_active())
	check("opening cast cleaned up", controller.opening_cast.is_empty())
	var disk := Saves.read_slot(1)
	check("opening completion saved", disk.ok and disk.data.state.campaign.opening_stage == 3 and disk.data.state.restaurant_leased)
	# Resume each interrupted opening segment, including its actual location.
	for stage in range(3):
		loop.state.campaign.guide_met = false
		loop.state.campaign.opening_stage = stage
		controller._start_opening_stage()
		if stage == 1: controller._process(10.0)
		check("resume opening segment " + str(stage), loop.hud.mode == "dialogue" and loop.location == C.D.opening[stage].location)
		controller._finish_opening_stage(stage)
		if controller.arrival_active: controller._process(10.0)
		loop.hud.close_modal()
		if is_instance_valid(controller.arrival_actor): controller.arrival_actor.queue_free()
		controller.arrival_actor = null
	mark_introduced(loop.state)
	for language in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(language, false)
		await frames()
		var fit := true
		var portraits := true
		for scene in C.D.opening:
			loop.hud.start_dialogue("", "res://Art/Characters/NPC32/portraits/nagi.aseprite", controller._beat_lines(scene.dialogue))
			for line in range(loop.hud.lines.size()):
				loop.hud.line_index = line
				loop.hud._show_line()
				await process_frame
				fit = fit and loop.hud.dialogue_text.get_content_height() <= loop.hud.dialogue_text.size.y
			loop.hud.close_modal()
		for index in range(10):
			ready_chapter(loop.state, index)
			var before: int = loop.state.coins
			controller._complete_guide_chapter(index)
			await frames()
			check("runtime full dialogue " + language + str(index), loop.hud.lines.size() == C.D.quests[index].dialogue.size() and loop.state.coins == before + C.D.quests[index].reward)
			for line in range(loop.hud.lines.size()):
				loop.hud.line_index = line
				loop.hud._show_line()
				await process_frame
				fit = fit and loop.hud.dialogue_text.get_content_height() <= loop.hud.dialogue_text.size.y
				portraits = portraits and loop.hud.dialogue_portrait.texture != null and not loop.hud.dialogue_speaker.text.is_empty()
			if index == 7: await shot("branch_dialogue_" + language)
			controller._finish_story(index)
			loop.hud.close_modal()
		check("all lines fit " + language, fit)
		check("speaker portraits " + language, portraits)
		controller.story_filter = "已完成"
		controller.open("故事")
		check("ten chapter recalls " + language, controller.list.get_child_count() >= 10)
		loop.hud.close_modal()
	# A scene saved after payout resumes without paying again on actual reload.
	ready_chapter(loop.state, 7)
	controller._complete_guide_chapter(7)
	var paid: int = loop.state.coins
	check("pending scene written", loop.save_progress().ok)
	await unload_game()
	C.pending_intro = false
	check("pending slot selected again", Saves.begin_slot(1).ok)
	await load_game()
	check("disk reload resumes pending chapter", loop.state.coins == paid and loop.state.campaign.pending_scene == 7 and loop.hud.mode == "dialogue" and loop.hud.lines.size() == C.D.quests[7].dialogue.size())
	controller._complete_guide_chapter(7)
	check("reload never pays twice", loop.state.coins == paid)
	controller._finish_story(7)
	loop.hud.close_modal()
	controller.story_filter = "已完成"
	controller.open("故事")
	await shot("story_journal")
	loop.hud.close_modal()
	controller._recall_chapter(7)
	check("recall keeps progress and inventory", loop.state.coins == paid and loop.state.campaign.chapter == 8 and loop.state.campaign.pantry.iron == 0)
	await unload_game()
	print("REBUILT COMPLETE checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
