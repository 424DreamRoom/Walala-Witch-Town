extends RefCounted
const QUESTS := [
	{"id": "gather", "title": "森林里的第一篮", "goal": 3, "place": "野外采集区", "description": "餐厅的香气，从[color=#247f78]新鲜食材[/color]开始。", "objective": "采集食材"},
	{"id": "prepare", "title": "让厨房准备就绪", "goal": 3, "place": "小镇餐厅 · 备料台", "description": "新鲜的[color=#247f78]厨房原料[/color]，是今晚料理的起点。", "objective": "加工食材"},
	{"id": "serve", "title": "第一位客人的晚餐", "goal": 1, "place": "小镇餐厅 · 夜间营业", "description": "一份热腾腾的[color=#247f78]晚餐[/color]，一段温暖的小镇时光。", "objective": "成功上菜"},
	{"id": "fish", "title": "来自潮汐的礼物", "goal": 1, "place": "潮汐码头 · 白天", "description": "海风轻拂，码头的[color=#247f78]鱼群[/color]在水下穿行。", "objective": "钓到一条鱼"}
]

static func count(state, quest: Dictionary) -> int:
	return mini(int(state.journal.get(quest.id, 0)), quest.goal)

static func complete(state, quest: Dictionary) -> bool:
	return count(state, quest) >= quest.goal

static func tracked(state) -> Dictionary:
	for quest in QUESTS:
		if quest.id == state.journal.tracked and not complete(state, quest):
			return quest
	for quest in QUESTS:
		if not complete(state, quest):
			return quest
	return {}
