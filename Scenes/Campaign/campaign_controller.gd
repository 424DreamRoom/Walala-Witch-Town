extends Node
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const I18n = preload("res://Localization/localized_text.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
const ResidentRoutines = preload("res://Scenes/Campaign/resident_routines.gd")
const FoodIcons = preload("res://Scenes/UI/food_icons.gd")
const Guide = preload("res://Scenes/Campaign/guide_profile.gd")
const OpeningFilm = preload("res://Scenes/Campaign/opening_film.gd")
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
var intro_film
var intro_title: Label
var intro_line: Label
var intro_elapsed := 0.0
var intro_index := -1
var intro_old_pause := false
var opening_dialogue_allowed := false
var opening_transition_active := false
var opening_cast: Array[Node2D] = []
var observed_day := 0
const ARRIVAL_PATH := [Vector2(600,324), Vector2(270,324), Vector2(270,294)]
const ARRIVAL_SPEED := 80.0
var arrival_actor
var arrival_active := false

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
		_start_opening_stage.call_deferred()
	elif loop.state.campaign.pending_scene >= 0:
		_resume_story.call_deferred()

func _process(delta: float) -> void:
	if SceneTransition.active or opening_transition_active: return
	guide.sync(loop.state.phase == "day")
	if is_instance_valid(intro):
		intro_elapsed += delta
		if intro_elapsed >= intro_length(): finish_intro()
		else: _render_intro()
	if not is_instance_valid(intro) and loop.state.campaign.introduced and not loop.state.campaign.guide_met and loop.hud.mode.is_empty():
		_start_opening_stage()
		return
	if get_tree().paused: return
	if observed_day != loop.state.day:
		observed_day = loop.state.day
		if loop.state.campaign.introduced:
			# The loop can sync yesterday's visible weather before this controller
			# sees the new day. Derive the transition from the shared forecast rule.
			var weather: String = loop.state.SeasonalDirector.pulse_for_day(loop.state.day).weather
			loop.lane.weather.set_weather(weather)
			loop.state.sync_weather(weather)
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
	if loop.state.campaign.pending_scene >= 0:
		_resume_story()
		return
	var dialogue_lines: Array = []
	dialogue_lines.append_array(Guide.current_lines(loop.state))
	_guide_dialogue(dialogue_lines)

func _guide_choices() -> Array:
	if loop.state.is_arrival_day():
		return [{"text": "当前目标", "action": show_guide_goal}, {"text": "再会", "action": loop.hud.close_modal}]
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
	if loop.state.campaign.pending_scene >= 0:
		_resume_story()
		return
	# Bind the chapter shown in this conversation: stale choices cannot pay twice.
	if loop.state.campaign.chapter != expected_chapter:
		show_guide_goal()
		return
	if not C.complete_chapter(loop.state):
		show_guide_goal()
		return
	_save_story_checkpoint()
	_resume_story()

func _save_story_checkpoint() -> void:
	# Story boundaries must survive a quit inside a paused conversation. Regular
	# gameplay keeps its existing six-hour autosave schedule.
	if loop.restoring_save or loop.Saves.active_slot == 0: return
	var result: Dictionary = loop.save_progress()
	if not result.ok: loop.save_menu.report_save(result, true)

func _resume_story() -> void:
	var index: int = loop.state.campaign.pending_scene
	if index < 0 or index >= C.D.quests.size(): return
	_guide_dialogue(_chapter_lines(C.D.quests[index]), [{"text": "继续", "action": _finish_story.bind(index)}])

func _finish_story(expected: int) -> void:
	if loop.state.campaign.pending_scene != expected: return
	loop.state.campaign.pending_scene = -1
	_save_story_checkpoint()
	_guide_dialogue(Guide.current_lines(loop.state))

func _chapter_lines(q: Dictionary) -> Array:
	return _beat_lines(q.dialogue)

func _beat_lines(beats: Array) -> Array:
	var dialogue_lines: Array = []
	for beat in beats:
		var speaker: String = loop.state.campaign.player_name if beat.speaker == "player" else Guide.NAME if beat.speaker == "yingluo" else C.entry(C.D.npcs, beat.speaker).name
		var portrait: String = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd").SHEET if beat.speaker == "player" else Guide.PORTRAIT if beat.speaker == "yingluo" else "res://Art/Characters/NPC32/portraits/" + beat.speaker + ".aseprite"
		var region := Rect2(0,0,32,32)
		if beat.speaker == "yingluo": region = Rect2()
		dialogue_lines.append({"source": beat.text, "args": [], "speaker": speaker, "translate_speaker": beat.speaker != "player" or speaker == C.DEFAULT_PLAYER_NAME, "portrait": portrait, "portrait_region": region})
	return dialogue_lines

func _recall_chapter(index: int) -> void:
	if index < 0 or index >= loop.state.campaign.chapter: return
	_guide_dialogue(_chapter_lines(C.D.quests[index]), [{"text": "再会", "action": loop.hud.close_modal}])

func show_resident(id: String) -> void:
	var npc := C.entry(C.D.npcs,id)
	for actor in actors:
		if actor.resident_id == id:
			actor.face(loop.lane.player.position - actor.position)
			actor.pose(0.0, false)
	var first_today: bool = loop.state.campaign.residents[id].talk_day != loop.state.day
	var dialogue_lines := C.talk(loop.state,id)
	if first_today and not loop.state.is_arrival_day():
		dialogue_lines.append_array(preload("res://Scenes/Campaign/town_conversations.gd").exchange(loop.state,id))
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
	if tab == "食谱": ids.insert(1, "__ready")
	if tab == "仓储": ids.append("resource")
	var filter := OptionButton.new()
	filter.position = Vector2(338,78)
	filter.size = Vector2(250,24)
	book.add_child(filter)
	for id in ids:
		filter.add_item(text("全部" if id == "" else "可制作" if id == "__ready" else "资源" if id == "resource" else categories[id]))
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
	if loop.state.is_arrival_day():
		row(text(C.D.arrival.description))
		return
	row(I18n.format("今日菜单 %d/%d", [loop.state.menu.count(true), C.restaurant(loop.state).menu]) + " · 18:00–22:00\n" + loop.state.pulse_note())
	var ordered: Array = range(C.D.recipes.size())
	# Stable priorities: selected menu, available stock, today's taste, catalogue.
	ordered.sort_custom(func(a, b):
		var a_score := _recipe_priority(a)
		var b_score := _recipe_priority(b)
		return a < b if a_score == b_score else a_score > b_score)
	var found := 0
	for index in ordered:
		var recipe: Dictionary = C.D.recipes[index]
		if not _food_matches(recipe, recipe_query, "" if recipe_category == "__ready" else recipe_category): continue
		if recipe_category == "__ready" and loop.state.dish_portions(index) <= 0: continue
		found += 1
		var tags := []
		for id in recipe.tags: tags.append(text(C.D.tags[id]))
		var details: String = cost_text(recipe.cost)
		if index < 3:
			var costs := []
			for material in range(3):
				if loop.state.COSTS[index][material] > 0:
					costs.append(text(loop.state.MATERIALS[material]) + " " + str(loop.state.materials[material]) + "/" + str(loop.state.COSTS[index][material]))
			details = " · ".join(costs)
		var stock := I18n.format("可制作 %d份", [loop.state.dish_portions(index)])
		if loop.state.SeasonalDirector.dish_focus_bonus(recipe, loop.state.daily_pulse) > 0: stock += " · " + text("今日偏好")
		var box := row(text(recipe.name)+" · "+str(recipe.price)+" G\n"+stock+"\n"+"/".join(tags)+"\n"+details,"res://Art/Campaign/icons/dish_"+recipe.id+".aseprite")
		var unlocked := C.unlocked(loop.state,index)
		action(box,"已上架" if loop.state.menu[index] else "未上架",mutate.bind(func():
			loop.state.set_menu_dish(index, not loop.state.menu[index])),unlocked and loop.state.phase=="day",88)
		action(box,"料理",func(): loop.hud.close_modal(); loop.cook_dish(index),unlocked and loop.state.phase=="night" and loop.location=="restaurant" and loop.at_counter("kitchen") and loop.state.menu[index] and loop.state.can_cook(index) and loop.state.cooking<0 and loop.state.held<0,88)
	if found == 0: row(text("没有符合条件的料理。"))

func _recipe_priority(index: int) -> int:
	return (100 if loop.state.menu[index] else 0) + (10 if loop.state.dish_portions(index) > 0 else 0) + loop.state.SeasonalDirector.dish_focus_bonus(C.D.recipes[index],loop.state.daily_pulse)

func _residents() -> void:
	for npc in C.D.npcs:
		if npc.id not in loop.state.campaign.met_residents: continue
		var r: Dictionary = loop.state.campaign.residents[npc.id]
		var title: String = text(npc.name)+" · "+str(npc.birthday[0]+1)+"/"+str(npc.birthday[1])+"\n"+(tr("好感 %d/1000 · 故事 %d/4") % [r.affinity,r.story])
		var preferences := []
		for tag in npc.likes: preferences.append(text(C.D.tags[tag]))
		title += "\n" + I18n.format("喜爱：%s · 忌口：%s", ["/".join(preferences), text(C.D.tags[npc.dislike])])
		var box := row(title,"res://Art/Characters/NPC32/portraits/"+npc.id+".aseprite")
		action(box,"交谈",show_resident.bind(npc.id),loop.location=="town" and loop.state.phase=="day")
		if loop.state.campaign.side_active.has(npc.id):
			action(box,"支线",func(): open("故事"))
	if loop.state.campaign.met_residents.is_empty(): row(text("这里还没有手记。"))

func _regions() -> void:
	for region in C.D.regions:
		var unlocked: bool = C.region_unlocked(loop.state, region)
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
	if loop.state.campaign.pending_scene >= 0 and story_filter != "已完成":
		var pending: Dictionary = C.D.quests[loop.state.campaign.pending_scene]
		var pending_row := row(text("主线") + " · " + text(pending.name))
		action(pending_row, "继续", _resume_story)
		return
	if story_filter == "已完成":
		for index in range(loop.state.campaign.chapter):
			var q: Dictionary = C.D.quests[index]
			var box := row(text("主线")+" · "+text(q.name)+"\n"+text(q.description))
			action(box,"回顾",_recall_chapter.bind(index)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for npc in C.D.npcs:
			for stage in range(loop.state.campaign.residents[npc.id].story):
				row(text("支线")+" · "+text(npc.stories[stage])+"\n"+text(npc.events[stage]),"res://Art/Characters/NPC32/portraits/"+npc.id+".aseprite")
		if list.get_child_count() == 0: row(text("这里还没有手记。"))
		return
	var q := C.current_main(loop.state)
	if loop.state.is_arrival_day():
		var step := Guide.Onboarding.current(loop.state)
		var box := row(text(step.name) + "\n" + text(step.description) + "\n" + I18n.format("地点：%s", [step.place]) + "\n" + I18n.format("当前目标：%s · %d/%d", [step.objective, step.progress, step.goal]))
		box.name = "ArrivalDay"
		return
	if not q.is_empty():
		var progress: int = mini(q.goal,C.metric(loop.state,q.metric))
		var step := Guide.Onboarding.current(loop.state)
		var caption: String = text("主线")+" · "+text(q.name)+"\n"+text(q.briefing)+"\n"+I18n.format("地点：%s",[step.place])+"\n"+I18n.format("当前目标：%s · %d/%d",[step.objective,step.progress,step.goal])+"\n"+text(q.objective)+" · "+(tr("目标 %d/%d · 奖励 %d金") % [progress,q.goal,q.reward])
		if step.id != q.id: caption += "\n"+text(step.description)
		var box := row(caption)
		box.name = "MainQuest"
		action(box,"完成",complete_chapter,progress>=q.goal).size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	intro_film = OpeningFilm.new()
	intro_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_film.setup(C.D.intro)
	intro.add_child(intro_film)
	var shade := ColorRect.new()
	shade.position = Vector2(0,220)
	shade.size = Vector2(640,140)
	shade.color = Color(0.12,0.08,0.17,0.85)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(shade)
	intro_title = loop.hud.label("",Rect2(32,232,576,34),intro,Color("fff0d5"),24)
	intro_line = loop.hud.label("",Rect2(32,274,570,64),intro,Color("fff0d5"))
	intro_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var skip: Button = loop.hud.button("略过",Rect2(554,12,66,26),intro,finish_intro)
	skip.grab_focus()
	_render_intro()

func intro_length() -> float:
	return intro_film.length()

func _render_intro() -> void:
	var index: int = intro_film.index_at(intro_elapsed)
	if index != intro_index:
		intro_index = index
		intro_title.text = C.D.intro[index].title
		intro_line.text = C.D.intro[index].line
	# Captions fade with the shot so the text never lingers over a black frame.
	var t: float = intro_film.local_time(intro_elapsed)
	var duration: float = intro_film.durations[index]
	var caption := clampf(minf(t - 0.3, duration - 0.3 - t) / 0.6, 0.0, 1.0)
	intro_title.modulate.a = caption
	intro_line.modulate.a = caption
	intro_film.render(intro_elapsed)

func finish_intro() -> void:
	if not is_instance_valid(intro) or opening_transition_active: return
	loop.state.campaign.introduced = true
	_save_story_checkpoint()
	# Keep the film visible until the fade fully covers the first world shot.
	await _start_opening_stage(true)

func opening_active() -> bool:
	return opening_transition_active or is_instance_valid(intro) or arrival_active or (loop.state.campaign.introduced and not loop.state.campaign.guide_met)

func _start_opening_stage(from_film: bool = false) -> void:
	if opening_transition_active or loop.state.campaign.guide_met or loop.hud.mode == "dialogue": return
	if is_instance_valid(intro) and not from_film: return
	opening_transition_active = true
	get_tree().paused = true
	# Loading a saved opening can create this controller during a menu fade.
	if SceneTransition.active:
		await SceneTransition.finished
		get_tree().paused = true
	var stage: int = loop.state.campaign.opening_stage
	# All world swaps and actor placement happen behind the shared black cover.
	await SceneTransition.run(_prepare_opening_stage.bind(stage))
	if stage == 1:
		await _walk_opening([
			{"actor": loop.lane.player, "path": [Vector2(270,324), Vector2(270,258)]},
			{"actor": arrival_actor, "path": ARRIVAL_PATH.slice(1)}
		])
		arrival_active = false
	elif stage == 2:
		var door: Vector2 = loop.REST_GATE
		await _walk_opening([
			{"actor": loop.lane.player, "path": [door + Vector2(0,16)]},
			{"actor": arrival_actor, "path": [door]}
		])
		await SceneTransition.run(_prepare_restaurant_entry)
		await _walk_opening([
			{"actor": loop.lane.player, "path": [Vector2(140,248), Vector2(140,146)]},
			{"actor": arrival_actor, "path": [Vector2(140,248), Vector2(140,180)]}
		])
	# Establish the conversation before returning HUD input to its normal owner.
	loop.lane.facing = 0 if stage == 1 else 2
	loop.lane._animate(false, false, 0.0)
	for actor in opening_cast:
		actor.face(loop.lane.player.position - actor.position)
	get_tree().paused = intro_old_pause
	opening_transition_active = false
	_opening_dialogue(stage)

func _prepare_opening_stage(stage: int) -> void:
	if is_instance_valid(intro):
		intro.hide()
		intro.queue_free()
		intro = null
	_clear_opening_cast()
	_restore_arrival_camera()
	match stage:
		0:
			loop._commit_travel("dock", Vector2.INF)
			_stage_opening_cast(0)
		1:
			loop._commit_travel("farm", Vector2.INF)
			loop.lane.player.position = Vector2(350,324)
			loop.lane.facing = 3
			arrival_actor = _opening_guide(ARRIVAL_PATH[0])
			arrival_actor.face(Vector2.LEFT)
			arrival_active = true
			# Frame the cottage, the arriving keeper and the conversation together.
			loop.lane.camera.position = Vector2(0,64)
		2:
			loop.state.restaurant_leased = true
			loop.state.campaign.settling_in = loop.state.day == 1 and loop.state.campaign.chapter == 0 and loop.state.journal.serve == 0
			loop._commit_travel("town", Vector2.INF)
			loop.lane.player.position = loop.REST_GATE + Vector2(0,64)
			loop.lane.facing = 1
			arrival_actor = _opening_guide(loop.REST_GATE + Vector2(0,36))
			arrival_actor.face(Vector2.UP)
	loop.lane._animate(false, false, 0.0)
	loop.lane.camera.reset_smoothing()
	loop.lane.camera.force_update_scroll()

func _prepare_restaurant_entry() -> void:
	_clear_opening_cast()
	loop._commit_travel("restaurant", Vector2.INF)
	_stage_opening_cast(2)
	loop.lane.player.position = Vector2(60,248)
	loop.lane.facing = 2
	arrival_actor.position = Vector2(40,248)
	arrival_actor.face(Vector2.RIGHT)
	loop.lane._animate(false, false, 0.0)
	loop.lane.camera.reset_smoothing()
	loop.lane.camera.force_update_scroll()

func _stage_opening_cast(stage: int) -> void:
	_clear_opening_cast()
	var positions: Dictionary = {"nagi": Vector2(332,223)} if stage == 0 else {"orla": Vector2(174,146), "toma": Vector2(230,146)}
	loop.lane.player.position = Vector2(300,239) if stage == 0 else Vector2(140,146)
	loop.lane.facing = 2
	loop.lane._animate(false, false, 0.0)
	for id in positions:
		var actor := preload("res://Scenes/Campaign/resident_actor.gd").new()
		actor.configure(id, C.D.npcs.find(C.entry(C.D.npcs, id)))
		actor.name = "Opening_" + id
		actor.position = positions[id]
		actor.face(loop.lane.player.position - actor.position)
		actor.pose(0.0, false)
		loop.area.add_child(actor)
		opening_cast.append(actor)
	if stage == 2:
		arrival_actor = _opening_guide(Vector2(140,180))
		arrival_actor.face(Vector2.UP)
		arrival_actor.pose_walk(0.0, false)

func _opening_guide(at: Vector2) -> Node2D:
	var keeper := preload("res://Scenes/Campaign/guide_actor.gd").new()
	keeper.name = "Opening_Lucinda"
	keeper.position = at
	# Town has no separate interior area; use its existing feet-sorted actors.
	var parent: Node2D = loop.lane.actors if loop.location == "town" else loop.area
	parent.add_child(keeper)
	opening_cast.append(keeper)
	return keeper

func _clear_opening_cast() -> void:
	for actor in opening_cast:
		if is_instance_valid(actor): actor.queue_free()
	opening_cast.clear()
	arrival_actor = null
	arrival_active = false

func _opening_dialogue(stage: int) -> void:
	opening_dialogue_allowed = true
	loop.hud.start_dialogue(Guide.NAME, Guide.PORTRAIT, _beat_lines(C.D.opening[stage].dialogue), [{"text": "继续", "action": _finish_opening_stage.bind(stage)}], Rect2())
	opening_dialogue_allowed = false

func _finish_opening_stage(expected: int) -> void:
	if opening_transition_active or loop.state.campaign.opening_stage != expected: return
	loop.hud.close_modal()
	opening_transition_active = true
	get_tree().paused = true
	loop.state.campaign.opening_stage += 1
	if loop.state.campaign.opening_stage == C.D.opening.size():
		loop.state.campaign.guide_met = true
		loop.state.restaurant_leased = true
		loop.state.campaign.settling_in = loop.state.day == 1 and loop.state.campaign.chapter == 0 and loop.state.journal.serve == 0
	# Save the destination segment before leaving, so interruption replays only
	# the next introduction and never depends on a half-finished walk.
	_save_story_checkpoint()
	if expected == 0:
		await _walk_opening([{"actor": loop.lane.player, "path": [Vector2(204,239)]}])
	elif expected == 1:
		await _walk_opening([
			{"actor": loop.lane.player, "path": [Vector2(270,324), Vector2(318,324)]},
			{"actor": arrival_actor, "path": [Vector2(270,324), Vector2(352,324)]}
		])
	if loop.state.campaign.guide_met:
		_restore_arrival_camera()
		_clear_opening_cast()
		get_tree().paused = intro_old_pause
	opening_transition_active = false
	if not loop.state.campaign.guide_met: await _start_opening_stage()

func _walk_opening(tracks: Array) -> void:
	# Cinematic motion runs while gameplay/clock/physics are paused. Each track
	# follows the same native directional animation as ordinary movement.
	loop.audio.reset_footsteps()
	for track in tracks: track["next"] = 0
	while true:
		await get_tree().process_frame
		var delta := minf(get_process_delta_time(), 0.05)
		var pending := false
		for track in tracks:
			var actor: Node2D = track.actor
			var budget := ARRIVAL_SPEED * delta
			var direction := Vector2.ZERO
			var travelled := 0.0
			while budget > 0.0 and track.next < track.path.size():
				var start := actor.position
				var target: Vector2 = track.path[track.next]
				actor.position = start.move_toward(target, budget)
				var step := start.distance_to(actor.position)
				budget -= step
				travelled += step
				if step > 0.0: direction = actor.position - start
				if actor.position == target: track.next += 1
				else: break
			var moving: bool = track.next < track.path.size()
			pending = pending or moving
			if actor == loop.lane.player:
				actor.velocity = Vector2.ZERO
				if not direction.is_zero_approx():
					loop.lane.facing = (2 if direction.x > 0.0 else 3) if absf(direction.x) > absf(direction.y) else (0 if direction.y > 0.0 else 1)
				loop.lane._animate(moving, false, delta)
				loop.lane.avatar.position = loop.lane.WITCH_FOOT_OFFSET + actor.position.round() - actor.position
				if travelled > 0.0: loop._on_player_moved(travelled, false)
			else:
				actor.face(direction)
				actor.pose_walk(delta, moving)
		if not pending: break
	loop.audio.reset_footsteps()

func _restore_arrival_camera() -> void:
	loop.lane.camera.position = Vector2.ZERO
	loop.lane.camera.reset_smoothing()
	loop.lane.camera.force_update_scroll()

func _exit_tree() -> void:
	if opening_active(): get_tree().paused = intro_old_pause
	if is_instance_valid(decor) and not decor.is_inside_tree(): decor.free()
