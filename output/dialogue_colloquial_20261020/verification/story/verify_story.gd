extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const Goals = preload("res://Scenes/Campaign/onboarding.gd")
const Guide = preload("res://Scenes/Campaign/guide_profile.gd")
const Terrain = preload("res://Scenes/Farm/farm_terrain.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const I18n = preload("res://Localization/localized_text.gd")
const OUT := "res://output/dialogue_colloquial_20261020/verification/story/"
var checks := 0
var failures := 0
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
	print("STORY ", caption, ": PASS" if result else ": FAIL")

func frames(count: int = 2) -> void:
	for index in range(count): await process_frame

func shot(filename: String) -> void:
	if not capture: return
	await frames(3)
	await RenderingServer.frame_post_draw
	check("capture " + filename, lane.viewport.get_texture().get_image().save_png(OUT + filename + ".png") == OK)

func ready_chapter(s, chapter: int) -> void:
	s.campaign.chapter = chapter
	var q: Dictionary = C.D.quests[chapter]
	match q.metric:
		"gather", "serve", "fish": s.journal[q.metric] = q.goal
		"friend": s.campaign.residents.mori.affinity = q.goal
		"restaurant": s.campaign.restaurant = q.goal
		"crop_types":
			for index in range(q.goal): s.campaign.harvested[C.D.crops[index].id] = true
		"banquet": s.campaign.stats.banquet = 7
		_: s.campaign.stats[q.metric] = q.goal

func state_checks() -> void:
	var s = State.new()
	check("initial goal is gathering", Goals.current(s).id == "main_00" and Goals.current(s).progress == 0)
	for index in [0, 3, 6]: check("first ingredients " + str(index), s.gather(index))
	check("gathering hands into preparation", C.complete_chapter(s) and s.coins == 30 and Goals.current(s).id == "prepare")
	check("preparation leads to menu", s.process_raw() and Goals.current(s).id == "menu")
	check("listing leads to first meal", s.set_menu_dish(0, true) and Goals.current(s).id == "first_meal")
	for index in [0, 3, 6]: s.gather(index)
	s.process_raw()
	check("service starts with available ingredients", s.start_service())
	for meal in range(3):
		if s.customers.is_empty(): s.admit()
		var seat: int = s.customers[0].seat
		check("real cooking " + str(meal), s.start_cook(0))
		s.tick(3.1)
		check("real meal " + str(meal), s.serve(seat))
		check("first meal resumes chapter progress " + str(meal), Goals.current(s).id == "main_01" and Goals.current(s).progress == meal + 1)
		s.tick(3.2)
	check("original dinner reward remains", C.complete_chapter(s) and s.coins == 70 and Goals.current(s).id == "plant")
	s.end_phase()
	s.next_day()
	s.wand_mode = "blue"
	var plots: Array[int] = []
	for index in range(Terrain.TILE_COUNT):
		if not Terrain.can_till(s, index): continue
		plots.append(index)
		if plots.size() == 5: break
	for index in plots:
		check("real till and seed " + str(index), s.work_farm_tile(index) and s.work_farm_tile(index))
	check("five planted plots lead to water", Goals.current(s).id == "water" and Goals.current(s).progress == 0)
	for index in plots: check("real water " + str(index), s.work_farm_tile(index))
	check("water leads to harvest", Goals.current(s).id == "main_02")
	var restored = State.new()
	check("saved tutorial resumes without new schema", restored.restore_save_data(s.to_save_data()) and Goals.current(restored) == Goals.current(s) and not restored.campaign.has("onboarding"))
	for day in range(3):
		if day > 0:
			for index in plots: s.work_farm_tile(index)
		s.phase = "result"
		s.next_day()
		check("growing crops never regress to planting " + str(day), Goals.current(s).id == "main_02")
	for index in plots:
		check("real harvest " + str(index), s.work_farm_tile(index))
		check("harvest does not regress tutorial " + str(index), Goals.current(s).id == "main_02")
	check("harvest pays original reward", C.complete_chapter(s) and s.campaign.chapter == 3)
	s = State.new()
	s.campaign.chapter = 1
	C.add(s, "herb", 1)
	var pantry_dish := -1
	for dish in range(3, s.menu.size()):
		if s.can_cook(dish):
			pantry_dish = dish
			break
	check("pantry recipe bypasses optional raw preparation", pantry_dish >= 3 and s.set_menu_dish(pantry_dish, true) and Goals.current(s).id == "first_meal")
	s = State.new()
	s.campaign.chapter = 1
	s.journal.serve = 3
	check("existing completed meals skip early steps", Goals.current(s).id == "main_01" and Guide.ready(s))
	s = State.new()
	s.campaign.chapter = 2
	s.campaign.stats.harvest = 1
	check("existing harvests skip early farming", Goals.current(s).id == "main_02" and Goals.current(s).progress == 1)
	s.campaign.chapter = 12
	check("completed campaign has no lingering tutorial", Goals.current(s).is_empty() and Goals.goal_line(s).is_empty())

func run() -> void:
	state_checks()
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(8)
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.state.campaign.introduced = true
	loop.state.campaign.guide_met = true
	loop.enter("farm")
	var controller = loop.campaign_controller
	var localization = root.get_node("Localization")
	for language in ["zh_CN", "en", "ja", "zh_TW"]:
		localization.set_language(language, false)
		for step in C.D.onboarding.values():
			check("tutorial goal is journal-only " + language + "/" + step.id, loop.hud.base.get_node_or_null("CurrentObjective") == null)
		for chapter in range(12):
			loop.state = State.new()
			loop.state.campaign.introduced = true
			loop.state.campaign.guide_met = true
			loop.state.campaign.chapter = chapter
			loop.hud.refresh()
			check("objective panel removed " + language + "/" + str(chapter), loop.hud.base.get_node_or_null("CurrentObjective") == null)
			if chapter == 1: await shot("hud_without_top_summary_" + language)
			ready_chapter(loop.state, chapter)
			var old_coins: int = loop.state.coins
			controller._complete_guide_chapter(chapter)
			check("chapter pays once without HUD objective " + language + "/" + str(chapter), loop.state.coins == old_coins + C.D.quests[chapter].reward and loop.hud.base.get_node_or_null("CurrentObjective") == null)
			var content_fits := true
			var speakers_match := true
			for index in range(loop.hud.lines.size()):
				loop.hud.line_index = index
				loop.hud._show_line()
				loop.hud.dialogue_text.visible_characters = -1
				await frames(1)
				content_fits = content_fits and loop.hud.dialogue_text.get_content_height() <= loop.hud.dialogue_text.size.y
				var beat: Variant = loop.hud.lines[index]
				if beat is Dictionary and beat.has("speaker"):
					speakers_match = speakers_match and loop.hud.dialogue_speaker.text == tr(beat.speaker) and loop.hud.history[-1] == loop.hud._history_line(index)
					var texture: Texture2D = loop.hud.dialogue_portrait.texture
					if texture is AtlasTexture:
						speakers_match = speakers_match and texture.atlas.resource_path == beat.portrait and texture.region == beat.portrait_region
					else: speakers_match = speakers_match and texture.resource_path == beat.portrait
				if chapter == 7 and index == 2: await shot("chapter_scene_" + language)
			check("all chapter lines fit " + language + "/" + str(chapter), content_fits)
			check("speaker portrait and history match " + language + "/" + str(chapter), speakers_match)
			loop.hud.close_modal()
		loop.state.campaign.chapter = 1
		controller.open("故事")
		await frames()
		check("journal shows current briefing and preparation only " + language, controller.list.get_child_count() == 1 and controller.list.get_child(0).get_child(0).text.contains(tr(C.D.quests[1].briefing)))
		await shot("journal_" + language)
		loop.hud.close_modal()
	for language in ["zh_CN", "en", "ja", "zh_TW"]:
		localization.set_language(language, false)
		for npc in C.D.npcs:
			loop.hud.start_dialogue(npc.name, "res://Art/Characters/NPC32/portraits/" + npc.id + ".aseprite", npc.lines + npc.events, [], Rect2(0, 0, 32, 32))
			var fits := true
			for index in range(loop.hud.lines.size()):
				loop.hud.line_index = index
				loop.hud._show_line()
				loop.hud.dialogue_text.visible_characters = -1
				await frames(1)
				fits = fits and loop.hud.dialogue_text.get_content_height() <= loop.hud.dialogue_text.size.y
			check("resident lines fit " + language + "/" + npc.id, fits)
			if npc.id == "toma" and language == "zh_CN": await shot("resident_toma_zh_CN")
			loop.hud.close_modal()
	# Legacy custom names must never be translated as an unrelated resident.
	loop.state = State.new()
	loop.state.campaign.chapter = 1
	loop.state.campaign.player_name = "陶陶"
	controller._recall_chapter(0)
	loop.hud.line_index = 2
	loop.hud._show_line()
	localization.set_language("en", false)
	check("language switch preserves custom name and localized history", loop.hud.dialogue_speaker.text == "陶陶" and loop.hud.history[-1].begins_with("陶陶："))
	loop.hud.line_index = 3
	loop.hud._show_line()
	check("resident with same source name still translates", loop.hud.dialogue_speaker.text == tr(C.entry(C.D.npcs,"toma").name))
	loop.hud.close_modal()
	var before: Dictionary = loop.state.to_save_data()
	controller._recall_chapter(1)
	check("future chapter cannot be recalled", loop.hud.mode.is_empty())
	controller._recall_chapter(0)
	check("recall has no transactions or hand-in", before == loop.state.to_save_data() and loop.hud.choices.size() == 1 and loop.hud.choices[0].text == "再会")
	loop.hud.close_modal()
	Saves.active_slot = 1
	Saves.created_at = int(Time.get_unix_time_from_system())
	check("story writes isolated save", loop.save_progress().ok)
	var disk: Dictionary = Saves.read_slot(1)
	var resumed = State.new()
	check("disk resume keeps chapter and active goal", disk.ok and resumed.restore_save_data(disk.data.state) and resumed.campaign.chapter == 1 and Goals.current(resumed) == Goals.current(loop.state))
	Saves.end_session()
	lane.queue_free()
	await frames(6)
	loop = null
	lane = null
	controller = null
	print("STORY COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
