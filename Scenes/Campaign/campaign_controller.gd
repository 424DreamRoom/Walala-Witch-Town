extends Node
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const I18n = preload("res://Localization/localized_text.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
const ResidentRoutines = preload("res://Scenes/Campaign/resident_routines.gd")
const FoodIcons = preload("res://Scenes/UI/food_icons.gd")
const Guide = preload("res://Scenes/Campaign/guide_profile.gd")
var loop
var tab := "故事"
var story_filter := "进行中"
var recipe_query := ""
var pantry_query := ""
var recipe_category := ""
var pantry_category := ""
var list: VBoxContainer
var actors: Array = []
var guide
var routines
var decor: Node2D
var decor_signature := ""
var decor_cell := 0
var intro: Control
var intro_image: TextureRect
var intro_title: Label
var intro_line: Label
var intro_elapsed := 0.0
var intro_index := -1
var intro_old_pause := false
var observed_day := 0
const ARRIVAL_PATH := [Vector2(600,324), Vector2(270,324), Vector2(270,294)]
const ARRIVAL_SPEED := 80.0
var arrival_actor
var arrival_active := false
var arrival_dialogue := false
var arrival_departing := false
var arrival_path := PackedVector2Array()
var arrival_old_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	observed_day = loop.state.day
	_build_residents()
	Localization.language_changed.connect(func(_language):
		if loop.hud.mode == "campaign": open(tab))
	if C.pending_intro:
		C.pending_intro = false
		show_intro.call_deferred()
	elif loop.state.campaign.introduced and not loop.state.campaign.guide_met:
		_start_arrival.call_deferred()

func _process(delta: float) -> void:
	if SceneTransition.active: return
	guide.sync(loop.state.phase == "day")
	if is_instance_valid(intro):
		intro_elapsed += delta
		var index := mini(3, int(intro_elapsed / 6.0))
		if index != intro_index: _intro_slide(index)
		intro_image.position.x = -12 + fmod(intro_elapsed,6.0)*2
		intro_image.modulate.a = clampf(minf(fmod(intro_elapsed,6.0),6.0-fmod(intro_elapsed,6.0)),0.0,1.0)
		if intro_elapsed >= 24: finish_intro()
	if arrival_active:
		if _walk_arrival(delta): _finish_arrival()
		return
	if arrival_dialogue and loop.hud.mode != "dialogue":
		arrival_dialogue = false
		_restore_arrival_camera()
		arrival_path = PackedVector2Array([Vector2(270,324), Vector2(680,324)])
		arrival_departing = true
	if get_tree().paused: return
	if arrival_departing:
		if not is_instance_valid(arrival_actor):
			arrival_departing = false
		elif _walk_arrival(delta, true):
			arrival_actor.queue_free()
			arrival_actor = null
			arrival_departing = false
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
	guide = preload("res://Scenes/Campaign/guide_actor.gd").new()
	guide.position = routines.safe_point(Vector2(464,408))
	loop.lane.actors.add_child(guide)
	guide.sync(loop.state.phase == "day")
	routines.visitors.append(guide)

func try_interact() -> bool:
	if loop.location != "town" or loop.state.phase != "day": return false
	var actor = routines.nearest(loop.lane.player.position)
	if guide.visible and loop.near(guide.position) and (actor == null or loop.lane.player.position.distance_to(guide.position) <= loop.lane.player.position.distance_to(actor.position)):
		show_guide()
		return true
	if actor == null: return false
	show_resident(actor.resident_id)
	return true

func show_guide(welcome: bool = false) -> void:
	if opening_active() or loop.state.phase == "result": return
	var dialogue_lines: Array = Guide.WELCOME.duplicate() if welcome else []
	var chapter: int = loop.state.campaign.chapter
	dialogue_lines.append(Guide.CHAPTERS[chapter] if chapter < Guide.CHAPTERS.size() else Guide.FAREWELL)
	_guide_dialogue(dialogue_lines)
	if loop.hud.mode == "dialogue": loop.state.campaign.guide_met = true

func _guide_choices() -> Array:
	var choices := [
		{"text": "当前目标", "action": show_guide_goal},
		{"text": "小镇生活", "action": show_guide_topics},
		{"text": "再会", "action": loop.hud.close_modal}
	]
	if Guide.ready(loop.state): choices.insert(0, {"text": "完成", "action": _complete_guide_chapter.bind(loop.state.campaign.chapter)})
	return choices

func _guide_dialogue(dialogue_lines: Array, choices: Array = []) -> void:
	loop.hud.start_dialogue(Guide.NAME, Guide.PORTRAIT, dialogue_lines, _guide_choices() if choices.is_empty() else choices, Rect2())

func show_guide_goal() -> void:
	_guide_dialogue(Guide.current_lines(loop.state))

func show_guide_topics(page: int = 0) -> void:
	var available := []
	for topic in Guide.TOPICS:
		if loop.state.campaign.chapter >= topic.chapter: available.append(topic)
	var choices := []
	var pages := ceili(available.size() / 2.0)
	page = posmod(page, pages)
	for index in range(page * 2, mini(page * 2 + 2, available.size())):
		var topic: Dictionary = available[index]
		choices.append({"text": topic.name, "action": _guide_dialogue.bind(topic.lines)})
	if pages > 1: choices.append({"text": "其他话题", "action": show_guide_topics.bind((page + 1) % pages)})
	choices.append({"text": "再会", "action": loop.hud.close_modal})
	_guide_dialogue(["手记里除了远方的故事，还有小镇每天的烟火。"], choices)

func _complete_guide_chapter(expected_chapter: int) -> void:
	# Bind the chapter shown in this conversation: stale choices cannot pay twice.
	if loop.state.campaign.chapter != expected_chapter:
		show_guide_goal()
		return
	var q := C.current_main(loop.state)
	if not C.complete_chapter(loop.state):
		show_guide_goal()
		return
	loop._autosave()
	var dialogue_lines: Array = [q.name, q.description]
	dialogue_lines.append_array(Guide.current_lines(loop.state))
	_guide_dialogue(dialogue_lines)

func show_resident(id: String) -> void:
	var npc := C.entry(C.D.npcs,id)
	for actor in actors:
		if actor.resident_id == id:
			actor.face(loop.lane.player.position - actor.position)
			actor.pose(0.0, false)
	var dialogue_lines := C.talk(loop.state,id)
	loop._autosave()
	var choices := [
		{"text":"赠礼", "action":func(): C.gift(loop.state,id); loop.hud.close_modal(); loop._show_feedback()},
		{"text":"继续", "action":loop.hud.close_modal}
	]
	if loop.state.campaign.side_active.has(id):
		choices.insert(1,{"text":"支线", "action":func(): loop.hud.close_modal(); story_filter="进行中"; open("故事")})
	loop.hud.start_dialogue(npc.name,"res://Art/Characters/NPC32/portraits/"+id+".aseprite",dialogue_lines,choices,Rect2(0,0,32,32))

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
	if tab in ["食谱", "仓储"]:
		scroll.position.y = 108
		scroll.size.y = 208
		_food_filters(book)
	match tab:
		"种子": _seeds()
		"食谱": _recipes()
		"居民": _residents()
		"探索": _regions()
		"成长": _upgrades()
		"仓储": _pantry()
		"家具": _furniture()
		_: _story()

func _food_filters(book: Panel) -> void:
	var search := LineEdit.new()
	search.position = Vector2(12,78)
	search.size = Vector2(318,24)
	search.placeholder_text = text("搜索")
	search.text = recipe_query if tab == "食谱" else pantry_query
	book.add_child(search)
	search.text_changed.connect(func(value: String):
		if tab == "食谱": recipe_query = value
		else: pantry_query = value
		_refresh_food_list())
	var categories: Dictionary = C.D.recipe_categories if tab == "食谱" else C.D.ingredient_categories
	var ids: Array = [""] + categories.keys()
	if tab == "仓储": ids.append("resource")
	var filter := OptionButton.new()
	filter.position = Vector2(338,78)
	filter.size = Vector2(250,24)
	book.add_child(filter)
	for id in ids:
		filter.add_item(text("全部" if id == "" else "资源" if id == "resource" else categories[id]))
	filter.select(ids.find(recipe_category if tab == "食谱" else pantry_category))
	filter.item_selected.connect(func(index: int):
		if tab == "食谱": recipe_category = ids[index]
		else: pantry_category = ids[index]
		_refresh_food_list())

func _refresh_food_list() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	list.get_parent().get_v_scroll_bar().value = 0
	if tab == "食谱": _recipes()
	else: _pantry()

func _food_matches(item: Dictionary, query: String, category: String) -> bool:
	if not category.is_empty() and item.get("category", "") != category: return false
	query = query.strip_edges().to_lower()
	if query.is_empty(): return true
	if query in text(item.name).to_lower() or query in item.name.to_lower(): return true
	for id in item.get("cost", {}):
		if query in text(C.D.items[id].name).to_lower() or query in C.D.items[id].name.to_lower(): return true
	return false

func row(caption: String, icon_path: String = "") -> HBoxContainer:
	var box := HBoxContainer.new()
	var height: float = maxf(44.0,loop.font.get_multiline_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,310,12).y+10.0)
	box.custom_minimum_size = Vector2(554,height)
	list.add_child(box)
	if not icon_path.is_empty():
		var image := TextureRect.new()
		image.texture = FoodIcons.from_path(icon_path)
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

