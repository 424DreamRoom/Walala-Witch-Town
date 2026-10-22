extends SceneTree
## Real scene integration, traversability, save migration and four-language QA.
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const Prefs = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const RegionLayout = preload("res://Scenes/Campaign/region_layout.gd")
const OUT := "res://output/project_polish/"
var failures := 0
var checks := 0
var lane
var loop
var capture := false

func _initialize() -> void:
	var profile := OUT + "profile_" + str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Prefs.file_path = profile + "/preferences.cfg"
	Saves.directory = profile + "/saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(label: String, value: bool) -> void:
	checks += 1
	if not value: failures += 1
	print("POLISH ",label,": ","PASS" if value else "FAIL")

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func click(button: Button) -> void:
	var container = lane.viewport.get_parent()
	var position: Vector2 = container.position + button.get_global_rect().get_center() * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func shot(file: String) -> void:
	if not capture: return
	await frames()
	await RenderingServer.frame_post_draw
	check("screenshot " + file, lane.viewport.get_texture().get_image().save_png(OUT + file + ".png") == OK)

func ready_state():
	var state = State.new()
	state.day = 2
	state.daily_pulse = State.SeasonalDirector.pulse_for_day(state.day)
	state.restaurant_leased = true
	state.campaign.introduced = true
	state.campaign.guide_met = true
	state.campaign.opening_stage = 3
	state.campaign.chapter = 10
	state.campaign.restaurant = 4
	return state

