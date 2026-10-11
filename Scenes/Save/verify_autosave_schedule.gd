extends SceneTree
## Real loop and disk checks; preferences and saves are isolated per process.
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Campaign = preload("res://Scenes/Campaign/campaign_state.gd")
var failures := 0
var lane
var loop

func _initialize() -> void:
	Saves.directory = "res://output/restaurant_service/autosave_%d/saves" % OS.get_process_id()
	Preferences.file_path = "res://output/restaurant_service/autosave_%d/preferences.cfg" % OS.get_process_id()
	Saves.end_session()
	Campaign.pending_intro = false
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("SCHEDULE TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func load_game() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	loop = lane.get_node("GameLoop")
	loop.set_process(false)
	loop.paused_for_test = false
	lane.automation = true
	await frames()

func clock(minutes: float) -> void:
	loop.state.phase = "day" if minutes < 1080 else "night" if minutes < 1320 else "result"
	loop.state.remaining = State.DAY_SECONDS * (1080 - minutes) / 720.0 if minutes < 1080 else State.NIGHT_SECONDS * (1320 - minutes) / 240.0 if minutes < 1320 else 0.0
	loop.last_phase = loop.state.phase

func saved_coins() -> int:
	return int(Saves.read_slot(1).data.state.coins)

func run() -> void:
	check("isolated new slot opens", Saves.begin_slot(1).ok)
	Saves.pending.state.campaign.introduced = true
	Saves.pending.state.campaign.player_name = "Test"
	await load_game()
	check("new game schedules noon", loop.next_autosave_at == 720.0)
	loop.state.coins = 10
	check("manual save remains immediate", loop.save_progress().ok and saved_coins() == 10)
	loop.state.coins = 11
	loop._process(30.0)
	check("thirty real seconds do not save", saved_coins() == 10)
	for location in ["home", "farm", "town", "field", "dock", "blacksmith", "store", "restaurant"]:
		loop.enter(location)
	check("map changes do not save early", saved_coins() == 10)
	loop.state.resources.wood = 8
	loop._autosave()
	check("gameplay requests wait for six-hour boundary", Saves.read_slot(1).data.state.resources.wood == 0)
	clock(719.9)
	loop._process(0.02)
	check("clock just before noon does not save", saved_coins() == 10)
	loop._process(0.1)
	check("crossing noon saves progress", saved_coins() == 11 and loop.next_autosave_at == 1080.0)
	check("scheduled save uses animated hat", loop.save_menu.indicator.visible and loop.save_menu.indicator.phase == "saving")
	loop.state.coins = 12
	loop._process(0.1)
	check("same boundary only writes once", saved_coins() == 11)
	clock(800.0)
	loop.save_menu.manual_save()
	check("manual save between boundaries preserves evening deadline", saved_coins() == 12 and loop.next_autosave_at == 1080.0)
	clock(1080.0)
	loop.state.coins = 13
	paused = true
	loop._autosave()
	check("paused gameplay defers automatic writes", saved_coins() == 12 and loop.next_autosave_at == 1080.0)
	paused = false
	loop.harvest.action = "cast"
	loop._autosave()
	check("unfinished harvesting defers boundary save", saved_coins() == 12)
	loop.harvest.cancel()
	loop._autosave()
	check("pending evening save runs after action finishes", saved_coins() == 13 and loop.next_autosave_at == 1320.0)
	loop.state.coins = 14
	loop.end_phase()
	loop._autosave()
	check("22:00 settlement saves once", saved_coins() == 14 and Saves.read_slot(1).data.state.phase == "result" and loop.next_autosave_at == 1440.0)
	loop.state.coins = 15
	loop._process(60.0)
	check("settlement waiting does not save again", saved_coins() == 14)
	loop.end_phase()
	loop._autosave()
	check("next day six o'clock saves and advances", saved_coins() == 15 and Saves.read_slot(1).data.state.day == 2 and loop.next_autosave_at == 2160.0)
	clock(719.0)
	loop.state.coins = 20
	check("near-boundary save fixture succeeds", loop.save_progress().ok)
	lane.queue_free()
	await frames(5)
	check("saved game reopens", Saves.begin_slot(1).ok)
	await load_game()
	check("loading keeps next clock boundary", loop.state.day == 2 and is_equal_approx(loop.state.get_time_minutes(), 719.0) and loop.next_autosave_at == 2160.0)
	clock(720.0)
	loop.state.coins = -1
	loop._autosave()
	check("failed automatic save keeps boundary pending", loop.autosave_retry_left == loop.AUTOSAVE_RETRY_SECONDS and loop.next_autosave_at == 2160.0)
	loop.state.coins = 21
	loop._process(29.9)
	check("failed save retry is throttled", saved_coins() == 20)
	loop._process(0.2)
	check("retry saves pending progress", saved_coins() == 21 and loop.next_autosave_at == 2520.0 and loop.autosave_retry_left == 0.0)
	clock(1080.0)
	loop.state.coins = -1
	loop._autosave()
	paused = true
	loop.state.coins = 22
	loop.save_menu.manual_save()
	check("manual save bypasses pause and retry delay", saved_coins() == 22 and loop.autosave_retry_left == 0.0)
	loop.state.coins = 23
	loop.save_menu.return_to_title()
	check("exit writes unscheduled changes immediately", saved_coins() == 23 and loop.save_menu.leaving)
	await create_timer(1.7).timeout
	await frames(5)
	check("exit reaches title normally", current_scene.scene_file_path == "res://Scenes/MainMenu/main_menu.tscn" and not paused)
	current_scene.queue_free()
	await frames(5)
	loop = null
	lane = null
	for suffix in ["", ".bak", ".tmp"]:
		var file_path: String = Saves.slot_path(1) + suffix
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	if FileAccess.file_exists(Preferences.file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("AUTOSAVE SCHEDULE VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
