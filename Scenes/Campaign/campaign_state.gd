extends RefCounted
## Campaign transactions use the same host state, coins, phase and save slot.
const Content = preload("res://Scenes/Campaign/content.gd")
const D = Content.DATA
const LIMIT := 1000000000
const DEFAULT_PLAYER_NAME := "艾洛温"
const PLAYER_NAME_LIMIT := 12
const SIDE_LIMIT := 2
const BANQUET_IDS := ["star_koi_banquet", "four_seasons_platter", "lantern_dessert"]
const SIDE_CHAPTERS := {"mori": 1, "toma": 1, "lumi": 2, "orla": 2, "ember": 3, "reed": 3, "nagi": 4, "aster": 6, "pip": 6, "yuki": 8}
static var pending_intro := false

static func initial() -> Dictionary:
	var result := {"version": 1, "introduced": false, "region": "field", "selected_crop": "herb", "restaurant": 0, "rod": 0, "reputation": 0, "chapter": 0, "seeds": {}, "pantry": {}, "residents": {}, "stats": {}, "harvested": {}, "gathered": {}, "stock": {}, "placed": [], "machines": {"sprinkler": 0, "mill": 0, "hive": 0, "greenhouse": 0}, "festival_days": []}
	result.player_name = DEFAULT_PLAYER_NAME
	result.guide_met = false
	result.story_version = 2
	result.legacy_chapter = 0
	result.opening_stage = 0
	result.pending_scene = -1
	result.settling_in = false
	result.met_residents = []
	result.side_active = {}
	result.side_last_day = {}
	for crop in D.crops: result.seeds[crop.id] = 0
	result.seeds.turnip = 6
	result.seeds.carrot = 4
	result.seeds.lettuce = 4
	for id in D.items: result.pantry[id] = 0
	for id in ["egg", "milk", "flour", "oil", "salt", "rice"]: result.pantry[id] = 4
	for npc in D.npcs: result.residents[npc.id] = {"affinity": 0, "story": 0, "talk_day": 0, "gift_day": 0}
	for id in ["gather", "harvest", "ore", "scrap", "crystal", "fish", "stories", "banquet", "serve"]: result.stats[id] = 0
	result.stats.ridge = 0
	for item in D.furniture: result.stock[item.id] = 0
	return result

## Validate names retained from older saves.
static func valid_player_name(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > PLAYER_NAME_LIMIT or value != value.strip_edges(): return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159) or code in [0x2028, 0x2029]: return false
	return true

static func entry(list: Array, id: String) -> Dictionary:
	for value in list:
		if value.id == id: return value
	return {}

static func season(s) -> int:
	return ((s.day - 1) / 28) % 4

static func calendar(s) -> String:
	return TranslationServer.translate("%s · 第%d年 · %d日") % [TranslationServer.translate(D.seasons[season(s)]), 1 + (s.day - 1) / 112, 1 + (s.day - 1) % 28]

static func restaurant(s) -> Dictionary:
	return D.upgrades[s.campaign.restaurant]

static func crop_days(plot: Dictionary) -> int:
	var crop := entry(D.crops, str(plot.get("crop", "herb")))
	return int(crop.get("days", 3))

static func add(s, id: String, amount: int) -> void:
	if id in s.campaign.pantry:
		s.campaign.pantry[id] = clampi(int(s.campaign.pantry[id]) + amount, 0, LIMIT)

static func stat(s, id: String, amount: int = 1) -> void:
	if id in s.campaign.stats:
		s.campaign.stats[id] = clampi(int(s.campaign.stats[id]) + amount, 0, LIMIT)

static func afford(s, cost: Dictionary) -> bool:
	for id in cost:
		if id not in s.campaign.pantry or s.campaign.pantry[id] < cost[id]: return false
	return true

static func pay(s, cost: Dictionary) -> void:
	for id in cost: add(s, id, -int(cost[id]))

