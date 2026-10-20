extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
var failures := 0
var checks := 0
var capture := false

func _initialize() -> void:
	var profile := "res://output/quest_pacing/"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile+"/preferences.cfg"
	Saves.directory = profile+"/saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(caption: String, result: bool) -> void:
	checks += 1
	if not result: failures += 1
	print("QUEST PACING ",caption,": ","PASS" if result else "FAIL")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func all_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button: result += node.text+"\n"
	for child in node.get_children(): result += all_text(child)
	return result

func run() -> void:
	var s = State.new()
	check("opening has one main and no sides",C.current_main(s).id=="main_00" and s.campaign.side_active.is_empty())
	C.talk(s,"mori")
	check("meeting before chapter gate does not assign a side",s.campaign.met_residents==["mori"] and s.campaign.side_active.is_empty())
	s.journal.gather=3
	check("main advances only one chapter",C.complete_chapter(s) and C.current_main(s).id=="main_01")
	C.talk(s,"mori")
	C.talk(s,"toma")
	check("eligible conversations discover two sides",s.campaign.side_active.size()==2)
	s.campaign.chapter=12
	C.talk(s,"lumi")
	check("third side waits at its resident",not s.campaign.side_active.has("lumi"))
	s.campaign.residents.mori.affinity=200
	var gift_id: String=C.D.npcs[0].gift
	s.campaign.pantry[gift_id]=0
	check("side cannot finish without materials",not C.story(s,"mori") and s.campaign.residents.mori.story==0)
	s.campaign.pantry[gift_id]=20
	var coins: int = s.coins
	check("side completes and pays once",C.story(s,"mori") and s.coins==coins+25 and s.campaign.side_active.size()==1)
	coins=s.coins
	check("same episode cannot pay twice",not C.story(s,"mori") and s.coins==coins)
	C.talk(s,"mori")
	check("next episode does not appear the same day",not s.campaign.side_active.has("mori"))
	C.talk(s,"lumi")
	check("later conversation uses the free slot",s.campaign.side_active.has("lumi"))
	s.campaign.side_active.erase("lumi")
	s.day+=1
	C.talk(s,"mori")
	check("later day discovers next episode",s.campaign.side_active.get("mori",-1)==1)
	check("active sides survive save roundtrip",State.normalize_save_data(s.to_save_data()).campaign==s.campaign)
	var old: Dictionary = s.to_save_data()
	for key in ["met_residents","side_active","side_last_day"]: old.campaign.erase(key)
	old.campaign.stats.erase("ridge")
	var restored: Dictionary = State.normalize_save_data(old)
	check("legacy save keeps chapter and finished episodes",not restored.is_empty() and restored.campaign.chapter==12 and restored.campaign.residents.mori.story==1 and restored.campaign.side_active.is_empty())
	for bad in [{"mori":3},{"unknown":0},{"mori":1,"toma":0,"lumi":0}]:
		var invalid: Dictionary = s.to_save_data()
		invalid.campaign.side_active=bad
		check("invalid active state rejected "+str(bad),State.normalize_save_data(invalid).is_empty())
	s=State.new()
	s.campaign.chapter=8
	for i in range(6): check("ridge survey action "+str(i),C.gather(s,"ridge",i))
	check("main story does not require optional resident stories",s.campaign.stats.stories==0 and C.complete_chapter(s) and s.campaign.chapter==9)
	s=State.new()
	s.campaign.chapter=1
	s.campaign.residents.mori.affinity=1000
	C.talk(s,"mori")
	s.campaign.pantry[gift_id]=10
	C.story(s,"mori")
	s.day+=1
	C.talk(s,"mori")
	check("later episode respects its chapter gate",not s.campaign.side_active.has("mori"))
	check("daily dialogue does not reveal future events",C.talk(s,"mori")==[C.D.npcs[0].lines[1]])
	s=State.new()
	s.campaign.chapter=1
	C.talk(s,"mori")
	var unchanged: Dictionary=s.campaign.pantry.duplicate()
	check("side can be deferred without cost or completion",C.defer_side(s,"mori") and s.campaign.side_active.is_empty() and s.campaign.residents.mori.story==0 and s.campaign.pantry==unchanged)
	C.talk(s,"mori")
	check("deferred side stays quiet for the day",s.campaign.side_active.is_empty())
	s.day+=1
	C.talk(s,"mori")
	check("deferred side can be rediscovered",s.campaign.side_active.has("mori"))
	var lane=load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(6)
	var loop=lane.get_node("GameLoop")
	loop.paused_for_test=true
	loop.state=State.new()
	loop.hud.open_journal()
	await frames()
	check("old task entrance opens unified journal",loop.hud.mode=="campaign" and paused)
	var controller=loop.campaign_controller
	var opening_text := all_text(controller.list)
	check("future main titles hidden",opening_text.contains(C.D.quests[0].name) and not opening_text.contains(C.D.quests[1].name) and controller.list.get_child_count()==1)
	var journal_key := InputEventKey.new()
	journal_key.keycode=KEY_J
	journal_key.physical_keycode=KEY_J
	journal_key.pressed=true
	loop.hud._input(journal_key)
	check("journal key closes and restores time",loop.hud.mode.is_empty() and not paused)
	loop.state.campaign.chapter=1
	C.talk(loop.state,"mori")
	C.talk(loop.state,"toma")
	for language in ["zh_CN","en","ja","zh_TW"]:
		root.get_node("Localization").set_language(language,false)
		controller.open("故事")
		await frames()
		check("localized main and two sides "+language,controller.list.get_child_count()==3 and all_text(controller.list).contains(TranslationServer.translate("支线")))
		if capture:
			await RenderingServer.frame_post_draw
			var image: Image=lane.viewport.get_texture().get_image()
			check("capture "+language,image.save_png("res://output/quest_pacing/"+language+".png")==OK)
		loop.hud.close_modal()
	root.get_node("Localization").set_language("zh_CN",false)
	controller.open("居民")
	await frames()
	check("resident page hides later episode titles",not all_text(controller.list).contains(C.D.npcs[0].stories[1]))
	loop.hud.close_modal()
	controller.story_filter="已完成"
	controller.open("故事")
	await frames()
	check("archive shows only completed main",controller.list.get_child_count()==1 and not all_text(controller.list).contains(C.D.quests[1].name))
	loop.hud.close_modal()
	Saves.active_slot=1
	Saves.created_at=int(Time.get_unix_time_from_system())
	check("isolated disk save",loop.save_progress().ok)
	var disk: Dictionary=Saves.read_slot(1)
	check("disk save preserves discovered sides",disk.ok and disk.data.state.campaign.side_active.size()==2 and int(disk.data.state.campaign.side_active.get("mori",-1))==0 and int(disk.data.state.campaign.side_active.get("toma",-1))==0)
	Saves.end_session()
	lane.queue_free()
	await frames(4)
	lane=null
	loop=null
	await create_timer(0.2).timeout
	print("QUEST PACING COMPLETE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
