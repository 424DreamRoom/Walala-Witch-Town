extends SceneTree

const Director = preload("res://Scenes/Gameplay/seasonal_director.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
var failures := 0

func check(title: String, passed: bool) -> void:
	print("SEASONAL TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func _initialize() -> void:
	var first := Director.pulse_for_day(1)
	var repeat := Director.pulse_for_day(1)
	check("deterministic daily pulse", first == repeat)
	check("pulse contains forecast and focus", first.has("weather") and first.has("focus"))
	var state := State.new()
	state.phase = "day"
	state.wand_mode = "blue"
	var plot := {"watered": true, "fertilized": true}
	check("quality bonus rewards full care", state.crop_quality_bonus(plot) >= 1)
	state.menu[0] = true
	state.start_service()
	check("service counters reset at opening", state.service_chain == 0 and state.tips == 0)
	state.end_phase()
	check("tips remain bounded", state.tips >= 0 and state.service_peak >= 0)
	print("SEASONAL VERIFY END failures=", failures)
	quit(1 if failures > 0 else 0)