func action(box: HBoxContainer, caption: String, callback: Callable, enabled: bool = true, width: float = 70.0) -> Button:
	var button: Button = loop.hud.button(caption,Rect2(0,0,72,36),box,callback)
	button.custom_minimum_size = Vector2(width,36)
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
		var box := row(label,"res://Art/Campaign/icons/seed_"+crop.id+".aseprite")
		action(box,"已选" if loop.state.campaign.selected_crop==crop.id else "选用",func(): loop.state.campaign.selected_crop=crop.id; open(tab),loop.state.phase=="day")
		action(box,"购入",mutate.bind(func():
			if crop.id=="herb": loop.state.business_transaction("buy_seeds")
			else: C.buy_seed(loop.state,crop.id)),loop.state.phase=="day")
	if loop.location=="farm":
		var box := row(text("肥料")+" · 3 G")
		action(box,"施肥",mutate.bind(func(): C.fertilize(loop.state,loop.area.selected_tile())))

func _recipes() -> void:
	row(I18n.format("今日菜单 %d/%d", [loop.state.menu.count(true), C.restaurant(loop.state).menu]) + " · 18:00–22:00")
	for index in range(C.D.recipes.size()):
		var recipe: Dictionary = C.D.recipes[index]
		if not _food_matches(recipe, recipe_query, recipe_category): continue
		var tags := []
		for id in recipe.tags: tags.append(text(C.D.tags[id]))
		var details: String = cost_text(recipe.cost) if index>=3 else text("厨房原料")
		var box := row(text(recipe.name)+" · "+str(recipe.price)+" G · "+text(C.D.stations[recipe.station])+"\n"+"/".join(tags)+" · "+details,"res://Art/Campaign/icons/dish_"+recipe.id+".aseprite")
		var unlocked := C.unlocked(loop.state,index)
		action(box,"已上架" if loop.state.menu[index] else "未上架",mutate.bind(func():
			loop.state.set_menu_dish(index, not loop.state.menu[index])),unlocked and loop.state.phase=="day",88)
		action(box,"料理",func(): loop.hud.close_modal(); loop.cook_dish(index),unlocked and loop.state.phase=="night" and loop.location=="restaurant" and loop.near(loop.area.stations.kitchen) and loop.state.menu[index] and loop.state.can_cook(index) and loop.state.cooking<0 and loop.state.held<0,88)

