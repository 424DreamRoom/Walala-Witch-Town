extends SceneTree
## Real FMOD channels, natural end/loop behavior and scene-owned cache cleanup.
const Voice = preload("res://Sounds/Walala/fmod_voice.gd")
const Library = preload("res://Sounds/Walala/music_library.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	Preferences.file_path = "res://output/fmod_test_%d.cfg" % OS.get_process_id()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("FMOD ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func wait_for(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	check("native server registered", Engine.has_singleton("FmodServer"))
	print("FMOD OUTPUT DRIVERS ", FmodServer.get_available_drivers())
	var runtime = root.get_node("WalalaFmod")
	check("cache initially empty", runtime.files.is_empty())
	var host := Node.new()
	root.add_child(host)
	var a := Voice.new()
	var b := Voice.new()
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(a)
	host.add_child(b)
	a.stream = preload("res://Sounds/Walala/UI/Organic/confirm.ogg")
	b.stream = a.stream
	a.volume_db = -30.0
	b.volume_db = -36.0
	a.pitch_scale = 2.0
	a.play()
	b.play()
	check("real FMOD voices overlap", a.playing and b.playing and a.channel != b.channel)
	check("file shared across voices", runtime.files.size() == 1 and runtime.files[a.stream.resource_path].users == 2)
	check("native gain matches dB", absf(a.channel.get_volume() - db_to_linear(-30.0)) < 0.00001)
	check("native pitch applied", is_equal_approx(a.channel.get_pitch(), 2.0))
	a.volume_db = -40.0
	check("live native gain update", absf(a.channel.get_volume() - db_to_linear(-40.0)) < 0.00001)
	a.stream_paused = true
	await wait_for(a.stream.get_length() / a.pitch_scale + 0.1)
	check("manual pause holds native playback", a.playing)
	a.stream_paused = false
	paused = true
	await wait_for(maxf(a.stream.get_length(), b.stream.get_length()) + 0.2)
	check("one shots finish while world paused", not a.playing and not b.playing)
	paused = false
	a.queue_free()
	await process_frame
	check("one owner keeps shared file", runtime.files.size() == 1 and runtime.files[b.stream.resource_path].users == 1)
	b.queue_free()
	await process_frame
	check("last owner releases file", runtime.files.is_empty())
	var step := Voice.new()
	host.add_child(step)
	step.stream = preload("res://Sounds/Walala/UI/Organic/hover.wav")
	step.volume_db = -40.0
	step.play()
	paused = true
	await wait_for(step.stream.get_length() + 0.15)
	check("world pause holds pausable native voice", step.playing)
	paused = false
	await wait_for(step.stream.get_length() + 0.15)
	check("world resume releases pausable native voice", not step.playing)
	step.queue_free()
	await process_frame
	# Crossing the entire source duration checks FMOD's real loop flag without
	# inventing a playback position (this upstream binding has no position API).
	for key in Library.TRACKS:
		var voice := Voice.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		host.add_child(voice)
		voice.stream = Library.looped(key)
		voice.volume_db = -80.0
		voice.pitch_scale = 8.0
		voice.play()
		check("native music starts " + key, voice.playing and is_equal_approx(voice.channel.get_pitch(), 8.0))
		paused = true
		await wait_for(voice.stream.get_length() / voice.pitch_scale + 0.3)
		check("native music loops during pause " + key, voice.playing)
		paused = false
		voice.queue_free()
		await process_frame
	host.queue_free()
	await process_frame
	check("all native files released", runtime.files.is_empty())
	var menu = load("res://Scenes/MainMenu/menu_audio.gd").new()
	root.add_child(menu)
	await wait_for(0.9)
	check("title native channel starts", menu.music.playing and menu.music.channel is FmodSound)
	menu.set_master_volume(0.5)
	menu.set_music_volume(0.4)
	check("title slider changes native gain", absf(menu.music.channel.get_volume() - db_to_linear(linear_to_db(0.2) - 6.0)) < 0.00001)
	menu.stop()
	check("title handoff stops native channel", not menu.music.playing)
	menu.queue_free()
	await process_frame
	check("title frees native files", runtime.files.is_empty())
	var game = load("res://Sounds/Walala/audio_manager.gd").new()
	root.add_child(game)
	game.set_context("day", "town", "rain")
	await wait_for(0.9)
	check("game music and rain use native channels", game.music[game.active].playing and game.ambient.playing)
	for key in game.streams:
		if key in ["day_town", "night_town3", "rain", "wind", "ui"]: continue
		game.play_event(key)
		check("native action starts " + key, game.effects.any(func(voice): return voice.playing))
		for voice in game.effects: voice.stop()
	for surface in game.footstep_streams:
		game.reset_footsteps()
		game.update_footsteps(2.0, false, surface)
		check("native footstep starts " + surface, game.footstep_voices.any(func(voice): return voice.playing))
	for key in game.ui_audio.SOUNDS:
		game.ui_audio.stop()
		game.play_event(key)
		check("native UI starts " + key, game.ui_audio.voices.any(func(voice): return voice.playing))
	game.set_context("night", "town", "snow")
	await wait_for(0.9)
	check("game night and wind use native channels", game.music[game.active].playing and game.ambient.playing)
	game.queue_free()
	await process_frame
	check("game releases every native file", runtime.files.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("FMOD VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
