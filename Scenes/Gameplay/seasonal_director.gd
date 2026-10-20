extends RefCounted
## Deterministic daily modifiers that connect weather, farming and the evening table.
## The director is pure data so a save can be replayed consistently on every platform.

const WEATHER := ["clear", "rain", "snow"]
const WEATHER_NAMES := {"clear": "晴朗", "rain": "小雨", "snow": "薄雪"}
const FOCUS_NAMES := ["汤品", "甜点", "丰收"]
const FOCUS_TAGS := ["warm", "sweet", "harvest"]

static func season_for_day(day: int) -> int:
	return maxi(0, ((day - 1) / 28) % 4)

static func pulse_for_day(day: int) -> Dictionary:
	var safe_day := maxi(1, day)
	var season := season_for_day(safe_day)
	# A stable cycle keeps the forecast readable and makes long saves deterministic.
	var weather_id: String = WEATHER[(safe_day * 7 + season * 3) % WEATHER.size()]
	var focus_index: int = (safe_day + season) % FOCUS_NAMES.size()
	var soil_bonus := 1 if weather_id == "rain" else 0
	var mood := 1 if weather_id == "clear" else 0
	if season == 3 and weather_id == "snow": mood = -1
	return {
		"season": season,
		"weather": weather_id,
		"weather_name": WEATHER_NAMES[weather_id],
		"focus": FOCUS_TAGS[focus_index],
		"focus_name": FOCUS_NAMES[focus_index],
		"soil_bonus": soil_bonus,
		"mood": mood,
		"note": "今日气象：%s · 料理偏好：%s" % [WEATHER_NAMES[weather_id], FOCUS_NAMES[focus_index]],
	}

static func crop_quality(plot: Dictionary, pulse: Dictionary) -> int:
	var score := 0
	if bool(plot.get("watered", false)): score += 1
	if bool(plot.get("fertilized", false)): score += 1
	score += int(pulse.get("soil_bonus", 0))
	return clampi(score, 0, 3)

static func dish_focus_bonus(recipe: Dictionary, pulse: Dictionary) -> int:
	var focus: String = str(pulse.get("focus", ""))
	if focus.is_empty(): return 0
	if focus in recipe.get("tags", []): return 1
	return 0

static func focus_text(pulse: Dictionary) -> String:
	return str(pulse.get("focus_name", ""))
