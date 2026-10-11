extends Node
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const I18n = preload("res://Localization/localized_text.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
const ResidentRoutines = preload("res://Scenes/Campaign/resident_routines.gd")
var loop
var tab := "故事"
var story_filter := "进行中"
var list: VBoxContainer
var actors: Array = []
var routines
var decor: Node2D
var decor_signature := ""
var decor_cell := 0
var entry_button: Button
var intro: Control
var naming: Control
var intro_image: TextureRect
var intro_title: Label
var intro_line: Label
var intro_elapsed := 0.0
var intro_index := -1
var intro_old_pause := false
var status: Label
var observed_day := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	entry_button = loop.hud.button("四季手记",Rect2(238,8,90,26),loop.hud.base,open)
	status = loop.hud.label("",Rect2(338,8,294,26),loop.hud.base,Color("fff0d5"))
	status.add_theme_color_override("font_shadow_color",Color("4d354e"))
	status.add_theme_constant_override("shadow_offset_x",1)
	status.add_theme_constant_override("shadow_offset_y",1)
	observed_day = loop.state.day
	_build_residents()
	Localization.language_changed.connect(func(_language):
		if loop.hud.mode == "campaign": open(tab))
	if C.pending_intro:
		C.pending_intro = false
		show_intro.call_deferred()
	elif preload("res://Scenes/Save/save_store.gd").active_slot > 0 and loop.state.campaign.introduced and loop.state.campaign.player_name.is_empty():
		# A closed window during naming resumes this step without replaying the film.
		_resume_naming.call_deferred()

func _process(delta: float) -> void:
	entry_button.visible = loop.state.phase != "result" and not opening_active()
	status.visible = entry_button.visible
	status.text = C.calendar(loop.state)+" · "+str(loop.state.coins)+" G"
	if is_instance_valid(intro):
		intro_elapsed += delta
		var index := mini(3, int(intro_elapsed / 6.0))
		if index != intro_index: _intro_slide(index)
		intro_image.position.x = -12 + fmod(intro_elapsed,6.0)*2
		intro_image.modulate.a = clampf(minf(fmod(intro_elapsed,6.0),6.0-fmod(intro_elapsed,6.0)),0.0,1.0)
		if intro_elapsed >= 24: finish_intro()
	if get_tree().paused: return
	if observed_day != loop.state.day:
		observed_day = loop.state.day
		if loop.state.campaign.introduced:
			loop.lane.weather.set_weather("snow" if C.season(loop.state)==3 and loop.state.day%3==0 else "rain" if loop.state.day%5==0 else "clear")
	routines.advance(delta)
	_update_decor()

func _build_residents() -> void:
	routines = ResidentRoutines.new()
	routines.configure(loop, C.D.npcs)
	actors = routines.actors

func try_interact() -> bool:
	if loop.location != "town" or loop.state.phase != "day": return false
	var actor = routines.nearest(loop.lane.player.position)
	if actor == null: return false
	show_resident(actor.resident_id)
	return true

func show_resident(id: String) -> void:
	var npc := C.entry(C.D.npcs,id)
	for actor in actors:
		if actor.resident_id == id:
			actor.face(loop.lane.player.position - actor.position)
			actor.pose(0.0, false)
	var dialogue_lines := C.talk(loop.state,id)
	var choices := [
		{"text":"赠礼", "action":func(): C.gift(loop.state,id); loop.hud.close_modal(); loop._show_feedback()},
		{"text":"继续", "action":loop.hud.close_modal}
	]
	if loop.state.campaign.side_active.has(id):
		choices.insert(1,{"text":"支线", "action":func(): loop.hud.close_modal(); story_filter="进行中"; open("故事")})
	loop.hud.start_dialogue(npc.name,"res://Art/Campaign/npcs/"+id+".png",dialogue_lines,choices)

func text(source: String) -> String:
	return tr(source)

func open(selected: String = "故事") -> void:
	if opening_active(): return
	if not loop.hud._begin_modal("campaign"): return
	tab = selected
	var book: Panel = loop.hud.panel(Rect2(20,16,600,328),loop.hud.modal)
	book.mouse_filter = Control.MOUSE_FILTER_STOP
	loop.hud.label("四季手记",Rect2(14,8,155,28),book,UISkin.INK,18)
	loop.hud.label(C.calendar(loop.state)+"   "+str(loop.state.coins)+" G",Rect2(173,8,380,28),book)
	loop.hud.button("×",Rect2(556,8,28,26),book,loop.hud.close_modal)
	var tabs := ["故事","种子","食谱","居民","探索","成长","仓储","家具"]
	for i in range(tabs.size()):
		var button: Button = loop.hud.button(tabs[i],Rect2(12+i*72,43,68,26),book,open.bind(tabs[i]))
		button.toggle_mode = true
		button.set_pressed_no_signal(tabs[i]==tab)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12,78)
	scroll.size = Vector2(576,238)
	book.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",6)
	if tab == "故事":
		for i in range(2):
			var title: String = ["进行中", "已完成"][i]
			var filter_button: Button = loop.hud.button(title, Rect2(12+i*112,78,108,24),book,func(): story_filter=title; open("故事"))
			filter_button.toggle_mode = true
			filter_button.set_pressed_no_signal(story_filter == title)
		scroll.position.y = 108
		scroll.size.y = 208
	scroll.add_child(list)
	match tab:
		"种子": _seeds()
		"食谱": _recipes()
		"居民": _residents()
		"探索": _regions()
		"成长": _upgrades()
		"仓储": _pantry()
		"家具": _furniture()
		_: _story()

