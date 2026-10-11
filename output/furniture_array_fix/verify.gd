extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Furniture = preload("res://Scenes/Building/furniture_catalog.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	Preferences.file_path = "res://output/furniture_array_fix/preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = "res://output/furniture_array_fix/saves_%d" % OS.get_process_id()
	Saves.end_session()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("FURNITURE SAVE ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func round_trip(state, slot: int) -> void:
	var expected: Dictionary = state.to_save_data()
	var now := int(Time.get_unix_time_from_system())
	var snapshot := {"state": expected, "world": {"location": "home", "position": [320, 405], "town_position": [408, 364], "facing": 0, "weather": "clear"}, "play_seconds": 0.0, "created_at": now, "saved_at": now, "saved_at_text": "test"}
	var written := Saves.write_slot(slot, snapshot)
	check("write slot " + str(slot), written.ok)
	var loaded := Saves.read_slot(slot)
	check("read slot " + str(slot), loaded.ok and not loaded.get("empty", true))
	if not loaded.ok or loaded.get("empty", true): return
	check("preserve furniture and chest contents " + str(slot), loaded.data.state.furniture == expected.furniture)
	var restored := State.new()
	check("restore loaded state " + str(slot), restored.restore_save_data(loaded.data.state) and restored.furniture == expected.furniture)
	check("overwrite existing slot " + str(slot), Saves.write_slot(slot, snapshot).ok)
	check("verify backup " + str(slot), Saves._read_file(Saves.slot_path(slot) + ".bak", slot).ok)

func run() -> void:
	var state := State.new()
	for data in [state.furniture, Furniture.legacy_data()]:
		var solids: Array[Rect2] = Furniture.fixed_solids(data)
		check("fixed geometry " + str(data.legacy_fixtures), solids.size() == (2 if data.legacy_fixtures else 0))
		check("placement validation " + str(data.legacy_fixtures), Furniture.placement_error(data, "stool", Vector2(384, 352), -1, Vector2(320, 405)).is_empty())
	state.furniture = Furniture.legacy_data()
	check("JSON furniture normalization", Furniture.normalize(JSON.parse_string(JSON.stringify(state.furniture))) == state.furniture)
	var old_state := state.to_save_data()
	old_state.furniture.erase("house_level")
	old_state.furniture.erase("legacy_fixtures")
	check("pre-expansion save migration", State.normalize_save_data(old_state).get("furniture", {}) == state.furniture)
	round_trip(state, 1)
	state = State.new()
	state.furniture.placed = [{"id": 1, "kind": "stool", "x": 384, "y": 352}, {"id": 2, "kind": "chest", "x": 256, "y": 384, "items": {"wood": 7}}]
	state.furniture.next_id = 3
	check("small house normalizes placed furniture", not Furniture.normalize(state.furniture).is_empty())
	state.furniture = Furniture.normalize(state.furniture)
	round_trip(state, 2)
	var invalid: Dictionary = state.to_save_data()
	invalid.furniture.placed[1].x = 384
	invalid.furniture.placed[1].y = 352
	check("overlapping furniture still rejected", State.normalize_save_data(invalid).is_empty())
	for slot in [1, 2]:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(slot) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	print("FURNITURE SAVE VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
