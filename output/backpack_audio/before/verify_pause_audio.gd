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
	loop.hud.open_bag()
	await background_advances("backpack")
	check("backpack remains paused", paused and loop.hud.mode == "bag")
	loop.hud.close_modal()
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