func row(caption: String, icon_path: String = "") -> HBoxContainer:
	var box := HBoxContainer.new()
	var height: float = maxf(44.0,loop.font.get_multiline_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,310,12).y+10.0)
	box.custom_minimum_size = Vector2(554,height)
	list.add_child(box)
	if not icon_path.is_empty():
		var image := TextureRect.new()
		image.texture = load(icon_path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(36,36)
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(image)
	var label: Label = loop.hud.label(caption,Rect2(0,0,322,height),box)
	label.custom_minimum_size = Vector2(310,height)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return box

func action(box: HBoxContainer, caption: String, callback: Callable, enabled: bool = true) -> Button:
	var button: Button = loop.hud.button(caption,Rect2(0,0,72,36),box,callback)
	button.custom_minimum_size = Vector2(70,36)
	button.disabled = not enabled
	return button

func mutate(callback: Callable) -> void:
	callback.call()
	open(tab)

func cost_text(cost: Dictionary) -> String:
	var parts := []
	for id in cost:
		parts.append(text(C.D.items[id].name)+" "+str(loop.state.campaign.pantry[id])+"/"+str(cost[id]))
	return " · ".join(parts)

func _seeds() -> void:
	for crop in C.D.crops:
		var count: int = loop.state.farm.seeds if crop.id=="herb" else loop.state.campaign.seeds[crop.id]
		var seasons := []
		for index in crop.seasons: seasons.append(text(C.D.seasons[index]))
		var label: String = text(crop.name)+" ×"+str(count)+" · "+str(crop.buy)+" G\n"+"/".join(seasons)+" · "+str(crop.days)+"d"+(" ↻"+str(crop.regrow)+"d" if crop.regrow>0 else "")
		var box := row(label,"res://Art/Campaign/icons/seed_"+crop.id+".png")
		action(box,"已选" if loop.state.campaign.selected_crop==crop.id else "选用",func(): loop.state.campaign.selected_crop=crop.id; open(tab),loop.state.phase=="day")
		action(box,"购入",mutate.bind(func():
			if crop.id=="herb": loop.state.business_transaction("buy_seeds")
			else: C.buy_seed(loop.state,crop.id)),loop.state.phase=="day")
	if loop.location=="farm":
		var box := row(text("肥料")+" · 3 G")
		action(box,"施肥",mutate.bind(func(): C.fertilize(loop.state,loop.area.selected_tile())))

func _recipes() -> void:
	for index in range(C.D.recipes.size()):
		var recipe: Dictionary = C.D.recipes[index]
		var tags := []
		for id in recipe.tags: tags.append(text(C.D.tags[id]))
		var details: String = cost_text(recipe.cost) if index>=3 else text("厨房原料")
		var box := row(text(recipe.name)+" · "+str(recipe.price)+" G · "+text(C.D.stations[recipe.station])+"\n"+"/".join(tags)+" · "+details,"res://Art/Campaign/icons/dish_"+recipe.id+".png")
		var unlocked := C.unlocked(loop.state,index)
		action(box,"已上架" if loop.state.menu[index] else "未上架",mutate.bind(func():
			if loop.state.menu[index]: loop.state.menu[index]=false
			elif loop.state.menu.count(true)<C.restaurant(loop.state).menu: loop.state.menu[index]=true
			else: loop.state.message="菜单已满"),unlocked and loop.state.phase=="day")
		action(box,"料理",func(): loop.hud.close_modal(); loop.cook_dish(index),unlocked and loop.state.phase=="night" and loop.location=="restaurant" and loop.near(loop.area.stations.kitchen) and loop.state.menu[index] and loop.state.can_cook(index) and loop.state.cooking<0 and loop.state.held<0)

func _residents() -> void:
	for npc in C.D.npcs:
		if npc.id not in loop.state.campaign.met_residents: continue
		var r: Dictionary = loop.state.campaign.residents[npc.id]
		var title: String = text(npc.name)+" · "+str(npc.birthday[0]+1)+"/"+str(npc.birthday[1])+"\n"+(tr("好感 %d/1000 · 故事 %d/4") % [r.affinity,r.story])
		var box := row(title,"res://Art/Campaign/portraits/"+npc.id+"_portrait.png")
		action(box,"交谈",show_resident.bind(npc.id),loop.location=="town" and loop.state.phase=="day")
		if loop.state.campaign.side_active.has(npc.id):
			action(box,"支线",func(): open("故事"))
	if loop.state.campaign.met_residents.is_empty(): row(text("这里还没有手记。"))

func _regions() -> void:
	for region in C.D.regions:
		var unlocked: bool = loop.state.campaign.chapter >= region.chapter
		var labels := []
		for id in region.items: labels.append(text(C.D.items[id].name))
		var box := row(text(region.name)+"\n"+" · ".join(labels))
		action(box,"出发" if unlocked else "尚未开放",func(): loop.hud.close_modal(); loop.enter(region.id),unlocked and loop.state.phase=="day")
	for fish in C.D.fish:
		row(text(fish.name)+" · "+fish.area+" · "+str(fish.start)+"–"+str(fish.end)+"h · "+str(fish.difficulty)+" ★","res://Art/Campaign/icons/"+fish.id+".png")

func _upgrades() -> void:
	var restaurant := C.restaurant(loop.state)
	row(text(restaurant.name)+"\n"+(tr("容量 %d · 菜单 %d · 声望 %d") % [restaurant.seats,restaurant.menu,loop.state.campaign.reputation]))
	if loop.state.campaign.restaurant<4:
		var next: Dictionary = C.D.upgrades[loop.state.campaign.restaurant+1]
		var box := row(text(next.name)+" · "+str(next.coins)+" G\n"+cost_text({"wood":next.wood,"iron":next.iron}))
		action(box,"升级",mutate.bind(func(): C.upgrade(loop.state,"restaurant")),loop.location=="restaurant" and loop.state.phase=="day")
	for spec in [["rod","钓竿"],["sprinkler","自动洒水器"],["mill","磨粉机"],["hive","蜂箱"],["greenhouse","温室"]]:
		var rank: int = loop.state.campaign.rod if spec[0]=="rod" else loop.state.campaign.machines[spec[0]]
		var cost: Dictionary = {"wood":4+4*rank,"iron":1+2*rank} if spec[0]=="rod" else {"wood":40,"iron":10,"crystal":5} if spec[0]=="greenhouse" else {"wood":12,"iron":2,"scrap":3}
		var coins: int = 40*(rank+1) if spec[0]=="rod" else 450 if spec[0]=="greenhouse" else 70
		var box := row(text(spec[1])+" "+str(rank)+" · "+str(coins)+" G\n"+cost_text(cost),"res://Art/Campaign/icons/"+spec[0]+".png")
		action(box,"升级",mutate.bind(func(): C.upgrade(loop.state,spec[0])),loop.state.phase=="day")
	var box := row(text("资源入库"))
	# Existing backpack resources can be committed to construction storage, and withdrawn below.
	action(box,"资源入库",mutate.bind(func(): C.import_resources(loop.state)),loop.state.phase=="day")
	var smelt := row(text("熔炼")+" · "+cost_text({"ore":2,"wood":1}))
	action(smelt,"熔炼",mutate.bind(func(): C.upgrade(loop.state,"smelt")),loop.state.phase=="day" and loop.location=="blacksmith")

func _pantry() -> void:
	for id in C.D.items:
		var item: Dictionary = C.D.items[id]
		var box := row(text(item.name)+" ×"+str(loop.state.campaign.pantry[id])+" · "+str(item.sell)+" G","res://Art/Campaign/icons/"+id+".png")
		action(box,"售出",mutate.bind(func(): C.trade(loop.state,id,false)),loop.location=="store" and loop.state.phase=="day" and loop.state.campaign.pantry[id]>0)
		if id in ["egg","milk","flour","oil","salt","rice","wheat"]:
			action(box,"购入",mutate.bind(func(): C.trade(loop.state,id,true)),loop.location=="store" and loop.state.phase=="day")
		elif id in ["wood","ore","iron"]:
			action(box,"取出",mutate.bind(func():
				if loop.state.campaign.pantry[id]>0 and loop.state.Items.change(loop.state,{id:1}): C.add(loop.state,id,-1)),loop.state.phase=="day")

func _furniture() -> void:
	var box := row(text("布置")+" · "+str(decor_cell+1)+" / 8")
	action(box,"−",func(): decor_cell=(decor_cell+7)%8; open(tab))
	action(box,"+",func(): decor_cell=(decor_cell+1)%8; open(tab))
	for item in C.D.furniture:
		var box2 := row(text(item.name)+" ×"+str(loop.state.campaign.stock[item.id])+" · ♥"+str(item.comfort)+"\n"+cost_text({"wood":item.wood,"iron":item.iron}),"res://Art/Campaign/furniture/"+item.id+".png")
		action(box2,"制作",mutate.bind(func(): C.craft(loop.state,item.id)),loop.state.phase=="day")
		action(box2,"摆放",mutate.bind(func(): C.decorate(loop.state,item.id,loop.location,decor_cell)),loop.location in ["home","restaurant"] and loop.state.phase=="day")

func _story() -> void:
	if story_filter == "已完成":
		for index in range(loop.state.campaign.chapter):
			var q: Dictionary = C.D.quests[index]
			row(text("主线")+" · "+text(q.name)+"\n"+text(q.description))
		for npc in C.D.npcs:
			for stage in range(loop.state.campaign.residents[npc.id].story):
				row(text("支线")+" · "+text(npc.stories[stage])+"\n"+text(npc.events[stage]),"res://Art/Campaign/portraits/"+npc.id+"_portrait.png")
		if list.get_child_count() == 0: row(text("这里还没有手记。"))
		return
	var q := C.current_main(loop.state)
	if not q.is_empty():
		var progress: int = mini(q.goal,C.metric(loop.state,q.metric))
		var box := row(text("主线")+" · "+text(q.name)+" · "+text(q.objective)+"\n"+(tr("目标 %d/%d · 奖励 %d金") % [progress,q.goal,q.reward]))
		box.name = "MainQuest"
		action(box,"完成",complete_chapter,progress>=q.goal)
	for id in loop.state.campaign.side_active:
		var npc := C.entry(C.D.npcs,id)
		var stage: int = loop.state.campaign.side_active[id]
		var r: Dictionary = loop.state.campaign.residents[id]
		var caption: String = text("支线")+" · "+text(npc.stories[stage])+"\n"+(tr("好感 %d/%d · 奖励 %d金") % [mini(r.affinity,(stage+1)*200),(stage+1)*200,25*(stage+1)])+"\n"+cost_text({npc.gift:stage+1})
		var box := row(caption,"res://Art/Campaign/portraits/"+id+"_portrait.png")
		box.name = "SideQuest_"+id
		action(box,"完成",complete_side.bind(id),C.side_ready(loop.state,id) and loop.location=="town")
	if q.is_empty() and loop.state.campaign.side_active.is_empty(): row(text("这里还没有手记。"))
	if not C.festival(loop.state).is_empty():
		var box := row(text("今日庆典")+" · "+text(C.festival(loop.state)))
		action(box,"灯会纪念",mutate.bind(func(): C.celebrate(loop.state)),loop.state.phase=="day")

func complete_side(id: String) -> void:
	if loop.location != "town" or not C.story(loop.state,id): return
	var npc := C.entry(C.D.npcs,id)
	var stage: int = loop.state.campaign.residents[id].story - 1
	loop._autosave()
	loop.hud.start_dialogue(npc.name,"res://Art/Campaign/npcs/"+id+".png",[npc.stories[stage],npc.events[stage]])

func complete_chapter() -> void:
	var chapter: int = loop.state.campaign.chapter
	if C.complete_chapter(loop.state):
		loop._autosave()
		loop.hud.start_dialogue(C.D.npcs[9].name,"res://Art/Campaign/npcs/orla.png",[C.D.quests[chapter].name,C.D.quests[chapter].description])
	else: open(tab)

func _update_decor() -> void:
	var signature: String = loop.location+JSON.stringify(loop.state.campaign.placed)
	if signature==decor_signature and is_instance_valid(decor) and decor.is_inside_tree(): return
	decor_signature = signature
	if is_instance_valid(decor): decor.queue_free()
	decor = null
	if loop.location not in ["home","restaurant"]: return
	decor = Node2D.new()
	decor.name = "CampaignFurniture"
	Depth.sortable_group(decor)
	loop.area.add_child(decor)
	for item in loop.state.campaign.placed:
		if item.room!=loop.location: continue
		var sprite := Sprite2D.new()
		sprite.texture = load("res://Art/Campaign/furniture/"+item.id+".png")
		sprite.name = "Decor_"+item.id+"_"+str(item.cell)
		Depth.feet_sprite(sprite,Vector2(50+(item.cell%4)*94,92+(item.cell/4)*54),64)
		sprite.scale = Vector2(0.5,0.5)
		if C.entry(C.D.furniture,item.id).shape == "rug": sprite.z_index = Depth.FLOOR_DECOR
		decor.add_child(sprite)

func show_intro() -> void:
	if opening_active(): return
	intro_old_pause = get_tree().paused
	get_tree().paused = true
	intro_elapsed = 0.0
	intro_index = -1
	intro = Control.new()
	intro.size = Vector2(640,360)
	intro.mouse_filter = Control.MOUSE_FILTER_STOP
	loop.hud.layer.add_child(intro)
	var black := ColorRect.new()
	black.color = Color("272333")
	black.size = intro.size
	intro.add_child(black)
	intro_image = TextureRect.new()
	intro_image.position = Vector2(-12,0)
	intro_image.size = Vector2(664,360)
	intro_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intro_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	intro.add_child(intro_image)
	var shade := ColorRect.new()
	shade.position = Vector2(0,220)
	shade.size = Vector2(640,140)
	shade.color = Color(0.12,0.08,0.17,0.85)
	intro.add_child(shade)
	intro_title = loop.hud.label("",Rect2(32,232,576,34),intro,Color("fff0d5"),24)
	intro_line = loop.hud.label("",Rect2(32,274,570,64),intro,Color("fff0d5"))
	intro_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loop.hud.button("略过",Rect2(554,12,66,26),intro,finish_intro)
	_intro_slide(0)

func _intro_slide(index: int) -> void:
	intro_index = index
	intro_title.text = C.D.intro[index].title
	intro_line.text = C.D.intro[index].line
	intro_image.texture = load(["res://Art/Campaign/maps/observatory.png","res://Art/Environment/Hearthwood/town_overview.png","res://Art/Environment/Hearthwood/restaurant_background.png","res://Art/Environment/Hearthwood/farm_overview.png"][index])

func finish_intro() -> void:
	if not is_instance_valid(intro): return
	intro.hide()
	intro.queue_free()
	intro = null
	loop.state.campaign.introduced = true
	loop._autosave()
	if loop.state.campaign.player_name.is_empty():
		_show_naming()
	else:
		get_tree().paused = intro_old_pause

func opening_active() -> bool:
	return is_instance_valid(intro) or is_instance_valid(naming)

func _resume_naming() -> void:
	if opening_active(): return
	intro_old_pause = get_tree().paused
	get_tree().paused = true
	_show_naming()

func _show_naming() -> void:
	naming = preload("res://Scenes/Campaign/player_naming.gd").new()
	naming.audio = loop.audio
	naming.confirmed.connect(_complete_naming)
	loop.hud.layer.add_child(naming)

func _complete_naming(player_name: String) -> void:
	if not is_instance_valid(naming) or not C.choose_player_name(loop.state, player_name): return
	if preload("res://Scenes/Save/save_store.gd").active_slot > 0:
		var result: Dictionary = loop.save_progress()
		if not result.ok:
			loop.state.campaign.player_name = ""
			naming.show_save_error(result.get("code", "invalid"))
			return
	loop.audio.play_event("ui_confirm")
	naming.hide()
	naming.queue_free()
	naming = null
	get_tree().paused = intro_old_pause

func _exit_tree() -> void:
	if opening_active(): get_tree().paused = intro_old_pause
	if is_instance_valid(decor) and not decor.is_inside_tree(): decor.free()
