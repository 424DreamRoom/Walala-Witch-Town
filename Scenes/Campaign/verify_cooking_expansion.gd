extends SceneTree
## Synthetic progress only; no player settings or saves are read.
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/cooking_expansion/"
var failures := 0
var checks := 0
var capture := false
var lane
var loop

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	C.pending_intro = false
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("COOKING ", label, ": ", "PASS" if ok else "FAIL")

func frames(count: int = 5) -> void:
	for i in range(count): await process_frame

func shot(name: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + name, lane.viewport.get_texture().get_image().save_png(OUT+name+".png") == OK)

func run() -> void:
	check("120 food ingredients exclude construction resources", C.D.ingredients.size() == 120 and C.D.items.size() == 125)
	check("324 appended recipes retain 36 legacy indices", C.D.recipes.size() == 360 and C.D.recipes[0].id == "mushroom_soup" and C.D.recipes[35].id == "lantern_dessert" and C.D.recipes[36].id == "apple_yogurt")
	var s = State.new()
	var old: Dictionary = s.to_save_data()
	old.menu = old.menu.slice(0,36)
	old.campaign.pantry.egg = 17
	old.campaign.stats.banquet = 5
	for id in C.D.added_ingredients: old.campaign.pantry.erase(id)
	var restored := State.normalize_save_data(old)
	check("36-dish save grows without losing progress", not restored.is_empty() and restored.menu.size() == 360 and restored.campaign.pantry.size() == 125 and restored.campaign.pantry.egg == 17 and restored.campaign.pantry.apple == 0 and restored.campaign.stats.banquet == 5)
	old.campaign.pantry.erase("egg")
	check("missing legacy ingredient still rejected", State.normalize_save_data(old).is_empty())
	old.campaign.pantry.egg = 17
	old.campaign.pantry.unknown_food = 3
	check("unknown ingredient still rejected", State.normalize_save_data(old).is_empty())

	for id in C.D.added_ingredients:
		s = State.new()
		var item: Dictionary = C.D.items[id]
		s.coins = item.buy
		check("buy exact cost " + id, C.trade(s,id,true) and s.coins == 0 and s.campaign.pantry[id] == 1)
		check("unaffordable purchase atomic " + id, not C.trade(s,id,true) and s.campaign.pantry[id] == 1 and s.coins == 0)
		check("sell exact return " + id, C.trade(s,id,false) and s.coins == item.sell and s.campaign.pantry[id] == 0)
		s.coins = 1000
		s.phase = "night"
		check("night purchase rejected " + id, not C.trade(s,id,true) and s.coins == 1000 and s.campaign.pantry[id] == 0)

	for index in range(3,C.D.recipes.size()):
		s = State.new()
		s.restaurant_leased = true
		s.campaign.restaurant = 4
		s.menu.fill(false)
		s.menu[index] = true
		s.phase = "night"
		s.remaining = State.NIGHT_SECONDS
		var recipe: Dictionary = C.D.recipes[index]
		for id in recipe.cost: s.campaign.pantry[id] = recipe.cost[id]
		var before: Dictionary = s.campaign.pantry.duplicate()
		check("starts with exact materials " + recipe.id, s.start_cook(index))
		var exact := true
		for id in before:
			exact = exact and s.campaign.pantry[id] == int(before[id])-int(recipe.cost.get(id,0))
		check("only recipe materials debited " + recipe.id, exact)
		s.tick(8)
		check("ready " + recipe.id, s.held == index)
		check("cooking save roundtrip " + recipe.id, not State.normalize_save_data(s.to_save_data()).is_empty())
		s.customers = [{"seat":0,"dish":index,"patience":35.0,"variant":0,"npc":0,"status":"waiting","eating_left":0.0}]
		check("serve and pay " + recipe.id, s.serve(0) and s.income >= recipe.price and s.held == -1)
		# Removing one required unit must fail before any other ingredient is taken.
		s = State.new()
		s.campaign.restaurant = 4
		s.menu.fill(false)
		s.menu[index] = true
		s.phase = "night"
		for id in recipe.cost: s.campaign.pantry[id] = recipe.cost[id]
		s.campaign.pantry[recipe.cost.keys()[0]] -= 1
		before = s.campaign.pantry.duplicate()
		check("missing ingredient atomic " + recipe.id, not s.start_cook(index) and s.campaign.pantry == before and s.cooking == -1)

	s = State.new()
	for index in range(36,360): C.service(s,{"npc":0},index)
	check("new dishes never satisfy legacy banquet", C.metric(s,"banquet") == 0 and s.campaign.stats.banquet == 0)
	for index in [33,34,35]: C.service(s,{"npc":0},index)
	check("three original banquet dishes still complete objective", C.metric(s,"banquet") == 3 and not State.normalize_save_data(s.to_save_data()).is_empty())
	s.campaign.pantry.apple = 9
	s.menu.fill(false)
	s.menu[359] = true
	s.campaign.restaurant = 4
	var snapshot := {"state":s.to_save_data(),"world":{"location":"farm","position":[270,258],"town_position":[408,364],"facing":0,"weather":"clear"},"play_seconds":0.0,"created_at":1,"saved_at":1,"saved_at_text":"Cooking Test"}
	check("save expanded menu slot", Saves.write_slot(1,snapshot).ok)
	var loaded := Saves.read_slot(1)
	check("JSON roundtrip preserves new food and final recipe", loaded.ok and not loaded.get("empty",true) and loaded.data.state.campaign.pantry.apple == 9 and loaded.data.state.menu[359])

	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(10)
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.state.campaign.introduced = true
	loop.state.campaign.guide_met = true
	loop.state.campaign.opening_stage = 3
	loop.state.campaign.restaurant = 4
	loop.enter("store")
	await frames()
	var ui = loop.campaign_controller
	var localization = root.get_node("Localization")
	for locale in ["zh_CN","en","ja","zh_TW"]:
		localization.set_language(locale,false)
		ui.recipe_query = ""
		ui.recipe_category = ""
		ui.open("食谱")
		await frames()
		check("all 360 rows " + locale, ui.list.get_child_count() == 361)
		ui.recipe_query = TranslationServer.translate("苹果")
		ui.open("食谱")
		await frames()
		# English substring search also includes Pineapple.
		check("translated name search " + locale, ui.list.get_child_count() == (11 if locale == "en" else 6))
		await shot("recipes_"+locale)
		ui.recipe_query = ""
		ui.recipe_category = "drink"
		ui._refresh_food_list()
		check("drink category " + locale, ui.list.get_child_count() > 20)
		ui.pantry_query = TranslationServer.translate("苹果")
		ui.pantry_category = ""
		ui.open("仓储")
		await frames()
		check("pantry localized search " + locale, ui.list.get_child_count() == (2 if locale == "en" else 1) and ui.list.get_child(0).get_child_count() == 4)
		loop.state.coins = 1000
		var apple_before: int = loop.state.campaign.pantry.apple
		var buy: Button = ui.list.get_child(0).get_child(3)
		check("new ingredient purchase button enabled " + locale, not buy.disabled)
		buy.pressed.emit()
		check("UI purchase reaches persistent pantry " + locale, loop.state.campaign.pantry.apple == apple_before+1 and loop.state.coins == 1000-C.D.items.apple.buy)
		await shot("pantry_"+locale)
	ui.pantry_query = ""
	ui.pantry_category = "fruit"
	ui.open("仓储")
	await frames()
	check("pantry fruit category", ui.list.get_child_count() == 26)
	await shot("pantry_fruit")
	lane.queue_free()
	await frames()
	print("COOKING COMPLETE checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