static func unlocked(s, dish: int) -> bool:
	return dish >= 0 and dish < D.recipes.size() and D.recipes[dish].tier <= s.campaign.restaurant

static func buy_seed(s, id: String) -> bool:
	var crop := entry(D.crops, id)
	if s.phase != "day" or crop.is_empty(): return false
	if season(s) not in crop.seasons and s.campaign.machines.greenhouse == 0:
		s.message = "季节不符"
		return false
	if s.coins < crop.buy:
		s.message = "金币不足"
		return false
	if s.campaign.seeds[id] >= 999999: return false
	s.coins -= crop.buy
	s.campaign.seeds[id] += 1
	s.message = "购入"
	return true

static func trade(s, id: String, buying: bool) -> bool:
	if s.phase != "day" or id not in D.items: return false
	var item: Dictionary = D.items[id]
	# Existing wild ingredients retain their exploration and fishing sources.
	if buying and not item.get("shop", false): return false
	if buying:
		if s.coins < item.buy or s.campaign.pantry[id] >= LIMIT:
			s.message = "金币不足"
			return false
		s.coins -= item.buy
		add(s, id, 1)
	else:
		if s.campaign.pantry[id] <= 0:
			s.message = "材料不足"
			return false
		add(s, id, -1)
		s.coins += item.sell
	s.message = "购入" if buying else "售出"
	return true

static func farm_action(s, index: int) -> bool:
	if s.phase != "day" or index < 0 or index >= s.FARM_TILE_COUNT: return false
	if s.wand_mode == "red" and s.is_item_selected("wand") and not s.require_wand_mode("blue"): return false
	var key := str(index)
	if not s.farm.plots.has(key): return false
	var plot: Dictionary = s.farm.plots[key]
	var id: String = str(plot.get("crop", s.campaign.selected_crop))
	if plot.growth < 0: id = s.campaign.selected_crop
	var crop := entry(D.crops, id)
	if crop.is_empty(): return false
	if plot.growth < 0:
		if season(s) not in crop.seasons and s.campaign.machines.greenhouse == 0:
			s.message = "季节不符"
			return false
		if s.campaign.seeds[id] <= 0:
			s.message = "种子不足"
			return false
		s.campaign.seeds[id] -= 1
		plot.crop = id
		plot.growth = 0
		plot.fertilized = false
		s.message = "播种完成"
	elif plot.growth >= crop.days:
		var amount: int = crop.yield_count + (1 if plot.get("fertilized", false) else 0)
		amount += s.crop_quality_bonus(plot)
		add(s, id, amount)
		s.record_crop_quality(plot)
		s.campaign.harvested[id] = true
		stat(s, "harvest", amount)
		s.journal.gather += amount
		plot.growth = maxi(0, int(crop.days) - int(crop.regrow)) if crop.regrow > 0 else -1
		plot.fertilized = false
		s.message = "收获完成"
		s.register_town_event("harvest")
	elif not plot.watered:
		if not s.has_tool("wand"):
			s.message = "需要法杖。"
			return false
		if not s.require_selected_item("wand"): return false
		if not s.require_wand_mode("blue"): return false
		if s.farm.water <= 0:
			s.message = "储水已空。"
			return false
		s.farm.water -= 1
		plot.watered = true
		s.message = "浇水完成"
	else:
		s.message = "今天已经浇过水。"
		return false
	return true

static func fertilize(s, index: int) -> bool:
	var plot: Dictionary = s.farm.plots.get(str(index), {})
	if s.phase != "day" or plot.is_empty() or plot.growth < 0: return false
	if plot.get("fertilized", false):
		s.message = "今日已施肥"
		return false
	if s.coins < 3:
		s.message = "金币不足"
		return false
	s.coins -= 3
	plot.fertilized = true
	s.message = "施肥"
	return true

