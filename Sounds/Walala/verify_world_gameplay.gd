extends SceneTree
## Exercise the actual world/door/cooking hooks with isolated settings and saves.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Campaign = preload("res://Scenes/Campaign/campaign_state.gd")
var checks := 0
var failures := 0
var lane
var loop

func _initialize() -> void:
	Preferences.file_path = "res://output/audio_world/gameplay_%d.cfg" % OS.get_process_id()
	Saves.directory = "res://output/audio_world/gameplay_%d_saves" % OS.get_process_id()
	Saves.end_session()
	Campaign.pending_intro = false
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("WORLD GAMEPLAY ", title, ": PASS" if passed else ": FAIL")

func settle() -> void:
	await create_timer(1.0).timeout

func travel(target: String) -> void:
	loop.travel(target)
	await root.get_node("SceneTransition").finished
	await settle()

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.state.campaign.guide_met = true
	loop.state.campaign.introduced = true
	loop.state.campaign.chapter = 6
	await settle()
	loop.state.phase = "day"
	lane.weather.clear_weather()
	loop.enter("town")
	await settle()
	check("live clear town has birds", loop.audio.soundscape.current_key == "birds")
	var open_before: int = loop.audio.counts.get("door_open", 0)
	await travel("home")
	check("live home music and one door open", loop.location == "home" and loop.audio.current_music == "home" and loop.audio.counts.get("door_open", 0) == open_before + 1)
	var close_before: int = loop.audio.counts.get("door_close", 0)
	await travel("farm")
	check("live house exit closes door", loop.location == "farm" and loop.audio.counts.get("door_close", 0) == close_before + 1)
	var before: Dictionary = loop.audio.counts.duplicate()
	await travel("dock")
	check("live dock switches music and water without door cue", loop.audio.current_music == "dock" and loop.audio.soundscape.current_key == "water" and loop.audio.counts == before)
	await travel("grove")
	check("live campaign region reaches audio context", loop.location == "field" and loop.state.campaign.region == "grove" and loop.audio.current_music == "forest" and loop.audio.soundscape.current_key == "birds")
	await travel("marsh")
	check("live marsh uses water", loop.audio.current_music == "forest" and loop.audio.soundscape.current_key == "water")
	await travel("blacksmith")
	check("live forge has fire", loop.audio.soundscape.current_key == "fire")
	await travel("restaurant")
	loop.state.phase = "night"
	loop.state.remaining = 60.0
	loop.state.cooking = 0
	loop.state.cook_left = 10.0
	await settle()
	check("live kitchen activity starts boiling", loop.audio.soundscape.current_key == "cooking")
	loop.state.cooking = -1
	await settle()
	check("live finished cooking stops boiling", loop.audio.soundscape.current_key.is_empty() and loop.audio.soundscape.voices.all(func(v): return not v.playing))
	lane.queue_free()
	await process_frame
	await process_frame
	check("live scene releases audio sources", root.get_node("WalalaFmod").files.is_empty())
	Saves.end_session()
	print("WORLD GAMEPLAY VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
