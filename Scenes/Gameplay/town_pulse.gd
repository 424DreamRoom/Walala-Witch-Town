extends RefCounted
## Deterministic daily community requests. The request is deliberately small:
## it nudges the player toward a different part of the town each day without
## introducing a second quest log or changing the main story pace.

const REQUESTS := [
	{"id": "gather", "name": "林间来货", "description": "采集林间食材", "goal": 3, "reward": 15, "reputation": 2},
	{"id": "harvest", "name": "新芽入仓", "description": "收获农场作物", "goal": 2, "reward": 20, "reputation": 3},
	{"id": "serve", "name": "灯下待客", "description": "让客人吃得满意", "goal": 2, "reward": 24, "reputation": 4},
	{"id": "fish", "name": "潮声带回", "description": "带回一条鲜鱼", "goal": 1, "reward": 18, "reputation": 3},
]

static func for_day(day: int) -> Dictionary:
	var index := posmod(maxi(1, day) - 1, REQUESTS.size())
	return REQUESTS[index].duplicate(true)

static func progress_text(request: Dictionary, progress: int) -> String:
	return "%s %d/%d" % [str(request.get("name", "")), mini(progress, int(request.get("goal", 1))), int(request.get("goal", 1))]

static func finished(request: Dictionary, progress: int) -> bool:
	return progress >= int(request.get("goal", 1))
