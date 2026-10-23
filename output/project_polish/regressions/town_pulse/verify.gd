extends SceneTree

const Pulse = preload("res://Scenes/Gameplay/town_pulse.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")

var failures := 0

func check(title: String, passed: bool) -> void:
	print("TOWN PULSE TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func _initialize() -> void:
	var first := Pulse.for_day(1)
	check("deterministic request", first == Pulse.for_day(1))
	check("request rotation", Pulse.for_day(1).id != Pulse.for_day(2).id)
	var state := State.new()
	state.town_contract = first
	state.register_town_event("gather", 2)
	check("partial progress", state.town_contract_progress == 2 and not state.town_contract_rewarded)
	state.register_town_event("gather")
	check("completion rewards once", state.town_contract_rewarded and state.coins == first.reward)
	state.register_town_event("gather", 4)
	check("completion is capped", state.town_contract_progress == first.goal and state.coins == first.reward)
	var round_trip := State.new()
	check("save carries request", round_trip.restore_save_data(state.to_save_data()) and round_trip.town_contract == state.town_contract)
	print("TOWN PULSE VERIFY END failures=", failures)
	quit(1 if failures > 0 else 0)