static func advance_day(s) -> void:
	s.campaign.gathered.clear()
	# Crops outside the new season become empty tilled soil. Greenhouse protects all plots.
	for key in s.farm.plots:
		var plot: Dictionary = s.farm.plots[key]
		var crop := entry(D.crops, str(plot.get("crop", "herb")))
		if season(s) not in crop.seasons and s.campaign.machines.greenhouse == 0:
			plot.growth = -1
		if int(key) < s.campaign.machines.sprinkler * 24: plot.watered = true
	if s.campaign.machines.hive > 0: add(s, "honey", s.campaign.machines.hive)
	var milled := mini(int(s.campaign.pantry.wheat), int(s.campaign.machines.mill) * 2)
	add(s, "wheat", -milled)
	add(s, "flour", milled)

static func gather(s, area: String, index: int) -> bool:
	var region := entry(D.regions, area)
	if s.phase != "day" or not region_unlocked(s, region) or index < 0 or index >= 6: return false
	var key := area + ":" + str(index)
	if s.campaign.gathered.get(key, 0) >= 2:
		s.message = "已售罄"
		return false
	var id: String = region.items[index % region.items.size()]
	s.campaign.gathered[key] = int(s.campaign.gathered.get(key, 0)) + 1
	add(s, id, 1)
	stat(s, id)
	stat(s, "gather")
	if area == "ridge": stat(s, "ridge")
	s.journal.gather += 1
	s.set_message("%s ×%d", [D.items[id].name, 1])
	s.register_town_event("gather")
	return true

static func eligible_fish(s, area: String) -> Array:
	var result := []
	var hour: float = s.get_time_minutes() / 60.0
	for fish in D.fish:
		if fish.area == area and season(s) in fish.seasons and hour >= fish.start and hour < fish.end:
			result.append(fish)
	return result

static func record_fish(s, area: String, serial: int) -> String:
	var pool := eligible_fish(s, area)
	if pool.is_empty(): return ""
	var fish: Dictionary = pool[(s.day + serial) % pool.size()]
	add(s, fish.id, 1)
	stat(s, "fish")
	return fish.name

static func talk(s, id: String) -> Array:
	var npc := entry(D.npcs, id)
	if npc.is_empty(): return []
	var r: Dictionary = s.campaign.residents[id]
	if r.talk_day != s.day:
		r.affinity = mini(1000, int(r.affinity) + 12)
		r.talk_day = s.day
	if id not in s.campaign.met_residents: s.campaign.met_residents.append(id)
	discover_side(s, id)
	return [npc.lines[mini(4, int(r.story))]]

static func gift(s, id: String) -> bool:
	var npc := entry(D.npcs, id)
	if npc.is_empty() or s.phase == "result": return false
	var r: Dictionary = s.campaign.residents[id]
	if r.gift_day == s.day:
		s.message = "今日已赠礼"
		return false
	if s.campaign.pantry[npc.gift] <= 0:
		s.message = "材料不足"
		return false
	add(s, npc.gift, -1)
	var birthday: bool = season(s) == npc.birthday[0] and (s.day - 1) % 28 + 1 == npc.birthday[1]
	r.affinity = mini(1000, int(r.affinity) + (120 if birthday else 40))
	r.gift_day = s.day
	s.message = "赠礼"
	return true

static func current_main(s) -> Dictionary:
	if s.campaign.chapter >= D.quests.size(): return {}
	return D.quests[s.campaign.chapter]

static func side_chapter(id: String, stage: int) -> int:
	return mini(10, int(SIDE_CHAPTERS.get(id, 12)) + stage * 2)

static func region_unlocked(s, region: Dictionary) -> bool:
	return not region.is_empty() and (s.campaign.chapter >= region.chapter or s.campaign.legacy_chapter >= region.legacy_chapter)

static func side_progress(s) -> int:
	return maxi(s.campaign.chapter, s.campaign.legacy_chapter)

