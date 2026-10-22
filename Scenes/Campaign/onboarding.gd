extends RefCounted
## Goals use existing saved progress; optional preparation never gates a chapter.
const C = preload("res://Scenes/Campaign/campaign_state.gd")

static func current(s) -> Dictionary:
	if s.is_arrival_day():
		return {"id": "settle_in", "name": C.D.arrival.name, "objective": C.D.arrival.objective, "goal": 1, "progress": 0, "place": C.D.arrival.place, "description": C.D.arrival.description}
	var quest := C.current_main(s)
	if quest.is_empty(): return {}
	var step: Dictionary = {}
	var progress := 0
	if s.campaign.chapter == 0 and s.journal.serve == 0:
		var stocked_menu := false
		for dish in range(s.menu.size()):
			if s.menu[dish] and s.can_cook(dish):
				stocked_menu = true
				break
		if s.journal.prepare < 3 and s.materials[0] + s.materials[1] + s.materials[2] < 3 and not stocked_menu:
			step = C.D.onboarding.prepare
			progress = s.journal.prepare
		elif s.menu.count(true) == 0:
			step = C.D.onboarding.menu
		elif s.journal.serve == 0:
			step = C.D.onboarding.first_meal
	elif s.campaign.chapter == 1 and s.campaign.stats.harvest == 0:
		var planted := 0
		var watered := 0
		for plot in s.farm.plots.values():
			if plot.growth < 0: continue
			planted += 1
			if plot.watered or plot.growth > 0: watered += 1
		if planted < 5:
			step = C.D.onboarding.plant
			progress = planted
		elif watered < 5:
			step = C.D.onboarding.water
			progress = watered
	if step.is_empty():
		return {"id": quest.id, "name": quest.name, "objective": quest.objective, "goal": quest.goal, "progress": mini(quest.goal, C.metric(s, quest.metric)), "place": quest.place, "description": quest.briefing}
	return {"id": step.id, "name": step.name, "objective": step.objective, "goal": step.goal, "progress": mini(step.goal, progress), "place": step.place, "description": step.description}

static func goal_line(s) -> Dictionary:
	var step := current(s)
	return {} if step.is_empty() else {"source": "当前目标：%s · %d/%d", "args": [step.objective, step.progress, step.goal]}