func _residents() -> void:
	for npc in C.D.npcs:
		if npc.id not in loop.state.campaign.met_residents: continue
		var r: Dictionary = loop.state.campaign.residents[npc.id]
		var title: String = text(npc.name)+" · "+str(npc.birthday[0]+1)+"/"+str(npc.birthday[1])+"\n"+(tr("好感 %d/1000 · 故事 %d/4") % [r.affinity,r.story])
		var box := row(title,"res://Art/Characters/NPC32/portraits/"+npc.id+".aseprite")
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
		action(box,"出发" if unlocked else "尚未开放",func(): loop.hud.close_modal(); loop.travel(region.id),unlocked and loop.state.phase=="day")
	for fish in C.D.fish:
		row(text(fish.name)+" · "+fish.area+" · "+str(fish.start)+"–"+str(fish.end)+"h · "+str(fish.difficulty)+" ★","res://Art/Campaign/icons/"+fish.id+".aseprite")

func _upgrades() -> void:
	var restaurant := C.restaurant(loop.state)
	row(text(restaurant.name)+"\n"+(tr("容量 %d · 菜单 %d · 声望 %d") % [restaurant.seats,restaurant.menu,loop.state.campaign.reputation]))
	if loop.state.campaign.restaurant<4:
		var next: Dictionary = C.D.upgrades[loop.state.campaign.restaurant+1]
		var box := row(text(next.name)+" · "+str(next.coins)+" G\n"+cost_text({"wood":next.wood,"iron":next.iron}))
		action(box,"升级",mutate.bind(func(): C.upgrade(loop.state,"restaurant")),loop.location=="restaurant" and loop.state.phase=="day")
	for spec in [["sprinkler","自动洒水器"],["mill","磨粉机"],["hive","蜂箱"],["greenhouse","温室"]]:
		var rank: int = loop.state.campaign.machines[spec[0]]
		var cost: Dictionary = {"wood":40,"iron":10,"crystal":5} if spec[0]=="greenhouse" else {"wood":12,"iron":2,"scrap":3}
		var coins: int = 450 if spec[0]=="greenhouse" else 70
		var box := row(text(spec[1])+" "+str(rank)+" · "+str(coins)+" G\n"+cost_text(cost),"res://Art/Campaign/icons/"+spec[0]+".aseprite")
		action(box,"升级",mutate.bind(func(): C.upgrade(loop.state,spec[0])),loop.state.phase=="day")
	var box := row(text("资源入库"))
	# Existing backpack resources can be committed to construction storage, and withdrawn below.
	action(box,"资源入库",mutate.bind(func(): C.import_resources(loop.state)),loop.state.phase=="day")
	var smelt := row(text("熔炼")+" · "+cost_text({"ore":2,"wood":1}))
	action(smelt,"熔炼",mutate.bind(func(): C.upgrade(loop.state,"smelt")),loop.state.phase=="day" and loop.location=="blacksmith")

