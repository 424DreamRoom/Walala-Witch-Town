extends RefCounted
const I18n = preload("res://Localization/localized_text.gd")
const Furniture = preload("res://Scenes/Building/furniture_catalog.gd")
const Equipment = preload("res://Scenes/Equipment/equipment_catalog.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Campaign = preload("res://Scenes/Campaign/campaign_state.gd")
const Content = preload("res://Scenes/Campaign/content.gd")
const SeasonalDirector = preload("res://Scenes/Gameplay/seasonal_director.gd")
const ShopFood = preload("res://Scenes/Businesses/food_catalog.gd")
const FarmTerrain = preload("res://Scenes/Farm/farm_terrain.gd")
var campaign: Dictionary = Campaign.initial()
## All inventory mutations live here; no UI-only copies.
const INGREDIENTS = ["蘑菇", "莓果", "香草"]
const MATERIALS = ["切片菇", "莓果酱", "香草料"]
const DISHES = Content.DISH_NAMES
const COSTS = [[2, 0, 0], [0, 2, 0], [1, 0, 1]]
const PRICES = Content.DISH_PRICES
const CAPACITY = 12
const TOOL_NAMES = {"wand": "法杖"}
const STARTING_TOOLS = {"wand": 1}
const LEGACY_STARTING_TOOLS = {"axe": 1, "hoe": 1, "watering_can": 1, "pickaxe": 1}
const RESOURCE_TOOLS = {"wood": "wand", "ore": "wand", "fish": "wand", "weed": "wand"}
const DAY_SECONDS = 9.0 * 60.0
const NIGHT_SECONDS = 5.0 * 60.0
const DAY_LENGTH_SECONDS = DAY_SECONDS + NIGHT_SECONDS
const OPEN_MINUTES = 18 * 60
const CLOSE_MINUTES = 22 * 60
const CLOCK_STEP_MINUTES = 30
const TIME_OF_DAY_NAMES = {"morning": "早上", "day": "白天", "evening": "傍晚", "night": "夜晚"}
const COOK_SECONDS = 3.0
const PATIENCE = 25.0
var day = 1
var phase = "day"
var remaining = DAY_SECONDS
var raw = [0, 0, 0]
var tools = STARTING_TOOLS.duplicate()
var bag_slots: Array = []
var selected_hotbar_slot := 0
var wand_mode := "red"
var bag_overflow: Dictionary = {}
var inventory_pending: Dictionary = {}
var equipment: Dictionary = Equipment.DEFAULT_LEVELS.duplicate()
var materials = [0, 0, 0]
var menu: Array = []
var nodes = [2, 2, 2, 2, 2, 2, 2, 2, 2]
const RESOURCE_NAMES = {"wood": "木材", "ore": "矿石", "fish": "鱼", "iron": "铁锭"}
const RESOURCE_HITS = 3
var resources = {"wood": 0, "ore": 0, "fish": 0, "iron": 0}
var resource_damage = {}
var fish_catches = {}
const FARM_TILE_COUNT := FarmTerrain.TILE_COUNT
const FARM_GROWTH_DAYS := 3
const FARM_WATER_CAPACITY := 24
const STARTING_FARM := {"plots": {}, "seeds": 12, "water": FARM_WATER_CAPACITY}
var farm: Dictionary = STARTING_FARM.duplicate(true)
var furniture: Dictionary = Furniture.initial_data()
var customers: Array = []
var cooking = -1
var cook_left = 0.0
var held = -1
var income = 0
var coins = 0
const RESTAURANT_RENT := 60
var restaurant_leased := false
var served = 0
var lost = 0
var wasted = 0
var arrivals = 0.0
var serial = 0
var result = ""
var message = "新的一天开始了。"
var message_source := ""
var message_arguments: Array = []
var formatted_message := ""
var journal = {"gather": 0, "prepare": 0, "serve": 0, "fish": 0, "tracked": "gather"}
## Daily pulse is derived from the day number and persisted service counters keep
## the evening loop meaningful without changing the original recipe economy.
var daily_pulse: Dictionary = {}
var service_chain := 0
var service_peak := 0
var tips := 0
var guest_mood := 0
var crop_quality_total := 0
var crop_harvests := 0

# Derive the clock from the saved phase timer so lighting and HUD never drift.
func _init() -> void:
	menu.resize(DISHES.size())
	menu.fill(false)
	daily_pulse = SeasonalDirector.pulse_for_day(day)
	guest_mood = int(daily_pulse.get("mood", 0))

func pulse_note() -> String:
	return I18n.format("今日气象：%s · 料理偏好：%s", [daily_pulse.weather_name, daily_pulse.focus_name])

func pulse_focus() -> String:
	return SeasonalDirector.focus_text(daily_pulse)

func sync_weather(weather: String) -> void:
	if weather not in SeasonalDirector.WEATHER_NAMES: return
	daily_pulse.weather = weather
	daily_pulse.weather_name = SeasonalDirector.WEATHER_NAMES[weather]
	daily_pulse.soil_bonus = 1 if weather == "rain" else 0

func crop_quality_bonus(plot: Dictionary) -> int:
	var quality := SeasonalDirector.crop_quality(plot, daily_pulse)
	return 1 if quality >= 2 else 0

func record_crop_quality(plot: Dictionary) -> void:
	var quality := SeasonalDirector.crop_quality(plot, daily_pulse)
	crop_quality_total += quality
	crop_harvests += 1

func service_summary() -> String:
	return "连席 %d · 小费 %d金 · 心情 %d" % [service_chain, tips, guest_mood]

# Daytime spans 06:00-18:00; confirmed service spans 18:00-22:00.
func get_time_minutes() -> float:
	if phase == "result":
		return float(CLOSE_MINUTES)
	var daytime: bool = phase == "day"
	var duration: float = DAY_SECONDS if daytime else NIGHT_SECONDS
	var elapsed: float = clampf(1.0 - remaining / duration, 0.0, 1.0)
	return (360.0 if daytime else float(OPEN_MINUTES)) + elapsed * (OPEN_MINUTES - 360.0 if daytime else float(CLOSE_MINUTES - OPEN_MINUTES))

func get_clock_minutes() -> int:
	# The HUD advances in half-hour steps; simulation time stays precise.
	return floori(get_time_minutes() / CLOCK_STEP_MINUTES) * CLOCK_STEP_MINUTES

func get_time_text() -> String:
	var minutes := get_clock_minutes()
	return "%02d:%02d" % [minutes / 60, minutes % 60]

func get_time_of_day() -> String:
	var minutes := get_time_minutes()
	if minutes < 360.0 or minutes >= 1200.0:
		return "night"
	if minutes < 540.0:
		return "morning"
	if minutes < 1020.0:
		return "day"
	return "evening"

func get_time_of_day_name() -> String:
	return tr(TIME_OF_DAY_NAMES[get_time_of_day()])

func set_message(source: String, arguments: Array) -> void:
	message_source = source
	message_arguments = arguments.duplicate()
	message = source % arguments
	formatted_message = message

func get_message_text() -> String:
	if message == formatted_message and not message_source.is_empty():
		return I18n.format(message_source, message_arguments)
	return I18n.prompt(message)

func get_result_text() -> String:
	return tr("第 %d 天结算\n收入：%d 金币　累计：%d\n上菜：%d　离店：%d　废弃：%d\n小费：%d　最高连席：%d\n原食材和厨房原料保留；采集点次日刷新。") % [day, income, coins, served, lost, wasted, tips, service_peak]

const BUSINESS_SALES = {"sell_wood": ["wood", 1], "sell_ore": ["ore", 3], "sell_iron": ["iron", 8], "sell_fish": ["fish", 4]}
const BUSINESS_BUYS = {"buy_mushroom": 0, "buy_berry": 1, "buy_herb": 2}

func bag_capacity() -> int:
	return Equipment.BAG_CAPACITIES[equipment.bag]

func water_capacity() -> int:
	return Equipment.WATER_CAPACITIES[equipment.wand]

func upgrade_block_reason(id: String) -> String:
	Items.ensure_bag(self)
	if id not in Equipment.IDS: return "未满足升级条件。"
	if phase != "day": return "柜台已打烊。"
	if equipment[id] >= Equipment.MAX_LEVEL: return "已达最高等级"
	if id == "wand" and not has_tool(id): return "需要法杖。"
	var price := Equipment.cost(id, equipment[id])
	if coins < price.coins: return "金币不足"
	if resources.wood < price.wood or resources.iron < price.iron: return "材料不足"
	return ""

func can_upgrade(id: String) -> bool:
	return upgrade_block_reason(id).is_empty()

func upgrade_equipment(id: String) -> bool:
	var reason := upgrade_block_reason(id)
	if not reason.is_empty():
		message = reason
		return false
	var price := Equipment.cost(id, equipment[id])
	coins -= price.coins
	Items.change(self, {"wood": -price.wood, "iron": -price.iron})
	equipment[id] += 1
	Items.ensure_bag(self)
	set_message("%s已升级为%s。", [Equipment.TITLES[id], Equipment.TIERS[equipment[id]]])
	return true

func swing_seconds(kind: String) -> float:
	return Equipment.SWING_SECONDS[equipment[RESOURCE_TOOLS[kind]]]

func farm_action_tiles(index: int) -> Array[int]:
	var area: Vector2i = Equipment.HOE_AREAS[equipment.wand]
	var result: Array[int] = []
	var center: Vector2i = FarmTerrain.cells[index]
	for y in range(center.y - area.y / 2, center.y + area.y / 2 + 1):
		for x in range(center.x - area.x / 2, center.x + area.x / 2 + 1):
			var tile: int = FarmTerrain.indices.get(Vector2i(x, y), -1)
			if FarmTerrain.can_till(self, tile): result.append(tile)
	return result

func can_business(action: String) -> bool:
	Items.ensure_bag(self)
	if phase != "day":
		return false
	if action == "buy_seeds":
		return coins >= 2 and Items.can_change(self, {"seed": 4})
	if action == "sell_herb":
		return raw[2] > 0
	if action == "smelt":
		return Items.can_change(self, {"ore": -2, "wood": -1, "iron": 1})
	if action in BUSINESS_SALES:
		return resources[BUSINESS_SALES[action][0]] > 0
	if action in BUSINESS_BUYS:
		return coins >= 3 and Items.room(self, Items.RAW[BUSINESS_BUYS[action]]) > 0
	if action.begins_with("buy_") and action.trim_prefix("buy_") in ShopFood.DATA:
		var id := action.trim_prefix("buy_")
		return coins >= ShopFood.DATA[id].price and Items.can_change(self, {id: 1})
	return false

func business_transaction(action: String) -> bool:
	if not can_business(action):
		message = "未满足交易条件。"
		return false
	if action == "buy_seeds":
		coins -= 2
		Items.change(self, {"seed": 4})
		message = "购入香草种子 ×4，花费2金。"
	elif action == "sell_herb":
		Items.change(self, {"herb": -1})
		coins += 3
		message = "售出香草 ×1，获得3金。"
	elif action == "smelt":
		Items.change(self, {"ore": -2, "wood": -1, "iron": 1})
		message = "熔炼完成：矿石2 + 木材1 → 铁锭1。"
	elif action in BUSINESS_SALES:
		var sale: Array = BUSINESS_SALES[action]
		Items.change(self, {sale[0]: -1})
		coins += sale[1]
		set_message("售出%s ×1，获得%d金。", [RESOURCE_NAMES[sale[0]], sale[1]])
	elif action.trim_prefix("buy_") in ShopFood.DATA:
		var id := action.trim_prefix("buy_")
		var food: Dictionary = ShopFood.DATA[id]
		if not Items.change(self, {id: 1}): return false
		coins -= food.price
		set_message("购入%s ×1，花费%d金。", [food.name, food.price])
	else:
		var ingredient: int = BUSINESS_BUYS[action]
		coins -= 3
		Items.change(self, {Items.RAW[ingredient]: 1})
		set_message("购入%s ×1，花费3金。", [INGREDIENTS[ingredient]])
	return true

func gather(index: int) -> bool:
	if phase != "day":
		message = "仅白天可以采集。"
		return false
	if nodes[index] <= 0:
		message = "这里已采完，次日刷新。"
		return false
	if not Items.change(self, {Items.RAW[index % 3]: 1}):
		set_message("背包已满（%d）。", [bag_capacity()])
		return false
	nodes[index] -= 1
	journal.gather = mini(1000000000, journal.gather + 1)
	set_message("采得%s ×%d", [INGREDIENTS[index % 3], 1])
	return true

func process_raw() -> bool:
	if phase == "result":
		return false
	Items.ensure_bag(self)
	var count = raw[0] + raw[1] + raw[2]
	for i in range(3):
		materials[i] += raw[i]
	Items.change(self, {"mushroom": -raw[0], "berry": -raw[1], "herb": -raw[2]})
	journal.prepare = mini(1000000000, journal.prepare + count)
	message = "加工完成：原食材 1:1 转为厨房原料。" if count > 0 else "背包没有原食材。"
	return count > 0

func resource_left(id: String) -> int:
	return RESOURCE_HITS - int(resource_damage.get(id, 0))

func has_tool(id: String) -> bool:
	return tools.get(id, 0) > 0

func select_hotbar_slot(index: int) -> bool:
	if index < 0 or index >= Items.HOTBAR_SLOTS or index == selected_hotbar_slot: return false
	selected_hotbar_slot = index
	return true

func selected_item_id() -> String:
	Items.ensure_bag(self)
	if selected_hotbar_slot < 0 or selected_hotbar_slot >= mini(Items.HOTBAR_SLOTS, bag_slots.size()): return ""
	var slot: Dictionary = bag_slots[selected_hotbar_slot]
	return str(slot.get("id", "")) if int(slot.get("count", 0)) > 0 else ""

func is_item_selected(id: String) -> bool:
	return not id.is_empty() and selected_item_id() == id

func require_selected_item(id: String) -> bool:
	if is_item_selected(id): return true
	set_message("%s未选中。", [Items.NAMES[id]])
	return false

func toggle_wand_mode() -> bool:
	if phase == "result" or not has_tool("wand") or not is_item_selected("wand"): return false
	wand_mode = "red" if wand_mode == "blue" else "blue"
	message = ""
	return true

func require_wand_mode(mode: String) -> bool:
	if not has_tool("wand"):
		message = "需要法杖。"
		return false
	if not require_selected_item("wand"): return false
	if wand_mode == mode: return true
	message = "当前为蓝色法杖。" if wand_mode == "blue" else "当前为红色法杖。"
	return false

func consume_selected_item(id: String, amount: int = 1) -> bool:
	if amount <= 0 or not require_selected_item(id): return false
	var slot: Dictionary = bag_slots[selected_hotbar_slot]
	if int(slot.count) < amount: return false
	slot.count -= amount
	if slot.count == 0: bag_slots[selected_hotbar_slot] = {}
	Items.sync(self)
	return true

func strike_resource(id: String, kind: String) -> int:
	if phase != "day" or kind not in ["wood", "ore", "weed"] or resource_left(id) <= 0:
		message = "这里已采完，次日刷新。" if phase == "day" else "仅白天可以采集。"
		return -1
	if not has_tool(RESOURCE_TOOLS[kind]):
		set_message("需要%s。", [TOOL_NAMES[RESOURCE_TOOLS[kind]]])
		return -1
	if not require_selected_item(RESOURCE_TOOLS[kind]): return -1
	if not require_wand_mode("red"): return -1
	if kind == "weed":
		resource_damage[id] = RESOURCE_HITS
		message = "杂草已清除。"
		return 0
	var rank: int = equipment[RESOURCE_TOOLS[kind]]
	var amount: int = Equipment.resource_yield(kind, rank)
	if resource_left(id) <= Equipment.STRIKE_POWER[rank] and not Items.change(self, {kind: amount}):
		message = "背包已满，无法取出。"
		return -1
	resource_damage[id] = mini(RESOURCE_HITS, int(resource_damage.get(id, 0)) + Equipment.STRIKE_POWER[rank])
	var left := resource_left(id)
	if left == 0:
		Campaign.stat(self, kind, amount)
		set_message("采得%s ×%d", [RESOURCE_NAMES[kind], amount])
	return left

func fish_left(id: String) -> int:
	return Equipment.FISH_COUNTS[equipment.wand] - int(fish_catches.get(id, 0))

func farm_tile_prompt(index: int) -> String:
	if phase != "day":
		return "夜间休耕"
	var plot: Dictionary = farm.plots.get(str(index), {})
	if not plot.is_empty() and plot.get("crop", "herb") != "herb":
		if plot.growth < 0: return "已开垦"
		if plot.growth >= Campaign.crop_days(plot): return "地块已成熟"
		return tr("生长 %d/%d") % [plot.growth, Campaign.crop_days(plot)]
	if plot.is_empty():
		return ""
	if plot.growth < 0:
		return "已开垦" if farm.seeds > 0 else "种子不足"
	if plot.growth >= FARM_GROWTH_DAYS:
		return "香草已成熟"
	if plot.watered:
		return I18n.format("已浇水 · 生长 %d/%d 天", [plot.growth, FARM_GROWTH_DAYS])
	return "未浇水" if farm.water > 0 else "储水已空"

func work_farm_tile(index: int) -> bool:
	if phase != "day" or index < 0 or index >= FARM_TILE_COUNT:
		message = "夜间无法耕作。"
		return false
	if not FarmTerrain.can_till(self, index):
		message = "土地被占用。"
		return false
	if wand_mode == "red" and is_item_selected("wand") and not require_wand_mode("blue"): return false
	var key := str(index)
	if not farm.plots.has(key):
		if not has_tool("wand"):
			message = "需要法杖。"
			return false
		if not require_selected_item("wand"): return false
		var count := 0
		for tile in farm_action_tiles(index):
			if farm.plots.has(str(tile)): continue
			farm.plots[str(tile)] = {"growth": -1, "watered": false}
			count += 1
		if equipment.wand == 0: message = "土地已翻好。"
		else: set_message("已翻好 %d 格土地。", [count])
		return true
	var plot: Dictionary = farm.plots[key]
	if plot.growth < 0 and campaign.selected_crop == "herb" and not is_item_selected("wand") and not require_selected_item("seed"): return false
	if plot.growth < 0 and campaign.selected_crop == "herb":
		plot.erase("crop")
		plot.erase("fertilized")
	if (plot.growth < 0 and campaign.selected_crop != "herb") or plot.get("crop", "herb") != "herb":
		return Campaign.farm_action(self, index)
	if plot.growth < 0:
		if farm.seeds <= 0:
			message = "香草种子不足。"
			return false
		if is_item_selected("wand"):
			if not Items.change(self, {"seed": -1}): return false
		elif not consume_selected_item("seed"): return false
		plot.growth = 0
		message = "已播下香草种子。"
	elif plot.growth >= FARM_GROWTH_DAYS:
		var harvest_amount: int = 1 + (1 if plot.get("fertilized", false) else 0)
		harvest_amount += crop_quality_bonus(plot)
		if not Items.change(self, {"herb": harvest_amount, "seed": 2}):
			message = "背包已满，无法收获。"
			return false
		record_crop_quality(plot)
		plot.growth = -1
		plot.erase("fertilized")
		Campaign.stat(self, "harvest", harvest_amount)
		campaign.harvested.herb = true
		journal.gather = mini(1000000000, journal.gather + 1)
		message = "收获香草 ×1、种子 ×2！"
		if harvest_amount > 1: set_message("%s ×%d", ["香草",harvest_amount])
	elif not plot.watered:
		if not has_tool("wand"):
			message = "需要法杖。"
			return false
		if not require_selected_item("wand"): return false
		if not require_wand_mode("blue"): return false
		if farm.water <= 0:
			message = "储水已空。"
			return false
		farm.water -= 1
		plot.watered = true
		message = "浇水完成，香草会在进入次日时生长。"
	else:
		message = "今天已经浇过水。"
		return false
	return true

func refill_farm_water() -> bool:
	if phase != "day" or not has_tool("wand"):
		message = "仅白天持有法杖时可补水。"
		return false
	if not require_selected_item("wand"): return false
	if not require_wand_mode("blue"): return false
	if farm.water == water_capacity():
		message = "储水已满。"
		return false
	farm.water = water_capacity()
	message = "储水已补满。"
	return true

func rain_on_farm() -> void:
	if phase == "result":
		return
	for plot in farm.plots.values():
		plot.watered = true

func _advance_farm_day() -> void:
	for plot in farm.plots.values():
		if plot.growth >= 0 and plot.growth < Campaign.crop_days(plot) and plot.watered:
			plot.growth += 1
		plot.watered = false

func catch_fish(id: String) -> bool:
	if phase != "day" or fish_left(id) <= 0:
		message = "鱼儿已散去。" if phase == "day" else "仅白天可以钓鱼。"
		return false
	if not has_tool("wand"):
		message = "需要法杖。"
		return false
	if not require_selected_item("wand"): return false
	if not Items.change(self, {"fish": 1}):
		message = "背包已满，无法取出。"
		return false
	fish_catches[id] = int(fish_catches.get(id, 0)) + 1
	journal.fish = mini(1000000000, journal.fish + 1)
	message = "钓到鱼 ×1"
	var fish_area: String = id.get_slice(":", 0) if ":" in id else "dock" if id.begins_with("dock") else "field"
	var named_fish := Campaign.record_fish(self, fish_area, journal.fish)
	if not named_fish.is_empty(): set_message("%s ×%d", [named_fish, 1])
	return true

func set_menu_dish(dish: int, enabled: bool) -> bool:
	if is_arrival_day(): return false
	if phase != "day" or dish < 0 or dish >= menu.size() or not Campaign.unlocked(self, dish):
		return false
	if enabled and not menu[dish] and menu.count(true) >= Campaign.restaurant(self).menu:
		message = "菜单已满"
		return false
	menu[dish] = enabled
	return true

func opening_error() -> String:
	if phase != "day": return "营业已开始。"
	if is_arrival_day(): return "食堂明天开始营业。"
	if not restaurant_leased: return "餐厅尚未承租。"
	if menu.count(true) == 0: return "菜单为空"
	if menu.count(true) > Campaign.restaurant(self).menu: return "菜单已满"
	for dish in range(menu.size()):
		if menu[dish] and not Campaign.unlocked(self, dish): return "菜品尚未解锁"
	return ""

func is_arrival_day() -> bool:
	return day == 1 and campaign.settling_in and phase == "day"

func rest_after_arrival() -> bool:
	if not is_arrival_day() or not campaign.guide_met: return false
	# Reuse the normal overnight inventory/farm reset without running a service
	# or producing a zero-income business report for the arrival day.
	phase = "result"
	next_day()
	message = "新的一天开始了。"
	return true

func start_service() -> bool:
	var error := opening_error()
	if not error.is_empty():
		message = error
		return false
	phase = "night"
	remaining = NIGHT_SECONDS
	arrivals = 0.0
	service_chain = 0
	service_peak = 0
	tips = 0
	guest_mood = int(daily_pulse.get("mood", 0))
	message = "夜间营业开始！"
	return true

func can_cook(dish: int) -> bool:
	if not Campaign.unlocked(self, dish): return false
	if dish >= 3: return Campaign.afford(self, Content.DATA.recipes[dish].cost)
	for i in range(3):
		if materials[i] < COSTS[dish][i]:
			return false
	return true

func dish_portions(dish: int) -> int:
	if not Campaign.unlocked(self, dish): return 0
	var count := 1000000000
	if dish < 3:
		for index in range(3):
			if COSTS[dish][index] > 0: count = mini(count, materials[index] / COSTS[dish][index])
	else:
		for id in Content.DATA.recipes[dish].cost:
			count = mini(count, campaign.pantry[id] / Content.DATA.recipes[dish].cost[id])
	return count

func service_exhausted() -> bool:
	if phase != "night" or cooking >= 0 or held >= 0 or not customers.is_empty(): return false
	for dish in range(menu.size()):
		if not menu[dish] or not Campaign.unlocked(self,dish): continue
		if dish >= 3:
			if can_cook(dish): return false
		else:
			var available := true
			for index in range(3):
				if materials[index] + raw[index] < COSTS[dish][index]: available = false
			if available: return false
	return true

func start_cook(dish: int) -> bool:
	if dish < 0 or dish >= menu.size(): return false
	if phase != "night" or cooking >= 0 or held >= 0:
		message = "当前无法烹饪。"
		return false
	if not menu[dish] or not can_cook(dish):
		message = "此菜未上菜单或原料不足，不扣库存。"
		return false
	if dish >= 3:
		Campaign.pay(self, Content.DATA.recipes[dish].cost)
	else:
		for i in range(3): materials[i] -= COSTS[dish][i]
	cooking = dish
	cook_left = Content.DATA.recipes[dish].seconds / Campaign.restaurant(self).speed
	message = "料理开始，原料已扣一次；3 秒后自动端起。"
	return true

func serve(seat: int) -> bool:
	var customer = customer_at(seat)
	if phase != "night" or customer == null or held < 0:
		message = "没有可送的菜或此座位为空。"
		return false
	if customer.get("status", "waiting") != "waiting":
		message = "这位客人正在用餐，暂不接单。"
		return false
	if customer.dish != held:
		message = "订单不符！菜仍在手上。"
		return false
	var recipe: Dictionary = Content.DATA.recipes[held]
	var focus_bonus := SeasonalDirector.dish_focus_bonus(recipe, daily_pulse)
	var base_income: int = PRICES[held] + Campaign.service(self, customer, held)
	service_chain += 1
	service_peak = maxi(service_peak, service_chain)
	guest_mood = clampi(guest_mood + 1 + focus_bonus, -3, 6)
	var chain_tip := 0
	if service_chain >= 2:
		chain_tip = roundi(float(PRICES[held]) * minf(0.18, 0.03 * float(service_chain - 1)))
	if focus_bonus > 0:
		chain_tip += maxi(1, roundi(float(PRICES[held]) * 0.05))
	tips += chain_tip
	income += base_income
	served += 1
	journal.serve = mini(1000000000, journal.serve + 1)
	set_message("上菜成功 +%d 金币（营业结束入账）", [base_income + chain_tip])
	held = -1
	customer.status = "eating"
	customer.eating_left = 3.0
	return true

func customer_at(seat: int):
	for c in customers:
		if c.seat == seat:
			return c
	return null

func admit() -> bool:
	if phase != "night" or customers.size() >= Campaign.restaurant(self).seats:
		return false
	var dishes: Array = []
	for i in range(mini(menu.size(), DISHES.size())):
		if menu[i] and can_cook(i):
			dishes.append(i)
	if dishes.is_empty():
		return false
	for seat in range(Campaign.restaurant(self).seats):
		if customer_at(seat) == null:
			var npc_index: int = serial % Content.DATA.npcs.size()
			var suitable: Array = []
			for dish in dishes:
				if Content.DATA.npcs[npc_index].dislike not in Content.DATA.recipes[dish].tags: suitable.append(dish)
			# Guests can still order from a limited menu, but prefer dishes that
			# respect their diet before considering favourite flavours.
			var choices: Array = suitable if not suitable.is_empty() else dishes
			var preferred: Array = []
			for dish in choices:
				for tag in Content.DATA.npcs[npc_index].likes:
					if tag in Content.DATA.recipes[dish].tags and dish not in preferred: preferred.append(dish)
			var available: Array = preferred if not preferred.is_empty() else choices
			var order: int = int(available[serial % available.size()])
			customers.append({"seat": seat, "dish": order, "patience": float(Campaign.restaurant(self).patience + Campaign.comfort(self)), "npc": npc_index, "variant": npc_index % 6, "status": "waiting", "eating_left": 0.0, "focus": SeasonalDirector.dish_focus_bonus(Content.DATA.recipes[order], daily_pulse) > 0})
			serial += 1
			return true
	return false

func tick(delta: float) -> void:
	if phase == "result":
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0:
		# Sunset waits for the player's menu and confirmation; it never opens service.
		if phase == "night": end_phase()
		return
	if phase != "night":
		return
	for i in range(customers.size() - 1, -1, -1):
		if customers[i].get("status", "waiting") == "eating":
			customers[i].eating_left -= delta
			if customers[i].eating_left <= 0:
				customers.remove_at(i)
			continue
		customers[i].patience -= delta
		if customers[i].patience <= 0:
			customers.remove_at(i)
			lost += 1
			service_chain = 0
			guest_mood = maxi(-3, guest_mood - 1)
	if cooking >= 0:
		cook_left = maxf(0.0, cook_left - delta)
		if cook_left <= 0:
			held = cooking
			cooking = -1
			message = "料理完成！"
	arrivals -= delta
	if arrivals <= 0:
		admit()
		arrivals = maxf(3.0, 6.0 - campaign.restaurant * 0.5)

func end_phase() -> void:
	if phase == "day":
		start_service()
	elif phase == "night":
		for customer in customers:
			if customer.get("status", "waiting") == "waiting": lost += 1
		customers.clear()
		if held >= 0:
			wasted += 1
			service_chain = 0
		if cooking >= 0:
			wasted += 1
		held = -1
		cooking = -1
		cook_left = 0.0
		income += tips
		coins += income
		phase = "result"
		remaining = 0.0
		result = "第 %d 天结算\n收入：%d 金币　累计：%d\n上菜：%d　离店：%d　废弃：%d\n小费：%d　最高连席：%d\n原食材和厨房原料保留；采集点次日刷新。" % [day, income, coins, served, lost, wasted, tips, service_peak]
		message = "营业结束。"

func next_day() -> void:
	if phase != "result":
		return
	_advance_farm_day()
	day += 1
	campaign.settling_in = false
	Campaign.advance_day(self)
	daily_pulse = SeasonalDirector.pulse_for_day(day)
	phase = "day"
	remaining = DAY_SECONDS
	nodes = [2, 2, 2, 2, 2, 2, 2, 2, 2]
	# The homestead stays cleared; only wild-region resources regrow daily.
	for id in resource_damage.keys():
		if not str(id).begins_with("farm_"): resource_damage.erase(id)
	fish_catches.clear()
	income = 0
	served = 0
	lost = 0
	wasted = 0
	service_chain = 0
	service_peak = 0
	tips = 0
	guest_mood = int(daily_pulse.get("mood", 0))
	message = "新的一天！库存与菜单保留，野外采集点已刷新。"

func can_craft_furniture(kind: String, area: String = "", player: Vector2 = Vector2.INF) -> bool:
	if phase != "day" or kind not in Furniture.IDS or not Furniture.bench_at(furniture, area, player): return false
	return furniture.stock[kind] < Furniture.MAX_STOCK and Items.can_change(self, Furniture.costs(kind))

func can_expand_house() -> bool:
	var plan := Furniture.House.upgrade_for(furniture)
	if phase != "day" or plan.is_empty(): return false
	var price: Dictionary = plan.price
	return coins >= price.coins and resources.wood >= price.wood and resources.iron >= price.iron and house_expansion_clear()

func can_rent_restaurant() -> bool:
	return phase == "day" and not restaurant_leased and coins >= RESTAURANT_RENT

func rent_restaurant() -> bool:
	if not can_rent_restaurant():
		message = "餐厅已承租。" if restaurant_leased else "柜台已打烊。" if phase != "day" else "金币不足。"
		return false
	coins -= RESTAURANT_RENT
	restaurant_leased = true
	message = "餐厅租约已生效。"
	return true

func house_expansion_clear() -> bool:
	var plan := Furniture.House.upgrade_for(furniture)
	if plan.is_empty(): return false
	var next := furniture.duplicate(true)
	next.house_level = plan.house_level
	next.exterior_level = plan.exterior_level
	var foundation := Furniture.House.outdoor_footprint(next)
	for item in furniture.placed:
		if Furniture.area_of(item) == "farm" and foundation.intersects(Furniture.footprint(item.kind, Furniture.position_of(item))): return false
	for key in farm.plots:
		var plot: Dictionary = farm.plots[key]
		if (plot.growth >= 0 or plot.get("fertilized", false)) and foundation.intersects(Rect2(FarmTerrain.tile_center(int(key)) - Vector2(15, 15), Vector2(30, 30))): return false
	for item in FarmTerrain.layout.props:
		if resource_left(item.resource_id) > 0 and foundation.intersects(Rect2(item.x - item.w / 2.0, item.y - item.h, item.w, item.h)): return false
	return true

func expand_house() -> bool:
	if not can_expand_house():
		message = "房屋已达最大面积。" if Furniture.House.upgrade_for(furniture).is_empty() else "柜台已打烊。" if phase != "day" else "扩建用地被占用。" if not house_expansion_clear() else "金币或材料不足。"
		return false
	var plan := Furniture.House.upgrade_for(furniture)
	var price: Dictionary = plan.price
	coins -= price.coins
	resources.wood -= price.wood
	resources.iron -= price.iron
	Items.ensure_bag(self)
	furniture.house_level = plan.house_level
	furniture.exterior_level = plan.exterior_level
	var foundation := Furniture.House.outdoor_footprint(furniture)
	for key in farm.plots.keys():
		if foundation.intersects(Rect2(FarmTerrain.tile_center(int(key)) - Vector2(15, 15), Vector2(30, 30))): farm.plots.erase(key)
	message = "房屋扩建完成。"
	return true

func craft_furniture(kind: String, area: String = "", player: Vector2 = Vector2.INF) -> bool:
	if not can_craft_furniture(kind, area, player):
		message = "附近没有工作台。" if not Furniture.bench_at(furniture, area, player) else "材料不足或家具收纳已满。"
		return false
	var recipe: Dictionary = Furniture.RECIPES[kind]
	if not Items.change(self, Furniture.costs(kind)): return false
	furniture.stock[kind] += 1
	set_message("已制作%s。", [recipe.title])
	return true

func furniture_by_id(id: int) -> Dictionary:
	for item in furniture.placed:
		if item.id == id: return item
	return {}

func place_furniture(kind: String, point: Vector2, player: Vector2, area: String = "home") -> bool:
	if phase != "day" or kind not in Furniture.IDS or furniture.stock[kind] <= 0: return false
	point = point.round()
	if furniture.placed.size() >= Furniture.MAX_PLACED or furniture.next_id >= 1000000000:
		message = "房间家具已达上限。"
		return false
	var error := Furniture.placement_error(furniture, kind, point, -1, player, area, {"farm": farm, "resource_damage": resource_damage})
	if not error.is_empty():
		message = error
		return false
	var item := {"id": furniture.next_id, "kind": kind, "x": roundi(point.x), "y": roundi(point.y)}
	if area == "farm": item.area = area
	if kind == "chest":
		item["items"] = {}
		item["slots"] = Items.empty_slots(Items.CHEST_SLOTS)
	furniture.placed.append(item)
	furniture.next_id += 1
	furniture.stock[kind] -= 1
	set_message("已摆放%s。", [Furniture.RECIPES[kind].title])
	return true

func move_furniture(id: int, point: Vector2, player: Vector2) -> bool:
	var item := furniture_by_id(id)
	if phase != "day" or item.is_empty(): return false
	point = point.round()
	var error := Furniture.placement_error(furniture, item.kind, point, id, player, Furniture.area_of(item), {"farm": farm, "resource_damage": resource_damage})
	if not error.is_empty():
		message = error
		return false
	item.x = roundi(point.x)
	item.y = roundi(point.y)
	set_message("已移动%s。", [Furniture.RECIPES[item.kind].title])
	return true

func store_furniture(id: int) -> bool:
	var item := furniture_by_id(id)
	if phase != "day" or item.is_empty() or furniture.stock[item.kind] >= Furniture.MAX_STOCK: return false
	if item.kind == "chest" and not item.get("items", {}).is_empty():
		message = "箱子内仍有物品"
		return false
	furniture.stock[item.kind] += 1
	furniture.placed.erase(item)
	set_message("已收回%s。", [Furniture.RECIPES[item.kind].title])
	return true

func transfer_chest(id: int, item_id: String, requested: int, deposit: bool) -> int:
	var chest := furniture_by_id(id)
	if phase == "result" or chest.is_empty() or chest.kind != "chest" or item_id not in Items.IDS or requested <= 0: return 0
	if not inventory_pending.is_empty(): return 0
	Items.ensure_bag(self)
	var source: Array = bag_slots if deposit else Items.chest_slots(chest)
	var destination: Array = Items.chest_slots(chest) if deposit else bag_slots
	var available := int(Items.totals(source).get(item_id, 0))
	var amount := mini(requested, mini(available, Items.room_in(destination, item_id)))
	if amount <= 0:
		message = "没有可转移的物品。" if available <= 0 else "箱子已满。" if deposit else "背包已满，无法取出。"
		return 0
	Items.remove(source, item_id, amount)
	Items.insert(destination, item_id, amount)
	Items.sync(self)
	Items.sync_chest(chest)
	set_message("已存入%s ×%d。" if deposit else "已取出%s ×%d。", [Items.NAMES[item_id], amount])
	return amount

func discard() -> void:
	if held >= 0:
		held = -1
		wasted += 1
		message = "已丢弃手中的菜（不退原料）。"

# Explicit, versioned save data: never deserialize objects or scripts from disk.
const SAVE_FIELDS = ["day", "phase", "remaining", "raw", "tools", "materials", "menu", "nodes", "resources", "resource_damage", "fish_catches", "customers", "cooking", "cook_left", "held", "income", "coins", "served", "lost", "wasted", "arrivals", "serial", "result", "message", "journal", "farm", "furniture", "equipment", "bag_slots", "bag_overflow", "campaign", "selected_hotbar_slot", "wand_mode", "service_chain", "service_peak", "tips", "guest_mood", "crop_quality_total", "crop_harvests", "restaurant_leased"]

func to_save_data() -> Dictionary:
	Items.ensure_bag(self)
	var data := {}
	for field in SAVE_FIELDS:
		var value = get(field)
		data[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	if not inventory_pending.is_empty():
		data.bag_slots = inventory_pending.bag.duplicate(true)
		Items.sync(data)
		for chest in data.furniture.placed:
			if chest.id == inventory_pending.chest_id:
				chest.slots = inventory_pending.chest.duplicate(true)
				Items.sync_chest(chest)
	data["day_length_seconds"] = DAY_LENGTH_SECONDS
	data["day_seconds"] = DAY_SECONDS
	data["night_seconds"] = NIGHT_SECONDS
	return data

func restore_save_data(data: Variant) -> bool:
	var normalized := normalize_save_data(data)
	if normalized.is_empty():
		return false
	for field in SAVE_FIELDS:
		set(field, normalized[field])
	daily_pulse = SeasonalDirector.pulse_for_day(day)
	inventory_pending.clear()
	return true

static func _number(value: Variant, minimum: float, maximum: float, integer: bool = false) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and (not integer or float(value) == floorf(float(value)))

static func normalize_save_data(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var saved_tools: Variant = data.get("tools", LEGACY_STARTING_TOOLS)
	if not saved_tools is Dictionary: return {}
	var legacy_tools: bool = saved_tools.has("axe")
	var tool_defaults: Dictionary = LEGACY_STARTING_TOOLS if legacy_tools else STARTING_TOOLS
	var inventory_ids: Array = Items.LEGACY_IDS if legacy_tools else Items.IDS
	for field in SAVE_FIELDS:
		if field not in ["journal", "tools", "farm", "furniture", "equipment", "bag_slots", "bag_overflow", "campaign", "selected_hotbar_slot", "wand_mode", "service_chain", "service_peak", "tips", "guest_mood", "crop_quality_total", "crop_harvests", "restaurant_leased"] and not data.has(field):
			return {}
	if data.phase not in ["day", "night", "result"]:
		return {}
	var normalized: Dictionary = data.duplicate(true)
	# Pre-property saves already operated the restaurant and keep their rights.
	var leased: Variant = data.get("restaurant_leased", true)
	if not leased is bool or (data.phase != "day" and not leased): return {}
	normalized.restaurant_leased = leased
	var saved_mode: Variant = data.get("wand_mode", "red")
	if not saved_mode is String or saved_mode not in ["blue", "red"]: return {}
	normalized.wand_mode = saved_mode
	var saved_selection: Variant = data.get("selected_hotbar_slot", 0)
	if not _number(saved_selection, 0, Items.HOTBAR_SLOTS - 1, true): return {}
	normalized.selected_hotbar_slot = int(saved_selection)
	normalized.campaign = Campaign.normalize(data.get("campaign", Campaign.initial()))
	if normalized.campaign.is_empty(): return {}
	normalized.equipment = Equipment.normalize(data.get("equipment", Equipment.LEGACY_LEVELS if legacy_tools else Equipment.DEFAULT_LEVELS), legacy_tools)
	if normalized.equipment.is_empty(): return {}
	# Older saves retain the original authored home, now as movable furniture.
	normalized.furniture = Furniture.normalize(data.get("furniture", Furniture.legacy_data()), legacy_tools)
	if normalized.furniture.is_empty(): return {}
	# Optional schema-1 addition: existing saves receive a fresh farm.
	var saved_farm: Variant = data.get("farm", STARTING_FARM)
	if not saved_farm is Dictionary or not saved_farm.get("plots") is Dictionary or saved_farm.plots.size() > FARM_TILE_COUNT:
		return {}
	if not _number(saved_farm.get("seeds"), 0, 999999, true) or not _number(saved_farm.get("water"), 0, Equipment.WATER_CAPACITIES[normalized.equipment["watering_can" if legacy_tools else "wand"]], true):
		return {}
	normalized.farm = {"plots": {}, "seeds": int(saved_farm.seeds), "water": int(saved_farm.water)}
	for key in saved_farm.plots:
		if not key is String or not key.is_valid_int() or str(int(key)) != key or int(key) < 0 or int(key) >= FARM_TILE_COUNT:
			return {}
		var plot: Variant = saved_farm.plots[key]
		if not plot is Dictionary or str(plot.get("crop", "herb")) not in normalized.campaign.seeds or not _number(plot.get("growth"), -1, Campaign.crop_days(plot), true) or not plot.get("watered") is bool:
			return {}
		normalized.farm.plots[key] = {"growth": int(plot.growth), "watered": plot.watered}
		if plot.has("crop"): normalized.farm.plots[key].crop = plot.crop
		if plot.has("fertilized"):
			if not plot.fertilized is bool: return {}
			normalized.farm.plots[key].fertilized = plot.fertilized
	# Saves from before tools were inventoried receive the same starter set.
	if saved_tools.size() != tool_defaults.size():
		return {}
	normalized.tools = {}
	for id in tool_defaults:
		if not _number(saved_tools.get(id), 0, 1, true):
			return {}
		normalized.tools[id] = int(saved_tools[id])
	# Older saves used a 3:2 split and closed at midnight. Keep phase progress,
	# including active orders and cooking, when migrating to the shorter service.
	var saved_day_length: Variant = data.get("day_length_seconds", 300.0)
	if not _number(saved_day_length, 1.0, 86400.0):
		return {}
	var saved_day_seconds: Variant = data.get("day_seconds", float(saved_day_length) * 0.6)
	var saved_night_seconds: Variant = data.get("night_seconds", float(saved_day_length) * 0.4)
	if data.has("day_seconds") != data.has("night_seconds") or not _number(saved_day_seconds, 1.0, 86400.0) or not _number(saved_night_seconds, 1.0, 86400.0): return {}
	if not is_equal_approx(float(saved_day_seconds) + float(saved_night_seconds), float(saved_day_length)): return {}
	var saved_phase_seconds: float = float(saved_night_seconds) if data.phase == "night" else float(saved_day_seconds)
	# Optional addition to schema 1: existing six-slot saves remain readable.
	var saved_journal: Variant = data.get("journal", {"gather": 0, "prepare": 0, "serve": 0, "fish": 0, "tracked": "gather"})
	if not saved_journal is Dictionary or saved_journal.get("tracked") not in ["gather", "prepare", "serve", "fish"]:
		return {}
	normalized.journal = {"tracked": saved_journal.tracked}
	for objective in ["gather", "prepare", "serve", "fish"]:
		if not _number(saved_journal.get(objective), 0, 1000000000, true):
			return {}
		normalized.journal[objective] = int(saved_journal[objective])
	var integer_fields := {"day": [1, 1000000], "cooking": [-1, DISHES.size()-1], "held": [-1, DISHES.size()-1], "income": [0, 1000000000], "coins": [0, 1000000000], "served": [0, 1000000000], "lost": [0, 1000000000], "wasted": [0, 1000000000], "serial": [0, 1000000000], "service_chain": [0, 1000000000], "service_peak": [0, 1000000000], "tips": [0, 1000000000], "guest_mood": [-3, 6], "crop_quality_total": [0, 1000000000], "crop_harvests": [0, 1000000000]}
	for field in integer_fields:
		var bounds: Array = integer_fields[field]
		var candidate: Variant = data.get(field, 0)
		if not _number(candidate, bounds[0], bounds[1], true):
			return {}
		normalized[field] = int(candidate)
	for field in {"remaining": saved_phase_seconds, "cook_left": 8.0, "arrivals": 6.0}:
		var maximum: float = {"remaining": saved_phase_seconds, "cook_left": 8.0, "arrivals": 6.0}[field]
		if not _number(data[field], 0.0, maximum):
			return {}
		normalized[field] = float(data[field])
	normalized.remaining *= (NIGHT_SECONDS if data.phase == "night" else DAY_SECONDS) / saved_phase_seconds
	if data.phase == "result": normalized.remaining = 0.0
	normalized["day_length_seconds"] = DAY_LENGTH_SECONDS
	normalized["day_seconds"] = DAY_SECONDS
	normalized["night_seconds"] = NIGHT_SECONDS
	for field in ["raw", "materials", "menu", "nodes"]:
		if not data[field] is Array or (data[field].size() not in [3, 36, DISHES.size()] if field == "menu" else data[field].size() != (9 if field == "nodes" else 3)):
			return {}
		for i in range(data[field].size()):
			if field == "menu":
				if not data[field][i] is bool:
					return {}
			else:
				var maximum: int = 2 if field == "nodes" else Equipment.BAG_CAPACITIES[normalized.equipment.bag] * (Items.STACK_SIZE if data.has("bag_slots") else 1) if field == "raw" else 1000000000
				if not _number(data[field][i], 0, maximum, true):
					return {}
				normalized[field][i] = int(data[field][i])
	while normalized.menu.size() < DISHES.size(): normalized.menu.append(false)
	if normalized.menu.count(true) > Campaign.restaurant(normalized).menu: return {}
	for index in range(normalized.menu.size()):
		if normalized.menu[index] and not Campaign.unlocked(normalized,index): return {}
	if not data.has("bag_slots") and normalized.raw[0] + normalized.raw[1] + normalized.raw[2] > Equipment.BAG_CAPACITIES[normalized.equipment.bag]:
		return {}
	if not data.resources is Dictionary:
		return {}
	for kind in RESOURCE_NAMES:
		if not _number(data.resources.get(kind), 0, 1000000000, true):
			return {}
		normalized.resources[kind] = int(data.resources[kind])
	for field in ["resource_damage", "fish_catches"]:
		if not data[field] is Dictionary or data[field].size() > 1000:
			return {}
		for id in data[field]:
			if not id is String or id.is_empty() or id.length() > 80 or not _number(data[field][id], 0, 3 + (int(normalized.campaign.rod if legacy_tools else normalized.equipment.wand) if field == "fish_catches" else 0), true):
				return {}
			normalized[field][id] = int(data[field][id])
	if not data.customers is Array or data.customers.size() > Campaign.restaurant(normalized).seats:
		return {}
	var seats := []
	for customer in normalized.customers:
		if not customer is Dictionary:
			return {}
		for field in {"seat": Campaign.restaurant(normalized).seats-1, "dish": DISHES.size()-1, "variant": 5}:
			var maximum: int = {"seat": Campaign.restaurant(normalized).seats-1, "dish": DISHES.size()-1, "variant": 5}[field]
			if not _number(customer.get(field), 0, maximum, true):
				return {}
			customer[field] = int(customer[field])
		if customer.has("npc") and not _number(customer.npc, 0, Content.DATA.npcs.size()-1, true): return {}
		if customer.seat in seats or customer.get("status") not in ["waiting", "eating"] or not _number(customer.get("patience"), 0, Campaign.restaurant(normalized).patience + 12) or not _number(customer.get("eating_left"), 0, 3):
			return {}
		seats.append(customer.seat)
	for field in ["result", "message"]:
		if not data[field] is String or data[field].length() > 8000:
			return {}
	if data.phase != "night" and (data.cooking != -1 or data.held != -1 or not data.customers.is_empty()):
		return {}
	if data.cooking >= 0 and data.held >= 0:
		return {}
	var overflow := Items.normalize_contents(data.get("bag_overflow", {}), 1000000000, legacy_tools)
	if not overflow.ok: return {}
	normalized.bag_overflow = overflow.items
	var capacity: int = Equipment.BAG_CAPACITIES[normalized.equipment.bag]
	if data.has("bag_slots"):
		var grid := Items.normalize_slots(data.bag_slots, capacity, legacy_tools)
		if not grid.ok: return {}
		normalized.bag_slots = grid.slots
		var quantities := Items.totals(grid.slots)
		for id in inventory_ids:
			if Items.count(normalized, id) != int(quantities.get(id, 0)): return {}
	else:
		normalized.bag_slots = Items.empty_slots(capacity)
		for id in inventory_ids:
			var amount: int = Items.count(normalized, id)
			var extra := amount - Items.insert(normalized.bag_slots, id, amount)
			if extra > 0: normalized.bag_overflow[id] = int(normalized.bag_overflow.get(id, 0)) + extra
		var quantities := Items.totals(normalized.bag_slots)
		for id in tool_defaults: normalized.tools[id] = int(quantities.get(id, 0))
		for i in range(Items.RAW.size()): normalized.raw[i] = int(quantities.get(Items.RAW[i], 0))
		for id in Items.RESOURCES: normalized.resources[id] = int(quantities.get(id, 0))
		normalized.farm.seeds = int(quantities.get("seed", 0))
	for id in tool_defaults:
		var owned: int = normalized.tools[id] + int(normalized.bag_overflow.get(id, 0))
		for item in normalized.furniture.placed:
			if item.kind == "chest": owned += int(item.items.get(id, 0))
		if owned > 1 or (owned == 0 and normalized.equipment[id] > 0): return {}
	for item in normalized.furniture.placed:
		if Furniture.area_of(item) == "farm" and not Furniture.farm_placement_error(item.kind, Furniture.footprint(item.kind, Furniture.position_of(item)), normalized).is_empty(): return {}
	if normalized.furniture.exterior_level > 0:
		var foundation := Furniture.House.outdoor_footprint(normalized.furniture)
		for key in normalized.farm.plots:
			if foundation.intersects(Rect2(FarmTerrain.tile_center(int(key)) - Vector2(15, 15), Vector2(30, 30))): return {}
	if legacy_tools: Items.migrate_tools(normalized)
	normalized.daily_pulse = SeasonalDirector.pulse_for_day(int(normalized.day))
	return normalized
