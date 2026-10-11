extends SceneTree
## Actual menu pauses with isolated preferences and saves; WASAPI checks playback.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
var failures := 0
var checks := 0
var lane
var loop

func _initialize() -> void:
	Preferences.file_path = "res://output/pause_audio_%d.cfg" % OS.get_process_id()
	Saves.directory = "res://output/pause_audio_%d_saves" % OS.get_process_id()
	Saves.end_session()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("PAUSE AUDIO ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func wait_for(seconds: float = 0.12) -> void:
	await create_timer(seconds).timeout

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func pointer(control: Control) -> Vector2:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var position := container.position + control.get_global_rect().get_center() * container.scale
	var event := InputEventMouseMotion.new()
	event.position = position
	root.push_input(event, true)
	await process_frame
	return position

func click(control: Control) -> void:
	var position := await pointer(control)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func cue_count(cue: String) -> int:
	return int(loop.audio.ui_audio.counts.get(cue, 0))

func backpack_pause() -> void:
	var opened := cue_count("ui_open")
	loop.audio.play_event("catch")
	var effect: AudioStreamPlayer = loop.audio.effects[0]
	await key(KEY_B)
	check("keyboard opens backpack with sound", paused and loop.hud.mode == "bag" and cue_count("ui_open") == opened + 1)
	check("backpack preserves active action sound", effect.playing and not effect.stream_paused)
	var effect_position := effect.get_playback_position()
	await wait_for(0.05)
	if AudioServer.get_driver_name() != "Dummy":
		check("native action sound advances in backpack", effect.get_playback_position() > effect_position)
	var remaining: float = loop.state.remaining
	var position: Vector2 = lane.player.position
	loop.paused_for_test = false
	lane.test_direction = Vector2.RIGHT
	await background_advances("backpack")
	await wait_for(0.15)
	check("backpack freezes clock and movement", paused and loop.state.remaining == remaining and lane.player.position == position)
	if AudioServer.get_driver_name() != "Dummy":
		check("native action sound finishes during backpack pause", not effect.playing)
	var slots: Array = loop.hud.chest_view.bag_slots
	await wait_for()
	var hovered := cue_count("ui_hover")
	await pointer(slots[1])
	check("backpack slot hover plays sound", cue_count("ui_hover") == hovered + 1)
	await wait_for()
	slots[0].grab_focus()
	hovered = cue_count("ui_hover")
	await key(KEY_D)
	check("backpack keyboard focus plays sound", cue_count("ui_hover") == hovered + 1)
	await wait_for()
	var clicked := cue_count("ui_click")
	var wand_index := 0
	for index in range(loop.state.bag_slots.size()):
		if loop.state.bag_slots[index].get("id") == "wand": wand_index = index
	await click(slots[wand_index])
	check("backpack pickup plays one sound", loop.hud.chest_view.session.hand.get("id") == "wand" and cue_count("ui_click") == clicked + 1)
	var voice: AudioStreamPlayer = null
	for candidate in loop.audio.ui_audio.voices:
		if candidate.playing and candidate.stream == loop.audio.ui_audio.SOUNDS.ui_click[0]: voice = candidate
	var cue_position := voice.get_playback_position() if voice != null else -1.0
	await wait_for(0.02)
	if AudioServer.get_driver_name() != "Dummy":
		check("native backpack click advances while paused", voice != null and voice.playing and voice.get_playback_position() > cue_position)
	await wait_for()
	clicked = cue_count("ui_click")
	await click(slots[2 if wand_index != 2 else 0])
	check("backpack placement plays one sound", loop.hud.chest_view.session.hand.is_empty() and cue_count("ui_click") == clicked + 1)
	lane.test_direction = Vector2.ZERO
	loop.paused_for_test = true
	var closed := cue_count("ui_close")
	await key(KEY_B)
	check("keyboard closes backpack with sound", not paused and loop.hud.mode.is_empty() and cue_count("ui_close") == closed + 1)
	await wait_for()
	opened = cue_count("ui_open")
	await click(loop.hud.slot_counts[0].get_parent())
	check("hotbar opens backpack with sound", paused and loop.hud.mode == "bag" and cue_count("ui_open") == opened + 1)
	await background_advances("hotbar backpack")
	await click(loop.hud.chest_view.get_node("CloseChest"))
	check("close button resumes world", not paused and loop.hud.mode.is_empty())

func background_advances(title: String, seconds: float = 0.3) -> void:
	var music: AudioStreamPlayer = loop.audio.music[loop.audio.active]
	var ambient: AudioStreamPlayer = loop.audio.ambient
	var music_position := music.get_playback_position()
	var ambient_position := ambient.get_playback_position()
	await wait_for(seconds)
	check(title + " background channels playing", music.playing and not music.stream_paused and ambient.playing and not ambient.stream_paused)
	if AudioServer.get_driver_name() != "Dummy":
		check(title + " native music advances", fposmod(music.get_playback_position() - music_position, music.stream.get_length()) > 0.05)
		check(title + " native ambience advances", fposmod(ambient.get_playback_position() - ambient_position, ambient.stream.get_length()) > 0.05)

func menu_pause(weather: String) -> void:
	lane.weather.set_weather(weather)
	await wait_for()
	# Start a crossfade just before opening the actual pause menu.
	loop.audio.set_context("night", "town", weather)
	loop.audio.set_context("day", "town", weather)
	await key(KEY_ESCAPE)
	var remaining: float = loop.state.remaining
	var position: Vector2 = lane.player.position
	loop.paused_for_test = false
	lane.test_direction = Vector2.RIGHT
	await background_advances(weather + " menu", 0.95)
	check(weather + " pause freezes clock and movement", paused and loop.save_menu.open and loop.state.remaining == remaining and lane.player.position == position)
	var music: AudioStreamPlayer = loop.audio.music[loop.audio.active]
	check(weather + " pause completes music crossfade", music.playing and not loop.audio.music[1-loop.audio.active].playing and absf(music.volume_db - (linear_to_db(loop.audio.channel_gain(loop.audio.music_volume)) - 6.0)) < 0.1)
	loop.save_menu.show_settings()
	var panel = loop.audio.panel
	var music_volume: float = loop.audio.music_volume
	var environment_volume: float = loop.audio.environment_volume
	panel.music_slider.value = 0.0
	check(weather + " paused music slider mutes independently", music.stream_paused and not loop.audio.ambient.stream_paused)
	panel.music_slider.value = music_volume
	panel.environment_slider.value = 0.0
	check(weather + " paused ambience slider mutes independently", loop.audio.ambient.stream_paused and not music.stream_paused)
	panel.environment_slider.value = environment_volume
	panel.master_slider.value = 0.0
	check(weather + " paused master slider mutes background", music.stream_paused and loop.audio.ambient.stream_paused)
	panel.master_slider.value = 1.0
	await wait_for()
	await background_advances(weather + " settings")
	check(weather + " settings remain paused", paused and panel.visible and loop.state.remaining == remaining and lane.player.position == position)
	lane.test_direction = Vector2.ZERO
	loop.paused_for_test = true
	await key(KEY_ESCAPE)
	check(weather + " settings return to paused menu", paused and loop.save_menu.open and not panel.visible)
	await key(KEY_ESCAPE)
	await background_advances(weather + " resumed")
	check(weather + " resume keeps current music voice", not paused and not loop.save_menu.open and loop.audio.music[loop.audio.active] == music)

func run() -> void:
	print("PAUSE AUDIO DRIVER ", AudioServer.get_driver_name())
	# A fixed legacy-room fixture keeps audio checks independent of expansion art.
	var state = preload("res://Scenes/Gameplay/loop_state.gd").new()
	state.furniture = preload("res://Scenes/Building/furniture_catalog.gd").legacy_data()
	state.furniture.placed.clear()
	Saves.pending = {"state": state.to_save_data(), "world": {"location": "town", "position": [408, 364], "town_position": [408, 364], "facing": 0, "weather": "clear"}}
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("town")
	for weather in ["rain", "snow"]:
		await menu_pause(weather)
	await backpack_pause()
	loop.campaign_controller.open()
	await background_advances("journal")
	check("journal remains paused", paused and loop.hud.mode == "campaign")
	loop.hud.close_modal()
	loop.enter("home")
	await key(KEY_ESCAPE)
	await wait_for()
	check("indoor pause keeps ambience silent", paused and not loop.audio.ambient.playing and loop.audio.music[loop.audio.active].playing and not loop.audio.music[loop.audio.active].stream_paused)
	await key(KEY_ESCAPE)
	lane.queue_free()
	await process_frame
	await wait_for(0.2)
	Saves.end_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("PAUSE AUDIO VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