static func discover_side(s, id: String) -> bool:
	if s.phase != "day" or id not in s.campaign.met_residents: return false
	if s.campaign.side_active.has(id) or s.campaign.side_active.size() >= SIDE_LIMIT: return false
	var r: Dictionary = s.campaign.residents[id]
	if r.story >= 4 or side_progress(s) < side_chapter(id, r.story): return false
	if r.affinity < r.story * 200 or s.campaign.side_last_day.get(id, 0) >= s.day: return false
	s.campaign.side_active[id] = int(r.story)
	return true

static func side_ready(s, id: String) -> bool:
	if s.phase != "day" or not s.campaign.side_active.has(id): return false
	var npc := entry(D.npcs, id)
	var r: Dictionary = s.campaign.residents[id]
	return r.affinity >= (r.story + 1) * 200 and afford(s, {npc.gift: r.story + 1})

static func defer_side(s, id: String) -> bool:
	if not s.campaign.side_active.has(id): return false
	s.campaign.side_active.erase(id)
	s.campaign.side_last_day[id] = s.day
	return true

static func story(s, id: String) -> bool:
	var npc := entry(D.npcs, id)
	if npc.is_empty(): return false
	var r: Dictionary = s.campaign.residents[id]
	if r.story >= 4 or not s.campaign.side_active.has(id) or r.affinity < (r.story + 1) * 200 or s.phase != "day":
		s.message = "未满足条件"
		return false
	var cost: Dictionary = {npc.gift: (r.story + 1)}
	if not afford(s, cost):
		s.message = "材料不足"
		return false
	pay(s, cost)
	r.story += 1
	s.campaign.side_active.erase(id)
	s.campaign.side_last_day[id] = s.day
	s.coins += 25 * r.story
	stat(s, "stories")
	if r.story == 4:
		match id:
			"mori":
				for crop in D.crops:
					if season(s) in crop.seasons:
						if crop.id == "herb":
							s.farm.seeds += 3
							s.Items.ensure_bag(s)
						else: s.campaign.seeds[crop.id] = mini(999999,s.campaign.seeds[crop.id]+3)
			"ember": add(s,"iron",3)
			"nagi": s.equipment.wand = mini(3,s.equipment.wand+1)
			"lumi":
				if s.campaign.stock.moon_table < 99: s.campaign.stock.moon_table += 1
				else: s.coins += 50
			"aster": add(s,"crystal",5)
			"toma":
				add(s,"flour",6)
				add(s,"milk",6)
			"pip": s.campaign.machines.mill = mini(4,s.campaign.machines.mill+1)
			"reed": s.campaign.machines.sprinkler = mini(4,s.campaign.machines.sprinkler+1)
			"yuki": s.campaign.machines.greenhouse = 1
			"orla": s.campaign.reputation += 100
	s.message = "目标达成"
	return true

static func service(s, customer: Dictionary, dish: int) -> int:
	var npc: Dictionary = D.npcs[int(customer.get("npc", customer.get("variant", 0))) % D.npcs.size()]
	var recipe: Dictionary = D.recipes[dish]
	var matches := 0
	for tag in npc.likes:
		if tag in recipe.tags: matches += 1
	var r: Dictionary = s.campaign.residents[npc.id]
	var disliked: bool = npc.dislike in recipe.tags
	r.affinity = clampi(int(r.affinity) + (-5 if disliked else 8 + matches * 4), 0, 1000)
	s.campaign.reputation = mini(LIMIT, s.campaign.reputation + (1 if disliked else 3 + matches))
	stat(s, "serve")
	var banquet_index: int = BANQUET_IDS.find(recipe.id)
	if banquet_index >= 0: s.campaign.stats.banquet = int(s.campaign.stats.banquet) | (1 << banquet_index)
	if dish < 3 and s.campaign.restaurant == 0: return 0
	return roundi(recipe.price * (0.06 * s.campaign.restaurant + (0.1 * matches if not disliked else 0.0)))