func reachable(area, from: Vector2) -> Dictionary:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(1,7,78,37)
	grid.cell_size = Vector2(8,8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in range(7,44):
		for x in range(1,79):
			var point := Vector2(x*8,y*8)
			var feet := Rect2(point-Vector2(5,6),Vector2(10,6))
			grid.set_point_solid(Vector2i(x,y),area.solids.any(func(rect):return rect.intersects(feet)))
	var start := Vector2i((from/8.0).round())
	var result := {}
	for y in range(7,44):
		for x in range(1,79):
			var cell := Vector2i(x,y)
			if not grid.is_point_solid(cell) and not grid.get_id_path(start,cell).is_empty(): result[cell] = true
	return result

func can_reach(points: Dictionary, target: Vector2, distance: float = 20.0) -> bool:
	for cell in points:
		if Vector2(cell*8).distance_to(target) <= distance: return true
	return false

func run() -> void:
	var state = ready_state()
	for day in range(1,113):
		var pulse: Dictionary = State.SeasonalDirector.pulse_for_day(day)
		check("forecast agrees with season " + str(day), pulse.weather == ("snow" if C.season({"day":day}) == 3 and day%3 == 0 else "rain" if day%5 == 0 else "clear"))
		check("food focus exists " + str(day), C.D.tags.has(pulse.focus))
	state.materials = [7,5,3]
	check("base recipe portions",state.dish_portions(0)==3 and state.dish_portions(1)==2 and state.dish_portions(2)==3)
	state.menu[0] = true
	check("service starts with a prepared menu",state.start_service())
	check("cook debits one portion",state.start_cook(0) and state.dish_portions(0)==2)
	state.tick(8)
	state.customers=[{"seat":0,"dish":0,"patience":30.0,"variant":0,"npc":0,"status":"waiting","eating_left":0.0}]
	state.daily_pulse.focus = "vegetable"
	check("matching daily taste creates a tip",state.serve(0) and state.tips>0)
	var expected: int = state.income + state.tips
	state.end_phase()
	check("tips enter coins exactly once",state.income==expected and state.coins==expected)
	state.end_phase()
	check("closing cannot pay twice",state.coins==expected)
	check("service snapshot roundtrip",not State.normalize_save_data(state.to_save_data()).is_empty())
	state = ready_state()
	state.phase="night"
	state.menu[0]=true
	check("sold-out service can finish without an empty wait",state.service_exhausted())
	State.Items.change(state,{"mushroom":2})
	check("unprocessed stock keeps service open",not state.service_exhausted())
	state.raw=[0,0,0]
	state.cooking=0
	check("cooking keeps service open",not state.service_exhausted())
	state = ready_state()
	state.phase = "night"
	state.remaining = State.NIGHT_SECONDS
	var spicy := -1
	for index in range(C.D.recipes.size()):
		if "spicy" in C.D.recipes[index].tags and "vegetable" in C.D.recipes[index].tags:
			spicy = index
			break
	check("diet test recipe exists",spicy>=0)
	state.menu[0]=true
	state.menu[spicy]=true
	state.materials=[10,10,10]
	for id in state.campaign.pantry: state.campaign.pantry[id]=100
	check("guest avoids disliked ingredient when another dish exists",state.admit() and state.customers[0].dish==0)
	lane=load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(6)
	loop=lane.get_node("GameLoop")
	loop.paused_for_test=true
	loop.state=ready_state()
	var signatures := {}
	for region in C.D.regions:
		loop.enter(region.id)
		await frames(2)
		check("native tile layer " + region.id,loop.area.tiles.get_used_cells().size()==920)
		var accessible := reachable(loop.area,loop.area.spawn)
		check("entrance connected " + region.id,accessible.size()>500)
		for index in range(loop.area.points.size()): check("gather reachable " + region.id+str(index),can_reach(accessible,loop.area.points[index]))
		for index in range(loop.area.resource_nodes.size()): check("resource reachable " + region.id+str(index),can_reach(accessible,loop.area.resource_nodes[index].anchor))
		check("exit reachable " + region.id,can_reach(accessible,loop.area.stations.exit))
		var saved: Vector2 = loop.area.safe_position(Vector2(500,160))
		check("legacy water position recovers " + region.id,loop.area._clear(saved))
		var layout := RegionLayout.get_region(region.id)
		signatures[JSON.stringify(layout.routes)] = true
		lane.player.position = loop.area.spawn
		loop.state.remaining=State.DAY_SECONDS*0.6
		await shot(region.id)
		# Preview uses current depletion and can inspect another unlocked region
		# without changing location, inventory, time or unlock progress.
		loop.hud.open_map()
		loop.hud.map_view.show_region("field",false)
		await frames()
		var canvas = loop.hud.map_view.canvas
		var count: int = canvas.region_markers("field").size()
		loop.state.campaign.gathered[region.id+":0"]=2
		check("atlas reflects gathered resources " + region.id,canvas.region_markers("field").size()==count-1)
		await shot(region.id+"_map")
		loop.hud.close_modal()
	check("six distinct routes",signatures.size()==6)
	for transition in [[4,"rain"],[5,"clear"],[86,"snow"]]:
		loop.state.day=transition[0]
		loop.campaign_controller.observed_day=loop.state.day
		loop.state.phase="result"
		loop.state.next_day()
		loop._process(0.0)
		loop.campaign_controller._process(0.0)
		check("live next-day forecast "+str(loop.state.day),loop.lane.weather.get_weather()==transition[1] and loop.state.daily_pulse.weather==transition[1])
	loop.state=ready_state()
	loop.lane.weather.clear_weather()
	loop.campaign_controller.observed_day=loop.state.day
	loop.hud.open_map()
	var atlas = loop.hud.map_view
	atlas.show_region("field",false)
	var atlas_before: Dictionary = loop.state.to_save_data()
	atlas.exploration_picker.item_selected.emit(1)
	check("atlas destination selection is read only",loop.state.to_save_data()==atlas_before and loop.location=="field")
	check("other destination hides current player marker",not atlas.canvas.player_anchor("field").is_finite())
	loop.hud.close_modal()
	loop.enter("town")
	lane.player.position=Vector2(532,456)
	for locale in ["zh_CN","en","ja","zh_TW"]:
		root.get_node("Localization").set_language(locale,false)
		for npc in C.D.npcs:
			loop.state.campaign.residents[npc.id].talk_day=0
			loop.campaign_controller.show_resident(npc.id)
			for line in range(loop.hud.lines.size()-2,loop.hud.lines.size()):
				loop.hud.line_index=line
				loop.hud._show_line()
				loop.hud.dialogue_text.visible_characters=-1
				await frames(1)
				check("dialogue fits " + locale+" "+npc.id+str(line),loop.hud.dialogue_text.get_content_height()<=loop.hud.dialogue_text.size.y)
			loop.hud.close_modal()
			var affinity: int = loop.state.campaign.residents[npc.id].affinity
			loop.campaign_controller.show_resident(npc.id)
			check("repeat conversation stays concise "+locale+" "+npc.id,loop.hud.lines.size()==1 and loop.state.campaign.residents[npc.id].affinity==affinity)
			loop.hud.close_modal()
		loop.state.campaign.residents.mori.talk_day=0
		loop.campaign_controller.show_resident("mori")
		check("daily two-person exchange " + locale,loop.hud.lines.size()==3)
		loop.hud.line_index=1
		loop.hud._show_line()
		loop.hud.dialogue_text.visible_characters=-1
		check("integer portrait " + locale,loop.hud.dialogue_portrait.size==Vector2(64,64))
		await shot("dialogue_"+locale)
		loop.hud.line_index=2
		loop.hud._show_line()
		check("protagonist replies " + locale,loop.hud.dialogue_speaker.text==TranslationServer.translate(C.DEFAULT_PLAYER_NAME))
		loop.hud.close_modal()
		loop.state.materials=[7,5,3]
		loop.campaign_controller.open("食谱")
		await frames()
		check("recipe book contains real stock " + locale,loop.campaign_controller.list.get_child_count()>3)
		await shot("recipes_"+locale)
		loop.hud.close_modal()
		loop.campaign_controller.open("居民")
		await shot("residents_"+locale)
		loop.hud.close_modal()
	loop.enter("restaurant")
	loop.state = ready_state()
	loop.state.phase="night"
	loop.state.menu[0]=true
	loop.state.campaign.restaurant=0
	loop.state.remaining=State.NIGHT_SECONDS
	lane.player.position=loop.area.stations.kitchen
	loop._refresh()
	check("sold-out kitchen exposes existing close action",loop.end_button.visible and not loop.end_button.disabled)
	await shot("sold_out_service")
	await click(loop.end_button)
	check("real close action reaches settlement",loop.state.phase=="result" and loop.state.coins==0)
	Saves.active_slot=1
	Saves.created_at=int(Time.get_unix_time_from_system())
	check("isolated save writes",loop.save_progress().ok)
	var disk := Saves.read_slot(1)
	check("isolated save reads",disk.ok and not disk.get("empty",true))
	loop.state.phase="day"
	loop.state.campaign.chapter=10
	loop.enter("grove")
	var before: Dictionary = loop.state.to_save_data()
	loop.lane.viewport.get_node("SeasonalAtmosphere")._process(30.0)
	check("atmosphere never mutates gameplay",loop.state.to_save_data()==before)
	var report := {"checks":checks,"failures":failures,"capture":capture}
	var file:=FileAccess.open(OUT+("capture.json" if capture else "headless.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	Saves.end_session()
	lane.queue_free()
	await frames(4)
	await create_timer(0.2).timeout
	print("PROJECT POLISH COMPLETE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
