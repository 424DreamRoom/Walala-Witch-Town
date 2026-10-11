extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
var failures := 0
var checks := 0
var capture := false
var lane
var loop

func _initialize() -> void:
	Preferences.file_path = "res://output/campaign_preferences_test.cfg"
	Saves.directory = "res://output/campaign_test_saves"
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(label: String, condition: bool) -> void:
	checks += 1
	if not condition: failures += 1
	print("CAMPAIGN ",checks," ",label,": ","PASS" if condition else "FAIL")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func shot(name: String) -> void:
	if not capture: return
	await frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = lane.viewport.get_texture().get_image()
	check("capture "+name,image.save_png("res://Scenes/Campaign/Verification/"+name+".png")==OK)

func finish_day(s) -> void:
	s.phase = "night"
	s.end_phase()
	s.next_day()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Scenes/Campaign/Verification"))
	check("20 crops, 120 ingredients, 360 recipes, 10 NPCs",C.D.crops.size()==20 and C.D.ingredients.size()==120 and C.D.recipes.size()==360 and C.D.npcs.size()==10)
	var s = State.new()
	# Farm terrain may contain new obstacles; use the first available test plot.
	var tile := 0
	while tile < State.FARM_TILE_COUNT and not State.FarmTerrain.can_till(s,tile): tile += 1
	check("test plot is available", tile < State.FARM_TILE_COUNT)
	check("initial campaign saves",not State.normalize_save_data(s.to_save_data()).is_empty())
	var old: Dictionary = s.to_save_data()
	old.erase("campaign")
	old.menu = [true,true,true]
	check("legacy three-dish save migrates",State.normalize_save_data(old).get("menu",[]).size()==C.D.recipes.size())
	for invalid in [-1,1.5,INF,NAN,"bad"]:
		var data: Dictionary = s.to_save_data()
		data.campaign.pantry.egg = invalid
		check("reject invalid pantry "+str(invalid),State.normalize_save_data(data).is_empty())
	for crop in C.D.crops:
		if crop.id=="herb": continue
		s = State.new()
		s.day = 1 + int(crop.seasons[0])*28
		s.campaign.selected_crop = crop.id
		s.campaign.seeds[crop.id] = 1
		s.campaign.pantry[crop.id] = 0
		check("till "+crop.id,s.work_farm_tile(tile))
		check("plant "+crop.id,s.work_farm_tile(tile) and s.campaign.seeds[crop.id]==0)
		for i in range(crop.days):
			s.farm.plots[str(tile)].watered = true
			finish_day(s)
		check("mature "+crop.id,s.farm.plots[str(tile)].growth==crop.days)
		check("harvest "+crop.id,s.work_farm_tile(tile) and s.campaign.pantry[crop.id]==crop.yield_count)
		check("save crop "+crop.id,not State.normalize_save_data(s.to_save_data()).is_empty())
		if crop.regrow>0: check("regrow "+crop.id,s.farm.plots[str(tile)].growth==crop.days-crop.regrow)
	s = State.new()
	s.campaign.selected_crop="tomato"
	s.campaign.seeds.tomato=1
	s.work_farm_tile(tile)
	check("season rejects atomically",not s.work_farm_tile(tile) and s.campaign.seeds.tomato==1)
	s.campaign.selected_crop="turnip"
	s.work_farm_tile(tile)
	s.day=28
	finish_day(s)
	check("season transition clears incompatible crop",s.farm.plots[str(tile)].growth==-1)
	s.campaign.machines.greenhouse=1
	s.campaign.selected_crop="turnip"
	s.campaign.seeds.turnip=1
	check("greenhouse permits off-season",s.work_farm_tile(tile))
	s.campaign.machines.sprinkler=clampi(1 + tile / 24,1,4)
	s.campaign.machines.hive=1
	s.campaign.machines.mill=1
	s.campaign.pantry.wheat=2
	finish_day(s)
	check("machines irrigate, mill and produce honey",s.farm.plots[str(tile)].watered and s.campaign.pantry.wheat==0 and s.campaign.pantry.flour==6 and s.campaign.pantry.honey==1)
	for index in range(C.D.recipes.size()):
		s = State.new()
		s.campaign.restaurant=4
		s.menu[index]=true
		s.materials=[30,30,30]
		for id in s.campaign.pantry: s.campaign.pantry[id]=30
		s.phase="night"
		s.remaining=State.NIGHT_SECONDS
		check("cook "+str(index),s.start_cook(index))
		var before: Dictionary = s.campaign.pantry.duplicate()
		check("no duplicate debit "+str(index),not s.start_cook(index) and s.campaign.pantry==before)
		s.tick(8)
		check("plate ready "+str(index),s.held==index)
		s.customers=[{"seat":0,"dish":index,"patience":35.0,"variant":0,"npc":0,"status":"waiting","eating_left":0.0}]
		check("serve "+str(index),s.serve(0) and s.income>=C.D.recipes[index].price)
		check("meal save "+str(index),not State.normalize_save_data(s.to_save_data()).is_empty())
	for npc in C.D.npcs:
		s = State.new()
		C.talk(s,npc.id)
		C.talk(s,npc.id)
		check("once daily chat "+npc.id,s.campaign.residents[npc.id].affinity==12)
		s.campaign.pantry[npc.gift]=20
		check("gift "+npc.id,C.gift(s,npc.id) and not C.gift(s,npc.id))
		s.campaign.residents[npc.id].affinity=1000
		s.campaign.chapter=12
		for stage in range(4):
			s.day += 1
			C.talk(s,npc.id)
			check("story "+npc.id+str(stage),C.story(s,npc.id))
		check("story ends "+npc.id,not C.story(s,npc.id))
	s=State.new()
	s.coins=5000
	for id in s.campaign.pantry: s.campaign.pantry[id]=1000
	for level in range(4): check("restaurant expansion "+str(level),C.upgrade(s,"restaurant"))
	check("restaurant maximum",not C.upgrade(s,"restaurant") and C.restaurant(s).seats==6)
	s.set_menu_dish(0, true)
	s.phase="night"
	s.remaining=State.NIGHT_SECONDS
	s.materials=[100,100,100]
	for i in range(6): check("admit seat "+str(i),s.admit())
	check("no overbooking",not s.admit())
	check("six-seat save valid",not State.normalize_save_data(s.to_save_data()).is_empty())
	s.phase="day"
	s.customers.clear()
	check("smelt in construction storage",C.upgrade(s,"smelt"))
	check("furniture craft",C.craft(s,"oak_chair"))
	check("furniture placement",C.decorate(s,"oak_chair","restaurant",0))
	check("decor improves comfort",C.comfort(s)==1)
	check("placement rejection atomic",not C.decorate(s,"moon_bed","restaurant",0) and s.campaign.placed.size()==1)
	check("reclaim furniture",C.decorate(s,"oak_chair","restaurant",0) and s.campaign.placed.is_empty())
	s.campaign.stock.oak_chair=99
	C.decorate(s,"oak_chair","restaurant",0)
	C.craft(s,"oak_chair")
	check("full furniture storage preserves placement",not C.decorate(s,"oak_chair","restaurant",0) and s.campaign.stock.oak_chair==99 and s.campaign.placed.size()==1)
	s.campaign.stock.oak_chair=0
	C.decorate(s,"oak_chair","restaurant",0)
	s.day=21
	check("festival once per date",C.celebrate(s) and not C.celebrate(s))
	check("campaign save roundtrip",C.normalize(s.campaign)==s.campaign)
	C.service(s,{"npc":0},33)
	C.service(s,{"npc":0},33)
	check("banquet tracks distinct recipes",C.metric(s,"banquet")==1)
	C.service(s,{"npc":0},34)
	C.service(s,{"npc":0},35)
	check("all three banquet dishes required",C.metric(s,"banquet")==3)
	s=State.new()
	s.journal.gather=3
	check("first chapter reward",C.complete_chapter(s) and s.coins==30 and s.campaign.chapter==1)
	check("no repeat chapter reward",not C.complete_chapter(s) and s.coins==30)
	lane=load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(6)
	loop=lane.get_node("GameLoop")
	loop.paused_for_test=true
	check("campaign controller installed",is_instance_valid(loop.campaign_controller))
	for page in ["故事","种子","食谱","居民","探索","成长","仓储","家具"]:
		loop.campaign_controller.open(page)
		await frames()
		check("UI tab "+page,loop.hud.mode=="campaign" and is_instance_valid(loop.campaign_controller.list))
		if page in ["种子","食谱","居民","成长"]: await shot("tab_"+str(["故事","种子","食谱","居民","探索","成长","仓储","家具"].find(page)))
		loop.hud.close_modal()
	var i18n = root.get_node("Localization")
	for locale in ["zh_CN","en","ja","zh_TW"]:
		i18n.set_language(locale,false)
		loop.campaign_controller.open("食谱")
		await frames()
		var caption: Label = loop.campaign_controller.list.get_child(1).get_child(1)
		check("localized menu "+locale,caption.text.begins_with(TranslationServer.translate("蘑菇汤")))
		await shot("menu_"+locale)
		loop.hud.close_modal()
		loop.hud.start_dialogue(C.D.npcs[0].name,"res://Art/Campaign/npcs/mori.aseprite",[C.D.npcs[0].events[0]])
		loop.hud.dialogue_text.visible_characters = -1
		loop.hud.reveal = float(loop.hud.dialogue_text.get_total_character_count())
		await shot("story_"+locale)
		loop.hud.close_modal()
	i18n.set_language("zh_CN",false)
	loop.state.campaign.chapter=12
	for region in C.D.regions:
		loop.enter(region.id)
		await frames()
		check("real tilemap "+region.id,loop.location=="field" and loop.area.region_id==region.id and loop.area.tiles.get_used_cells().size()==920)
		lane.player.position=loop.area.points[0]
		loop.interact()
		check("real gather "+region.id,loop.state.campaign.gathered.get(region.id+":0",0)==1)
		if region.id=="grove": await shot("grove")
		loop.enter("town")
	loop.enter("farm")
	loop.state.campaign.selected_crop="turnip"
	loop.state.work_farm_tile(tile)
	loop.state.work_farm_tile(tile)
	await shot("farm_crop")
	loop.enter("restaurant")
	loop.state.campaign.restaurant=4
	loop.state.set_menu_dish(0, true)
	loop.state.phase="night"
	loop.state.remaining=State.NIGHT_SECONDS
	loop.state.materials=[100,100,100]
	for i in range(6): loop.state.admit()
	await shot("six_guests")
	loop.state.phase="day"
	loop.state.customers.clear()
	loop.campaign_controller.show_intro()
	await frames()
	await shot("intro")
	check("intro pauses world",paused)
	loop.campaign_controller.finish_intro()
	check("intro completes into paused arrival",paused and loop.state.campaign.introduced and loop.campaign_controller.arrival_active)
	loop.campaign_controller._process(6.0)
	check("default protagonist completes opening with guide welcome",paused and loop.state.campaign.player_name == C.DEFAULT_PLAYER_NAME and loop.hud.mode=="dialogue" and loop.state.campaign.guide_met)
	loop.hud.close_modal()
	# A real isolated JSON slot write and read, including new field routing.
	Saves.active_slot=1
	Saves.created_at=int(Time.get_unix_time_from_system())
	loop.enter("grove")
	check("isolated save write",loop.save_progress().ok)
	var disk: Dictionary = Saves.read_slot(1)
	check("isolated save read",disk.ok and disk.data.state.campaign.region=="grove")
	loop._restore_world(disk.data.world)
	check("region survives restore",loop.area.region_id=="grove")
	Saves.end_session()
	print("CAMPAIGN COMPLETE checks=",checks," failures=",failures)
	lane.queue_free()
	await frames(4)
	loop = null
	lane = null
	# Headless frames run faster than the audio mixer; allow stopped voices to drain.
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