static func metric(s, id: String) -> int:
	if id == "repair_stock":
		var progress := 0
		var cost := {"iron": 4, "scrap": 6, "crystal": 4}
		for item in cost: progress += mini(s.campaign.pantry[item], cost[item])
		return progress
	if id == "banquet":
		var mask: int = s.campaign.stats.banquet
		return (1 if mask & 1 else 0) + (1 if mask & 2 else 0) + (1 if mask & 4 else 0)
	if id == "gather": return s.journal.gather
	if id == "serve": return s.journal.serve
	if id == "fish": return s.journal.fish
	if id == "restaurant": return s.campaign.restaurant
	if id == "crop_types": return s.campaign.harvested.size()
	if id == "friend":
		var best := 0
		for r in s.campaign.residents.values(): best = maxi(best, r.affinity)
		return best
	return s.campaign.stats.get(id, 0)

static func complete_chapter(s) -> bool:
	if s.is_arrival_day(): return false
	var chapter: int = s.campaign.chapter
	if chapter >= D.quests.size() or s.campaign.pending_scene >= 0: return false
	var q: Dictionary = D.quests[chapter]
	if metric(s, q.metric) < q.goal:
		s.message = "未满足条件"
		return false
	if not afford(s, q.get("cost", {})): return false
	pay(s, q.get("cost", {}))
	s.campaign.pending_scene = chapter
	s.campaign.chapter += 1
	s.coins += q.reward
	s.message = "目标达成"
	return true

static func import_resources(s) -> bool:
	if s.phase != "day": return false
	var changes := {}
	for id in ["wood", "ore", "iron"]:
		var count: int = s.resources[id]
		if count > 0: changes[id] = -count
	if changes.is_empty(): return false
	if not s.Items.change(s, changes): return false
	for id in changes: add(s, id, -changes[id])
	s.message = "资源入库"
	return true

static func upgrade(s, id: String) -> bool:
	if s.phase != "day": return false
	if id == "smelt":
		if not afford(s, {"ore":2,"wood":1}): return false
		pay(s,{"ore":2,"wood":1})
		add(s,"iron",1)
		s.message = "熔炼"
		return true
	var cost := {}
	var coins := 0
	if id == "restaurant":
		if s.campaign.restaurant >= D.upgrades.size() - 1: return false
		var next: Dictionary = D.upgrades[s.campaign.restaurant + 1]
		cost = {"wood": next.wood, "iron": next.iron}
		coins = next.coins
	elif id in s.campaign.machines:
		if s.campaign.machines[id] >= (1 if id == "greenhouse" else 4): return false
		cost = {"wood": 12, "iron": 2, "scrap": 3} if id != "greenhouse" else {"wood": 40, "iron": 10, "crystal": 5}
		coins = 70 if id != "greenhouse" else 450
	else: return false
	if s.coins < coins or not afford(s, cost):
		s.message = "未满足条件"
		return false
	pay(s, cost)
	s.coins -= coins
	if id == "restaurant": s.campaign.restaurant += 1
	else: s.campaign.machines[id] += 1
	s.message = "升级"
	return true

static func craft(s, id: String) -> bool:
	var item := entry(D.furniture, id)
	if item.is_empty() or s.phase != "day" or s.campaign.stock[id] >= 99: return false
	var cost := {"wood": item.wood, "iron": item.iron}
	if not afford(s, cost):
		s.message = "材料不足"
		return false
	pay(s, cost)
	s.campaign.stock[id] += 1
	s.message = "制作完成"
	return true