func _pantry() -> void:
	for id in C.D.items:
		var item: Dictionary = C.D.items[id]
		if not _food_matches(item, pantry_query, pantry_category): continue
		var prices: String = text("售出")+" "+str(item.sell)+" G"
		if item.get("shop", false): prices += " · "+text("购入")+" "+str(item.buy)+" G"
		var box := row(text(item.name)+" ×"+str(loop.state.campaign.pantry[id])+"\n"+prices,"res://Art/Campaign/icons/"+id+".aseprite")
		action(box,"售出",mutate.bind(func(): C.trade(loop.state,id,false)),loop.location=="store" and loop.state.phase=="day" and loop.state.campaign.pantry[id]>0)
		if item.get("shop", false):
			action(box,"购入",mutate.bind(func(): C.trade(loop.state,id,true)),loop.location=="store" and loop.state.phase=="day")
		elif id in ["wood","ore","iron"]:
			action(box,"取出",mutate.bind(func():
				if loop.state.campaign.pantry[id]>0 and loop.state.Items.change(loop.state,{id:1}): C.add(loop.state,id,-1)),loop.state.phase=="day")

func _furniture() -> void:
	var box := row(text("布置")+" · "+str(decor_cell+1)+" / 8")
	action(box,"−",func(): decor_cell=(decor_cell+7)%8; open(tab))
	action(box,"+",func(): decor_cell=(decor_cell+1)%8; open(tab))
	for item in C.D.furniture:
		var box2 := row(text(item.name)+" ×"+str(loop.state.campaign.stock[item.id])+" · ♥"+str(item.comfort)+"\n"+cost_text({"wood":item.wood,"iron":item.iron}),"res://Art/Campaign/furniture/"+item.id+".aseprite")
		action(box2,"制作",mutate.bind(func(): C.craft(loop.state,item.id)),loop.state.phase=="day")
		action(box2,"摆放",mutate.bind(func(): C.decorate(loop.state,item.id,loop.location,decor_cell)),loop.location in ["home","restaurant"] and loop.state.phase=="day")

func _story() -> void:
	if story_filter == "已完成":
		for index in range(loop.state.campaign.chapter):
			var q: Dictionary = C.D.quests[index]
			row(text("主线")+" · "+text(q.name)+"\n"+text(q.description))
		for npc in C.D.npcs:
			for stage in range(loop.state.campaign.residents[npc.id].story):
				row(text("支线")+" · "+text(npc.stories[stage])+"\n"+text(npc.events[stage]),"res://Art/Characters/NPC32/portraits/"+npc.id+".aseprite")
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
		var box := row(caption,"res://Art/Characters/NPC32/portraits/"+id+".aseprite")
		box.name = "SideQuest_"+id
		action(box,"完成",complete_side.bind(id),C.side_ready(loop.state,id) and loop.location=="town")
		action(box,"暂缓",mutate.bind(func(): C.defer_side(loop.state,id); loop._autosave()))
	if q.is_empty() and loop.state.campaign.side_active.is_empty(): row(text("这里还没有手记。"))
	if not C.festival(loop.state).is_empty():
		var box := row(text("今日庆典")+" · "+text(C.festival(loop.state)))
		action(box,"灯会纪念",mutate.bind(func(): C.celebrate(loop.state)),loop.state.phase=="day")

