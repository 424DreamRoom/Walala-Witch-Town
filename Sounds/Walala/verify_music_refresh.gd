extends SceneTree
const Voice = preload("res://Sounds/Walala/fmod_voice.gd")
const Library = preload("res://Sounds/Walala/music_library.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const MenuAudio = preload("res://Scenes/MainMenu/menu_audio.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("MUSIC REFRESH ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func wait_for(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	Preferences.file_path = "res://output/music_refresh_%d.cfg" % OS.get_process_id()
	print("MUSIC REFRESH DRIVER ", AudioServer.get_driver_name())
	var metrics := {}
	for key in Library.TRACKS:
		var stream: AudioStreamOggVorbis = Library.TRACKS[key]
		check("valid OGG " + key, stream.get_length() > 20.0)
		var playback := stream.instantiate_playback()
		playback.start()
		var peak := 0.0
		var energy := 0.0
		var samples := 0
		# Decode the whole source, including any lead-in, rather than its header alone.
		var blocks := ceili(stream.get_length() * 44100.0 / 8192.0)
		for block in range(blocks):
			for sample in playback.mix_audio(1.0, 8192):
				energy += sample.length_squared()
				peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
				samples += 2
		playback.stop()
		check("nonzero full PCM " + key, energy > 0.01 and peak > 0.01)
		metrics[key] = {"seconds": stream.get_length(), "peak": peak, "rms_db": linear_to_db(sqrt(energy / samples))}
		var voice := Voice.new()
		root.add_child(voice)
		voice.stream = Library.looped(key)
		voice.volume_db = -60.0
		voice.pitch_scale = 8.0
		voice.play()
		await wait_for(voice.stream.get_length() / voice.pitch_scale + 0.3)
		check("FMOD loops beyond source duration " + key, voice.playing and is_equal_approx(voice.channel.get_pitch(), 8.0))
		voice.stop()
		voice.queue_free()
	var report := FileAccess.open("res://output/music_refresh_metrics.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "\t"))
	report.close()
	print("MUSIC REFRESH METRICS ", JSON.stringify(metrics))
	var menu := MenuAudio.new()
	root.add_child(menu)
	await wait_for(0.9)
	check("title uses separate looping track", menu.music.stream is AudioStreamOggVorbis and menu.music.stream.loop and is_equal_approx(menu.music.stream.get_length(), Library.TRACKS.title.get_length()))
	check("title playing with saved gain", menu.music.playing and absf(menu.music.volume_db - (linear_to_db(0.22) - 6.0)) < 0.1)
	menu.set_music_muted(true)
	check("title mute", menu.music.stream_paused)
	menu.set_music_muted(false)
	menu.stop()
	check("title stops before gameplay", not menu.music.playing)
	menu.queue_free()
	await process_frame
	# Load after autoloads have initialized, as the actual scene does.
	var game = load("res://Sounds/Walala/audio_manager.gd").new()
	root.add_child(game)
	game.set_context("day", "town", "clear")
	await wait_for(0.9)
	check("day uses new OGG", game.music[game.active].stream is AudioStreamOggVorbis and is_equal_approx(game.music[game.active].stream.get_length(), Library.TRACKS.day_town.get_length()))
	var active: int = game.active
	var channel = game.music[active].channel
	game.set_context("day", "field", "clear")
	await wait_for(0.15)
	check("location keeps current music voice", game.active == active)
	check("location preserves native channel", game.music[active].channel == channel and channel.is_valid())
	game.set_context("night", "restaurant", "rain")
	check("day and night overlap during fade", game.music.all(func(v): return v.playing))
	await wait_for(0.9)
	check("night transition completes", game.current_music == "night_town3" and game.music[game.active].playing and not game.music[1-game.active].playing)
	check("night uses new OGG", is_equal_approx(game.music[game.active].stream.get_length(), Library.TRACKS.night_town3.get_length()))
	game.set_context("result", "restaurant", "rain")
	check("result retains night music", game.current_music == "night_town3" and not game.ambient.playing)
	game.set_music_volume(0.4)
	game.set_music_muted(true)
	game.set_context("day", "town", "rain")
	await wait_for(0.9)
	check("muted phase change stays silent", game.music[game.active].stream_paused)
	check("outdoor rain preserved", game.current_ambient == "rain" and game.ambient.playing)
	game.set_music_muted(false)
	check("gain survives phase change", not game.music[game.active].stream_paused and absf(game.music[game.active].volume_db - (linear_to_db(0.4) - 6.0)) < 0.1)
	game.set_effects_muted(true)
	check("effects mute independent from music", game.ambient.stream_paused and not game.music[game.active].stream_paused)
	game.set_music_volume(0.0)
	check("zero music volume silent", game.music[game.active].stream_paused)
	game.set_music_volume(0.22)
	game.set_context("night", "town", "snow")
	await wait_for(0.1)
	game.set_context("day", "home", "rain")
	await wait_for(0.9)
	check("rapid switching leaves one music voice", game.music[game.active].playing and not game.music[1-game.active].playing)
	check("indoor environment silent", not game.ambient.playing)
	game.queue_free()
	await process_frame
	var restored := MenuAudio.new()
	root.add_child(restored)
	check("settings persist to title", is_equal_approx(restored.music_volume, 0.22) and restored.effects_muted)
	restored.queue_free()
	await process_frame
	await wait_for(0.15)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("MUSIC REFRESH VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