static func decorate(s, id: String, room: String, cell: int) -> bool:
	if room not in ["home", "restaurant"] or cell < 0 or cell >= 8 or s.phase != "day": return false
	var same := false
	for item in s.campaign.placed:
		if item.room == room and item.cell == cell and item.id == id: same = true
	if not same and s.campaign.stock.get(id,0) <= 0: return false
	for item in s.campaign.placed:
		if item.room == room and item.cell == cell:
			if s.campaign.stock[item.id] >= 99:
				s.message = "已达上限"
				return false
			s.campaign.stock[item.id] += 1
			s.campaign.placed.erase(item)
			if item.id == id: return true
			break
	if s.campaign.stock.get(id, 0) <= 0: return false
	s.campaign.stock[id] -= 1
	s.campaign.placed.append({"id": id, "room": room, "cell": cell})
	return true

static func comfort(s) -> int:
	var total := 0
	for item in s.campaign.placed:
		if item.room == "restaurant": total += int(entry(D.furniture, item.id).comfort)
	return mini(12, total)

static func festival(s) -> String:
	if (s.day - 1) % 28 + 1 != 21: return ""
	return ["春芽节", "潮灯节", "丰收宴", "长夜灯会"][season(s)]

static func celebrate(s) -> bool:
	if festival(s).is_empty() or s.day in s.campaign.festival_days: return false
	s.campaign.festival_days.append(s.day)
	for r in s.campaign.residents.values(): r.affinity = mini(1000, r.affinity + 35)
	s.campaign.reputation += 30
	s.coins += 40
	s.message = "灯会纪念"
	return true