func complete_side(id: String) -> void:
	if loop.location != "town" or not C.story(loop.state,id): return
	var npc := C.entry(C.D.npcs,id)
	var stage: int = loop.state.campaign.residents[id].story - 1
	loop._autosave()
	loop.hud.start_dialogue(npc.name,"res://Art/Characters/NPC32/portraits/"+id+".aseprite",[npc.stories[stage],npc.events[stage]],[],Rect2(0,0,32,32))

func complete_chapter() -> void:
	_complete_guide_chapter(loop.state.campaign.chapter)

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
		sprite.texture = load("res://Art/Campaign/furniture/"+item.id+".aseprite")
		sprite.name = "Decor_"+item.id+"_"+str(item.cell)
		Depth.feet_sprite(sprite,Vector2(50+(item.cell%4)*94,92+(item.cell/4)*54),64)
		if loop.location == "home" and not loop.state.furniture.legacy_fixtures:
			var floor := preload("res://Scenes/Building/house_catalog.gd").floor_for(loop.state.furniture)
			sprite.position = (floor.position + Vector2(32 + (item.cell % 4) * (floor.size.x - 64) / 3.0, 32 if item.cell < 4 else floor.size.y - 64)).round()
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
	var skip: Button = loop.hud.button("略过",Rect2(554,12,66,26),intro,finish_intro)
	skip.grab_focus()
	_intro_slide(0)

func _intro_slide(index: int) -> void:
	intro_index = index
	intro_title.text = C.D.intro[index].title
	intro_line.text = C.D.intro[index].line
	intro_image.texture = load(["res://Art/Campaign/maps/observatory.aseprite","res://Art/Environment/Hearthwood/town_overview.aseprite","res://Art/Environment/Hearthwood/restaurant_background.aseprite","res://Art/Environment/Hearthwood/farm_overview.aseprite"][index])

func finish_intro() -> void:
	if not is_instance_valid(intro): return
	intro.hide()
	intro.queue_free()
	intro = null
	loop.state.campaign.introduced = true
	loop._autosave()
	get_tree().paused = intro_old_pause
	_start_arrival()

func opening_active() -> bool:
	return is_instance_valid(intro) or arrival_active

func _start_arrival() -> void:
	if opening_active() or loop.state.campaign.guide_met: return
	arrival_old_pause = get_tree().paused
	get_tree().paused = true
	loop.enter_home_doorstep()
	loop.audio.reset_footsteps()
	arrival_actor = preload("res://Scenes/Campaign/guide_actor.gd").new()
	arrival_actor.name = "Opening_Yingluo"
	arrival_actor.position = ARRIVAL_PATH[0]
	loop.area.add_child(arrival_actor)
	arrival_path = PackedVector2Array(ARRIVAL_PATH.slice(1))
	arrival_active = true
	# Frame both characters above the existing dialogue panel.
	loop.lane.camera.position = Vector2(0,64)
	loop.lane.camera.reset_smoothing()
	loop.lane.camera.force_update_scroll()

func _walk_arrival(delta: float, avoid_player: bool = false) -> bool:
	var distance := ARRIVAL_SPEED * maxf(0.0, delta)
	var moving := false
	while distance > 0.0 and not arrival_path.is_empty():
		var start: Vector2 = arrival_actor.position
		var target: Vector2 = arrival_path[0]
		var next := start.move_toward(target, distance)
		if avoid_player and preload("res://Scenes/Gameplay/actor_collision.gd").blocks_motion(start, next, loop.lane.player.position): break
		distance -= start.distance_to(next)
		moving = moving or next != start
		arrival_actor.position = next
		if next == target:
			arrival_path.remove_at(0)
		else:
			# The step consumed the budget; tiny float remainders cannot advance
			# a world coordinate and must not spin in this loop.
			break
	arrival_actor.pose_walk(delta, moving and not arrival_path.is_empty())
	return arrival_path.is_empty()

func _finish_arrival() -> void:
	arrival_active = false
	get_tree().paused = arrival_old_pause
	show_guide(true)
	arrival_dialogue = loop.hud.mode == "dialogue"
	if not arrival_dialogue: _restore_arrival_camera()

func _restore_arrival_camera() -> void:
	loop.lane.camera.position = Vector2.ZERO
	loop.lane.camera.reset_smoothing()
	loop.lane.camera.force_update_scroll()

func _exit_tree() -> void:
	if arrival_active: get_tree().paused = arrival_old_pause
	elif opening_active(): get_tree().paused = intro_old_pause
	if is_instance_valid(decor) and not decor.is_inside_tree(): decor.free()
