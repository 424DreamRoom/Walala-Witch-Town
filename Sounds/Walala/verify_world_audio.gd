extends SceneTree
## Original PCM, native FMOD looping, scene fades, controls and bounded door cues.
const Library = preload("res://Sounds/Walala/world_audio_library.gd")
const Music = preload("res://Sounds/Walala/music_library.gd")
const Voice = preload("res://Sounds/Walala/fmod_voice.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
var checks := 0
var failures := 0
var audio

func _initialize() -> void:
	Preferences.file_path = "res://output/audio_world/preferences_%d.cfg" % OS.get_process_id()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("WORLD AUDIO ", title, ": PASS" if passed else ": FAIL")

func wait_for(seconds: float = 0.9) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	check("native FMOD available", Engine.has_singleton("FmodServer"))
	var assets: Array = JSON.parse_string(FileAccess.get_file_as_string("res://Sounds/Walala/World/manifest.json")).assets
	var native: Array[Voice] = []
	var longest := 0.0
	for asset in assets:
		var path: String = "res://Sounds/Walala/World/" + asset.file
		var stream := AudioStreamOggVorbis.load_from_file(path)
		stream.set_meta("fmod_source_path", path)
		check("duration " + asset.file, absf(stream.get_length() - asset.duration_seconds) < 0.02)
		var decoder := stream.instantiate_playback()
		decoder.start()
		var rate := float(AudioServer.get_mix_rate())
		var frames := ceili(stream.get_length() * rate)
		var decoded := 0
		var energy := 0.0
		var peak := 0.0
		while decoded < frames:
			var pcm := decoder.mix_audio(1.0, mini(8192, frames - decoded))
			if pcm.is_empty(): break
			for frame in pcm:
				energy += frame.length_squared() / 2.0
				peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
			decoded += pcm.size()
		decoder.stop()
		check("complete nonzero PCM " + asset.file, decoded >= frames - 16 and energy > 0.001)
		check("maximum gain retains headroom " + asset.file, peak * db_to_linear(asset.gain_db) < 0.9)
		if asset.category == "character": continue
		stream.loop = true
		var voice := Voice.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(voice)
		voice.stream = stream
		voice.pitch_scale = 16.0
		voice.volume_db = -90.0
		voice.play()
		native.append(voice)
		longest = maxf(longest, stream.get_length() / 16.0)
	paused = true
	await wait_for(longest + 0.4)
	for voice in native:
		check("native loop crosses source end while paused " + String(voice.stream.get_meta("fmod_source_path")).get_file(), voice.playing)
		voice.queue_free()
	paused = false
	await process_frame
	check("loop check releases every source", root.get_node("WalalaFmod").files.is_empty())
	audio = load("res://Sounds/Walala/audio_manager.gd").new()
	root.add_child(audio)
	audio.set_context("day", "town", "clear")
	await wait_for()
	check("clear town has birds", audio.soundscape.current_key == "birds" and audio.soundscape.voices[audio.soundscape.active].playing)
	var bird_voice = audio.soundscape.voices[audio.soundscape.active]
	var bird_channel = bird_voice.channel
	for frame in range(20):
		audio.set_context("day", "farm", "clear")
		await process_frame
	check("frame updates preserve native scenery channel", bird_voice.channel == bird_channel and bird_channel.is_valid())
	audio.set_context("night", "town", "clear")
	check("birds and insects crossfade", audio.soundscape.voices.all(func(v): return v.playing))
	paused = true
	await wait_for()
	check("scene fade completes while paused", audio.soundscape.current_key == "crickets" and not audio.soundscape.voices[1-audio.soundscape.active].playing)
	audio.set_environment_volume(0.0)
	check("environment zero pauses every loop", audio.soundscape.voices.all(func(v): return v.stream_paused) and audio.ambient.stream_paused and not audio.music[audio.active].stream_paused)
	audio.set_environment_volume(0.35)
	check("environment restore resumes same channel", audio.soundscape.voices[audio.soundscape.active].playing and not audio.soundscape.voices[audio.soundscape.active].stream_paused)
	paused = false
	audio.set_context("day", "town", "rain")
	await wait_for()
	check("rain replaces wildlife", audio.ambient.playing and audio.current_ambient == "rain" and audio.soundscape.voices.all(func(v): return not v.playing))
	audio.set_context("day", "town", "snow")
	await wait_for()
	check("snow replaces wildlife with wind", audio.current_ambient == "wind" and audio.soundscape.current_key.is_empty())
	audio.set_context("day", "dock", "rain")
	await wait_for()
	check("dock music and water with rain", audio.current_music == "dock" and audio.soundscape.current_key == "water" and audio.ambient.playing)
	audio.set_context("day", "home", "rain")
	await wait_for()
	check("home has warm music and no outdoor loops", audio.current_music == "home" and not audio.ambient.playing and audio.soundscape.voices.all(func(v): return not v.playing))
	audio.set_context("day", "field", "clear", "grove")
	await wait_for()
	check("forest music level is calibrated", audio.current_music == "forest" and absf(audio.music[audio.active].volume_db - (linear_to_db(0.22) + 5.0)) < 0.05)
	audio.set_context("day", "field", "clear", "marsh")
	await wait_for()
	check("marsh keeps forest music with water", audio.current_music == "forest" and audio.soundscape.current_key == "water")
	audio.set_context("day", "blacksmith", "rain")
	await wait_for()
	check("forge fire replaces outdoors", audio.soundscape.current_key == "fire" and not audio.ambient.playing)
	audio.set_context("night", "restaurant", "clear", "field", true)
	await wait_for()
	check("active kitchen bubbles", audio.soundscape.current_key == "cooking")
	audio.set_context("night", "restaurant", "clear")
	await wait_for()
	check("finished kitchen releases bubbling source", audio.soundscape.voices.all(func(v): return not v.playing))
	audio.set_context("day", "town", "clear")
	audio.set_context("day", "dock", "rain")
	audio.set_context("day", "blacksmith", "rain")
	audio.set_environment_volume(0.5)
	await wait_for()
	check("rapid scenery changes leave one voice", audio.soundscape.voices.filter(func(v): return v.playing).size() == 1 and audio.soundscape.current_key == "fire")
	var fire = audio.soundscape.voices[audio.soundscape.active]
	check("gain adjustment survives scenery fade", absf(fire.volume_db - (linear_to_db(0.5) + 7.0)) < 0.05 and absf(fire.channel.get_volume() - db_to_linear(fire.volume_db)) < 0.0001)
	audio.set_master_volume(0.0)
	check("master mute silences native scenery", fire.stream_paused and audio.music[audio.active].stream_paused)
	audio.set_master_volume(1.0)
	audio.set_effects_muted(true)
	check("legacy effect mute includes scenery", fire.stream_paused and not audio.music[audio.active].stream_paused)
	audio.set_effects_muted(false)
	for key in Library.SOUNDS:
		var previous: AudioStream
		var correct := true
		for repeat in range(8):
			for voice in audio.effects: voice.stop()
			audio.play_event(key)
			var voice = audio.effects[0]
			correct = correct and voice.playing and Library.SOUNDS[key].has(voice.stream) and voice.stream != previous
			previous = voice.stream
		check("bounded nonrepeating door cue " + key, correct)
	for voice in audio.effects: voice.stop()
	audio.set_character_volume(0.0)
	audio.play_transition("town", "home")
	check("door follows character mute", audio.effects.all(func(v): return not v.playing) and not fire.stream_paused)
	audio.set_character_volume(0.35)
	audio.play_transition("town", "home")
	check("enter building opens wooden door", audio.effects.any(func(v): return v.playing))
	await wait_for(1.6)
	check("door ends naturally", audio.effects.all(func(v): return not v.playing))
	var before: Dictionary = audio.counts.duplicate()
	audio.play_transition("town", "farm")
	audio.play_transition("town", "town")
	check("outdoor and unchanged travel have no door cue", before == audio.counts)
	audio.set_context("result", "restaurant", "clear", "field", true)
	await wait_for()
	check("settlement keeps music and stops scenery", audio.current_music == "night_town3" and audio.soundscape.voices.all(func(v): return not v.playing))
	audio.stop()
	check("explicit stop includes new voices", audio.soundscape.voices.all(func(v): return not v.playing))
	audio.queue_free()
	await process_frame
	check("scene exit releases all native files", root.get_node("WalalaFmod").files.is_empty())
	print("WORLD AUDIO VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
