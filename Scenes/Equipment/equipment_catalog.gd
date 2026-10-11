extends RefCounted
## Saved ranks are separate from tool ownership and use stable IDs.
const IDS := ["wand", "bag"]
const TITLES := {"wand": "法杖", "bag": "背包"}
const TIERS := ["基础", "强化", "精制", "大师"]
const DEFAULT_LEVELS := {"wand": 0, "bag": 0}
const LEGACY_LEVELS := {"axe": 0, "pickaxe": 0, "hoe": 0, "watering_can": 0, "bag": 0}
const MAX_LEVEL := 3
const TOOL_COSTS := [{"coins": 20, "wood": 2, "iron": 1}, {"coins": 60, "wood": 4, "iron": 3}, {"coins": 120, "wood": 6, "iron": 6}]
const BAG_COSTS := [{"coins": 30, "wood": 3, "iron": 1}, {"coins": 80, "wood": 6, "iron": 2}, {"coins": 160, "wood": 10, "iron": 4}]
const BAG_CAPACITIES := [12, 18, 24, 36]
const WATER_CAPACITIES := [24, 36, 48, 72]
const SWING_SECONDS := [0.68, 0.56, 0.44, 0.34]
const STRIKE_POWER := [1, 2, 3, 3]
const HOE_AREAS := [Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3), Vector2i(5, 3)]
const FISH_COUNTS := [3, 4, 5, 6]
const BITE_WINDOWS := [1.5, 1.9, 2.3, 2.7]

static func resource_yield(kind: String, rank: int) -> int:
	return (3 if kind == "wood" else 2) + rank

static func fishing_wait_range(rank: int) -> Vector2:
	return Vector2(2.0, 4.0) / (1.0 + rank * 0.2)

static func wand_values(rank: int) -> Array:
	var area: Vector2i = HOE_AREAS[rank]
	var wait := fishing_wait_range(rank)
	# Each group supplies one attribute row, including multi-value ranges.
	return [[STRIKE_POWER[rank]], [SWING_SECONDS[rank]], [resource_yield("wood", rank)], [resource_yield("ore", rank)], [WATER_CAPACITIES[rank]], [area.x, area.y], [FISH_COUNTS[rank]], [BITE_WINDOWS[rank]], [wait.x, wait.y]]

static func cost(id: String, rank: int) -> Dictionary:
	if id not in IDS or rank < 0 or rank >= MAX_LEVEL: return {}
	return (BAG_COSTS if id == "bag" else TOOL_COSTS)[rank].duplicate()

static func normalize(value: Variant, legacy: bool = false) -> Dictionary:
	var ids: Array = LEGACY_LEVELS.keys() if legacy else IDS
	if not value is Dictionary or value.size() != ids.size(): return {}
	var result := {}
	for id in ids:
		var rank: Variant = value.get(id)
		if not (rank is int or rank is float) or not is_finite(float(rank)) or rank < 0 or rank > MAX_LEVEL or float(rank) != floorf(float(rank)): return {}
		result[id] = int(rank)
	return result

static func effect(id: String, rank: int, preview: bool = true) -> String:
	var next := mini(MAX_LEVEL, rank + 1) if preview else rank
	if id == "wand":
		var current := wand_values(rank)
		var upgraded := wand_values(next)
		var arguments: Array = []
		for index in range(current.size()):
			arguments.append_array(current[index])
			if preview: arguments.append_array(upgraded[index])
		if not preview:
			return TranslationServer.translate("采集力度 %d\n采集施法 %.2f秒\n每树木材 %d\n每矿矿石 %d\n储水量 %d\n翻地范围 %d×%d\n每日钓点鱼数 %d\n咬钩窗口 %.1f秒\n咬钩等待 %.2f–%.2f秒") % arguments
		return TranslationServer.translate("采集力度 %d → %d\n采集施法 %.2f秒 → %.2f秒\n每树木材 %d → %d\n每矿矿石 %d → %d\n储水量 %d → %d\n翻地范围 %d×%d → %d×%d\n每日钓点鱼数 %d → %d\n咬钩窗口 %.1f秒 → %.1f秒\n咬钩等待 %.2f–%.2f秒 → %.2f–%.2f秒") % arguments
	if not preview: return TranslationServer.translate("背包格数 %d") % BAG_CAPACITIES[rank]
	return TranslationServer.translate("背包格数 %d → %d") % [BAG_CAPACITIES[rank], BAG_CAPACITIES[next]]