static func valid_int(value: Variant, high: int = LIMIT) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= high and value == floorf(value)

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	# Infer welcome progress before filling an empty name; keep custom names.
	value = value.duplicate(true)
	if not value.has("guide_met"):
		value.guide_met = value.get("introduced") == true and (not value.has("player_name") or (value.player_name is String and not value.player_name.is_empty()))
	if not value.has("player_name") or (value.player_name is String and value.player_name.is_empty()):
		value.player_name = DEFAULT_PLAYER_NAME
	elif value.player_name == "薇尔莉娅":
		value.player_name = DEFAULT_PLAYER_NAME
	# Old saves keep completed resident episodes and discover later episodes naturally.
	if not value.has("met_residents"):
		value.met_residents = []
		if value.get("residents") is Dictionary:
			for id in value.residents:
				var r: Variant = value.residents[id]
				if r is Dictionary:
					var talked: Variant = r.get("talk_day", 0)
					var completed: Variant = r.get("story", 0)
					if (valid_int(talked, 1000000) and talked > 0) or (valid_int(completed, 4) and completed > 0): value.met_residents.append(id)
	if not value.has("side_active"): value.side_active = {}
	if not value.has("side_last_day"): value.side_last_day = {}
	if value.get("stats") is Dictionary and not value.stats.has("ridge"): value.stats.ridge = 0
	# Different plots have no meaningful chapter mapping. Preserve earned assets
	# and old unlocks while starting the new story at its first chapter.
	if not value.has("story_version"):
		if not valid_int(value.get("chapter"), 12): return {}
		value.story_version = 2
		value.legacy_chapter = int(value.chapter)
		value.chapter = 0
		value.pending_scene = -1
		# A running legacy game keeps its location and time, even when its old
		# welcome flag was absent or false. The replacement opening is for new runs.
		if value.get("introduced") == true: value.guide_met = true
		value.opening_stage = 3 if value.guide_met else 0
	var defaults := initial()
	# Existing games retain their day/service progress; new arrivals opt in at
	# the restaurant introduction, and keep this flag through saves until rest.
	if not value.has("settling_in"): value.settling_in = false
	# Add only expansion ingredient slots. Missing legacy fields and unknown IDs
	# still fail the strict validation below; existing quantities are preserved.
	if value.get("pantry") is Dictionary:
		for id in D.added_ingredients:
			if not value.pantry.has(id): value.pantry[id] = 0
	if value.keys().size() != defaults.keys().size(): return {}
	for key in defaults:
		if not value.has(key): return {}
	if value.version != 1 or not value.introduced is bool or value.selected_crop not in defaults.seeds: return {}
	if not value.guide_met is bool: return {}
	if not value.settling_in is bool: return {}
	if value.story_version != 2 or not valid_int(value.legacy_chapter, 12) or not valid_int(value.opening_stage, 3): return {}
	if value.guide_met != (value.opening_stage == 3): return {}
	if not value.pending_scene is int and not value.pending_scene is float: return {}
	if value.pending_scene != -1 and (not valid_int(value.pending_scene, D.quests.size() - 1) or value.pending_scene != value.chapter - 1): return {}
	if not value.player_name is String: return {}
	if not value.player_name.is_empty() and not valid_player_name(value.player_name): return {}
	if value.region != "field" and entry(D.regions, str(value.region)).is_empty(): return {}
	for key in {"restaurant": 4, "rod": 3, "chapter": D.quests.size(), "reputation": LIMIT}:
		if not valid_int(value[key], {"restaurant": 4, "rod": 3, "chapter": D.quests.size(), "reputation": LIMIT}[key]): return {}
	for key in ["seeds", "pantry", "stats", "stock", "machines"]:
		if not value[key] is Dictionary or value[key].size() != defaults[key].size(): return {}
		for id in defaults[key]:
			if not valid_int(value[key].get(id), 999999 if key == "seeds" else 99 if key == "stock" else 4 if key == "machines" else LIMIT): return {}
	if value.machines.greenhouse > 1: return {}
	if not value.residents is Dictionary or value.residents.size() != D.npcs.size(): return {}
	for npc in D.npcs:
		var r: Variant = value.residents.get(npc.id)
		if not r is Dictionary or r.size() != 4: return {}
		for key in ["affinity", "story", "talk_day", "gift_day"]:
			if not valid_int(r.get(key), 1000 if key == "affinity" else 4 if key == "story" else 1000000): return {}
	if not value.met_residents is Array or value.met_residents.size() > D.npcs.size(): return {}
	var met := []
	for id in value.met_residents:
		if not id is String or id not in defaults.residents or id in met: return {}
		met.append(id)
	if not value.side_active is Dictionary or value.side_active.size() > SIDE_LIMIT: return {}
	for id in value.side_active:
		if id not in met or not valid_int(value.side_active[id], 3): return {}
		if value.side_active[id] != value.residents[id].story or maxi(value.chapter, value.legacy_chapter) < side_chapter(id, value.side_active[id]): return {}
	if not value.side_last_day is Dictionary or value.side_last_day.size() > D.npcs.size(): return {}
	for id in value.side_last_day:
		if id not in met or not valid_int(value.side_last_day[id], 1000000): return {}
	if not value.harvested is Dictionary or value.harvested.size() > D.crops.size(): return {}
	for id in value.harvested:
		if id not in defaults.seeds or value.harvested[id] != true: return {}
	if not value.gathered is Dictionary or value.gathered.size() > 36: return {}
	for id in value.gathered:
		if not id is String or id.split(":").size() != 2: return {}
		var parts: PackedStringArray = id.split(":")
		if entry(D.regions, parts[0]).is_empty() or parts[1] not in ["0","1","2","3","4","5"] or not valid_int(value.gathered[id], 2): return {}
	if not value.placed is Array or value.placed.size() > 16: return {}
	var occupied := []
	for item in value.placed:
		if not item is Dictionary or item.size() != 3 or item.get("id") not in defaults.stock or item.get("room") not in ["home", "restaurant"] or not valid_int(item.get("cell"), 7): return {}
		var key: String = item.room + str(item.cell)
		if key in occupied: return {}
		occupied.append(key)
	if not value.festival_days is Array or value.festival_days.size() > 40000: return {}
	var dates := []
	for day in value.festival_days:
		if not valid_int(day, 1000000) or int(day) % 28 != 21 or day in dates: return {}
		dates.append(day)
	return value.duplicate(true)
