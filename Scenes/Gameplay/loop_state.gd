extends RefCounted
## All inventory mutations live here; no UI-only copies.
const INGREDIENTS = ["蘑菇", "莓果", "香草"]
const MATERIALS = ["切片菇", "莓果酱", "香草料"]
const DISHES = ["蘑菇汤", "莓果派", "香草炖菇"]
const COSTS = [[2, 0, 0], [0, 2, 0], [1, 0, 1]]
const PRICES = [12, 14, 18]
const CAPACITY = 12
const DAY_SECONDS = 180.0
const NIGHT_SECONDS = 120.0
const COOK_SECONDS = 3.0
const PATIENCE = 25.0
var day = 1
var phase = "day"
var remaining = DAY_SECONDS
var raw = [0, 0, 0]
var materials = [0, 0, 0]
var menu = [true, true, true]
var nodes = [2, 2, 2, 2, 2, 2, 2, 2, 2]
const RESOURCE_NAMES = {"wood": "木材", "ore": "矿石", "fish": "鱼"}
const RESOURCE_HITS = 3
const FISH_PER_DAY = 3
var resources = {"wood": 0, "ore": 0, "fish": 0}
var resource_damage = {}
var fish_catches = {}
var customers: Array = []
var cooking = -1
var cook_left = 0.0
var held = -1
var income = 0
var coins = 0
var served = 0
var lost = 0
var wasted = 0
var arrivals = 0.0
var serial = 0
var result = ""
var message = "沿小镇路标去野外采集，再回餐厅备料。"

func gather(index: int) -> bool:
	if phase != "day":
		message = "仅白天可以采集。"
		return false
	if nodes[index] <= 0:
		message = "这里已采完，次日刷新。"
		return false
	if raw[0] + raw[1] + raw[2] >= CAPACITY:
		message = "背包已满（12），回餐厅加工腾出空间。"
		return false
	raw[index % 3] += 1
	nodes[index] -= 1
	message = "采得" + INGREDIENTS[index % 3] + " ×1"
	return true

func process_raw() -> bool:
	if phase == "result":
		return false
	var count = raw[0] + raw[1] + raw[2]
	for i in range(3):
		materials[i] += raw[i]
		raw[i] = 0
	message = "加工完成：原食材 1:1 转为厨房原料。" if count > 0 else "背包没有原食材；可去采集或直接结束阶段。"
	return count > 0

func resource_left(id: String) -> int:
	return RESOURCE_HITS - int(resource_damage.get(id, 0))

func strike_resource(id: String, kind: String) -> int:
	if phase != "day" or kind not in ["wood", "ore"] or resource_left(id) <= 0:
		message = "这里已采完，次日刷新。" if phase == "day" else "仅白天可以采集。"
		return -1
	resource_damage[id] = int(resource_damage.get(id, 0)) + 1
	var left := resource_left(id)
	if left == 0:
		var amount := 3 if kind == "wood" else 2
		resources[kind] += amount
		message = "采得%s ×%d" % [RESOURCE_NAMES[kind], amount]
	return left

func fish_left(id: String) -> int:
	return FISH_PER_DAY - int(fish_catches.get(id, 0))

func catch_fish(id: String) -> bool:
	if phase != "day" or fish_left(id) <= 0:
		message = "鱼儿已散去，次日再来。" if phase == "day" else "仅白天可以钓鱼。"
		return false
	fish_catches[id] = int(fish_catches.get(id, 0)) + 1
	resources.fish += 1
	message = "钓到鱼 ×1"
	return true

func can_cook(dish: int) -> bool:
	for i in range(3):
		if materials[i] < COSTS[dish][i]:
			return false
	return true

func start_cook(dish: int) -> bool:
	if phase != "night" or cooking >= 0 or held >= 0:
		message = "仅夜间烹饪；请先送出手中的菜，或等待当前料理完成。"
		return false
	if not menu[dish] or not can_cook(dish):
		message = "此菜未上菜单或原料不足，不扣库存。"
		return false
	for i in range(3):
		materials[i] -= COSTS[dish][i]
	cooking = dish
	cook_left = COOK_SECONDS
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
		message = "订单不符！菜仍在手上，找正确客人或丢弃。"
		return false
	income += PRICES[held]
	served += 1
	message = "上菜成功 +" + str(PRICES[held]) + " 金币（营业结束入账）"
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
	if phase != "night" or customers.size() >= 3:
		return false
	var dishes: Array = []
	for i in range(3):
		if menu[i] and can_cook(i):
			dishes.append(i)
	if dishes.is_empty():
		return false
	for seat in range(3):
		if customer_at(seat) == null:
			customers.append({"seat": seat, "dish": dishes[serial % dishes.size()], "patience": PATIENCE, "variant": serial % 6, "status": "waiting", "eating_left": 0.0})
			serial += 1
			return true
	return false

func tick(delta: float) -> void:
	if phase == "result":
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0:
		end_phase()
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
	if cooking >= 0:
		cook_left = maxf(0.0, cook_left - delta)
		if cook_left <= 0:
			held = cooking
			cooking = -1
			message = "菜做好了！走近对应客人按 E 上菜。"
	arrivals -= delta
	if arrivals <= 0:
		admit()
		arrivals = 6.0

func end_phase() -> void:
	if phase == "day":
		phase = "night"
		remaining = NIGHT_SECONDS
		arrivals = 0.0
		message = "夜间营业开始！E 备料；走近料理台选菜。缺货可随时结束。"
	elif phase == "night":
		lost += customers.size()
		customers.clear()
		if held >= 0:
			wasted += 1
		if cooking >= 0:
			wasted += 1
		held = -1
		cooking = -1
		cook_left = 0.0
		coins += income
		phase = "result"
		result = "第 %d 天结算\n收入：%d 金币　累计：%d\n上菜：%d　离店：%d　废弃：%d\n原食材和厨房原料保留；采集点次日刷新。" % [day, income, coins, served, lost, wasted]
		message = "营业结束，点击「进入次日」继续。"

func next_day() -> void:
	if phase != "result":
		return
	day += 1
	phase = "day"
	remaining = DAY_SECONDS
	nodes = [2, 2, 2, 2, 2, 2, 2, 2, 2]
	resource_damage.clear()
	fish_catches.clear()
	income = 0
	served = 0
	lost = 0
	wasted = 0
	message = "新的一天！库存与菜单保留，野外采集点已刷新。"

func discard() -> void:
	if held >= 0:
		held = -1
		wasted += 1
		message = "已丢弃手中的菜（不退原料）。"
