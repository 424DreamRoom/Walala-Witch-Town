extends RefCounted
## Yingluo speaks about the town and the current chapter; input belongs in docs.
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const NAME := "萤萝 · 巡灯员"
const PORTRAIT := "res://Art/Characters/NPC32/portraits/yingluo.aseprite"
const SPRITE := "res://Art/Characters/NPC32/guides/yingluo.aseprite"
const Onboarding = preload("res://Scenes/Campaign/onboarding.gd")
const WELCOME = C.D.guide.welcome
const CHAPTERS = C.D.guide.chapters
const CURRENT = C.D.guide.current
const FAREWELL = C.D.guide.farewell
const TOPICS = C.D.guide.topics

static func current_lines(s) -> Array:
	var q := C.current_main(s)
	if q.is_empty(): return [FAREWELL]
	# The guide speaks about the chapter's situation. Objective names, counts,
	# and locations remain available in the journal and HUD, rather than in NPC
	# dialogue.
	var result: Array = [CURRENT[s.campaign.chapter]]
	if ready(s): result.append("这件事办成了，真好。")
	return result

static func ready(s) -> bool:
	var q := C.current_main(s)
	return not q.is_empty() and C.metric(s, q.metric) >= q.goal
