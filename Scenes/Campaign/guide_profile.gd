extends RefCounted
## Yingluo speaks about the town and the current chapter; input belongs in docs.
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const NAME := "萤萝 · 巡灯员"
const PORTRAIT := "res://Art/Characters/NPC32/portraits/yingluo.aseprite"
const SPRITE := "res://Art/Characters/NPC32/guides/yingluo.aseprite"
const Onboarding = preload("res://Scenes/Campaign/onboarding.gd")
const WELCOME = C.D.guide.welcome
const CHAPTERS = C.D.guide.chapters
const FAREWELL = C.D.guide.farewell
const TOPICS = C.D.guide.topics

static func current_lines(s) -> Array:
	var q := C.current_main(s)
	if q.is_empty(): return [FAREWELL]
	var step := Onboarding.current(s)
	var result: Array = [CHAPTERS[s.campaign.chapter], Onboarding.goal_line(s), {"source": "地点：%s", "args": [step.place]}]
	if ready(s): result.append("这一页的心愿已经实现。")
	return result

static func ready(s) -> bool:
	var q := C.current_main(s)
	return not q.is_empty() and C.metric(s, q.metric) >= q.goal
