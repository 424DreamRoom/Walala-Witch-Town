extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
var failures = 0
var lane
var loop
var audio
var preferences_path := Preferences.file_path
var saves_directory := Saves.directory

func _initialize() -> void:
	Preferences.file_path = "res://output/weather_footsteps_%d.cfg" % OS.get_process_id()
	Saves.directory = "res://output/weather_footsteps_%d_saves" % OS.get_process_id()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("WEATHER FOOTSTEPS ", title, ": ", "PASS" if passed else "FAIL")
	if not passed:
		failures += 1

func wait_for(seconds: float) -> void:
	await create_timer(seconds).timeout

func steps(surface: String) -> int:
	return audio.counts.get("footstep_" + surface, 0)

func all_steps() -> int:
	var count := 0
	for cue in audio.counts:
		if cue.begins_with("footstep_"): count += audio.counts[cue]
	return count

func any_step_playing() -> bool:
	return audio.footstep_voices.any(func(p): return p.playing)

func source_levels(stream: AudioStream) -> Dictionary:
	# Measure decoded audio, so a playing but inaudible source cannot pass.
	var playback = stream.instantiate_playback()
	playback.start()
	var remaining := roundi(minf(stream.get_length(), 12.0) * AudioServer.get_mix_rate())
	var samples := 0
	var energy := 0.0
	var peak := 0.0
	while remaining > 0:
		var frames := mini(remaining, 8192)
		for sample in playback.mix_audio(1.0, frames):
			energy += sample.length_squared()
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			samples += 2
		remaining -= frames
	playback.stop()
	playback = null
	return {"rms_db": linear_to_db(sqrt(energy / samples)), "peak_db": linear_to_db(peak)}

func walk_at(position: Vector2, direction: Vector2, running: bool, seconds: float) -> void:
	lane.test_direction = Vector2.ZERO
	lane.player.position = position
	audio.reset_footsteps()
	await physics_frame
	lane.test_running = running
	lane.test_direction = direction
	await wait_for(seconds)
	lane.test_direction = Vector2.ZERO
	await physics_frame
	await physics_frame

func run() -> void:
	# Slider tests leave the user's saved preferences untouched.
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	# New games begin at home; outdoor checks must explicitly enter town.
	loop.enter("town")
	audio = loop.audio
	audio.set_effects_muted(false)
	audio.set_effects_volume(0.35)
	await wait_for(0.15)
	print("AUDIO DRIVER ", AudioServer.get_driver_name())
	for surface in audio.footstep_streams:
		for i in range(audio.footstep_streams[surface].size()):
			var stream: AudioStream = audio.footstep_streams[surface][i]
			check("loaded " + surface + str(i), stream != null and stream.get_length() > 0)
			if stream == null:
				continue
			var playback = stream.instantiate_playback()
			playback.start()
			var energy = 0.0
			for frame in playback.mix_audio(1.0, 8192):
				energy += frame.length_squared()
			check("nonzero PCM " + surface + str(i), energy > 0.0001)
			playback.stop()
			playback = null
	var surfaces = loop.footstep_surfaces
	for spec in [
		["town", Vector2(408, 364), "clear", "stone"],
		["town", Vector2(108, 450), "clear", "dirt"],
		["town", Vector2(224, 307), "clear", "dirt"],
		["field", Vector2(60, 280), "clear", "dirt"],
		["field", Vector2(140, 150), "clear", "grass"],
		["town", Vector2(408, 364), "snow", "snow"],
		["home", Vector2(320, 405), "snow", "wood"],
		["restaurant", Vector2(60, 280), "snow", "wood"],
		["blacksmith", Vector2(300, 300), "snow", "stone"],
		["blacksmith", Vector2(450, 390), "snow", "wood"],
		["store", Vector2(300, 300), "snow", "wood"],
		["dock", Vector2(400, 230), "clear", "wood"],
		["dock", Vector2(64, 276), "clear", "dirt"],
		["dock", Vector2(400, 230), "snow", "snow"],
	]:
		check("surface " + str(spec), surfaces.resolve(spec[0], spec[1], spec[2]) == spec[3])
	var before = steps("stone")
	# Follow the current diagonal stone road for both speeds.
	await walk_at(Vector2(408, 364), Vector2(60, 46).normalized(), false, 0.65)
	var walking_steps = steps("stone") - before
	check("real walking starts steps", walking_steps >= 2 and walking_steps <= 4)
	var after_walk = audio.counts.duplicate()
	await wait_for(0.45)
	check("idle adds no steps", after_walk == audio.counts and not any_step_playing())
	before = steps("stone")
	await walk_at(Vector2(408, 364), Vector2(60, 46).normalized(), true, 0.65)
	check("running cadence faster", steps("stone") - before > walking_steps)
	# The west road at y=364 is now a scene exit; use the closed boundary above it.
	await walk_at(Vector2(6, 280), Vector2.LEFT, false, 0.5)
	lane.test_direction = Vector2.LEFT
	# Let move_and_slide settle its collision margin before measuring a blocked push.
	await wait_for(0.15)
	audio.reset_footsteps()
	before = all_steps()
	await wait_for(0.5)
	check("pushing wall stays silent", all_steps() == before)
	lane.test_direction = Vector2.ZERO
	lane.player.position = Vector2(408, 364)
	await wait_for(0.1)
	check("teleport adds no steps", all_steps() == before)
	lane.weather.set_weather("rain")
	await wait_for(0.1)
	check("rain loop starts", audio.current_ambient == "rain" and audio.ambient.playing and audio.ambient.stream.loop)
	var rain_rms_db: float = source_levels(audio.ambient.stream).rms_db + audio.ambient.volume_db
	var channel = audio.ambient.channel
	await wait_for(0.2)
	check("rain loop not restarted each frame", audio.ambient.channel == channel and channel.is_valid())
	lane.weather.set_weather("snow")
	await wait_for(0.1)
	check("snow uses wind loop", audio.current_ambient == "wind" and audio.ambient.playing and audio.ambient.stream.loop and not audio.ambient.stream_paused)
	var wind_levels := source_levels(audio.ambient.stream)
	var snow_rms_db: float = wind_levels.rms_db + audio.ambient.volume_db
	var music_rms_db: float = source_levels(audio.streams["day_town"]).rms_db + linear_to_db(audio.channel_gain(audio.music_volume)) - 6.0
	print("WEATHER LEVELS rain_rms_db=", rain_rms_db, " snow_rms_db=", snow_rms_db, " music_rms_db=", music_rms_db)
	check("default snow has audible decoded level", snow_rms_db > -45.0 and snow_rms_db < -32.0)
	check("snow remains present beside default music", snow_rms_db >= music_rms_db - 12.0)
	check("snow and rain levels stay balanced", absf(snow_rms_db - rain_rms_db) < 6.0)
	await wait_for(0.1)
	channel = audio.ambient.channel
	await wait_for(0.2)
	check("snow loop not restarted each frame", audio.ambient.channel == channel and channel.is_valid())
	audio.ambient.pitch_scale = 8.0
	await wait_for(audio.ambient.stream.get_length() / 8.0 + 0.3)
	check("FMOD snow loop wraps at end", audio.ambient.playing)
	audio.ambient.pitch_scale = 1.0
	audio.set_environment_volume(1.0)
	check("maximum snow volume retains headroom", wind_levels.peak_db + audio.ambient.volume_db < -1.0)
	audio.set_environment_volume(0.0)
	check("snow environment zero pauses weather only", audio.ambient.stream_paused and not audio.music[audio.active].stream_paused)
	audio.set_environment_volume(0.35)
	check("snow environment restore resumes loop", not audio.ambient.stream_paused and audio.ambient.playing)
	audio.set_master_volume(0.0)
	check("master zero silences snow", audio.ambient.stream_paused)
	audio.set_master_volume(1.0)
	audio.set_effects_muted(true)
	check("effects mute silences snow", audio.ambient.stream_paused)
	audio.set_effects_muted(false)
	check("effects unmute resumes snow", not audio.ambient.stream_paused and audio.ambient.playing)
	before = steps("snow")
	await walk_at(Vector2(408, 360), Vector2.RIGHT, false, 0.4)
	check("snow steps selected while moving", steps("snow") > before)
	loop.enter("home")
	check("enter interior immediately stops weather and steps", not audio.ambient.playing and not any_step_playing())
	before = steps("wood")
	await walk_at(lane.player.position, Vector2.LEFT, false, 0.3)
	check("interior selects wood during snow", steps("wood") > before and not audio.ambient.playing)
	for interior in ["restaurant", "blacksmith", "store"]:
		loop.enter(interior)
		check("snow silent inside " + interior, not audio.ambient.playing)
	for outdoor in ["town", "farm", "field", "dock"]:
		loop.enter(outdoor)
		check("snow resumes outside " + outdoor, audio.current_ambient == "wind" and audio.ambient.playing and not audio.ambient.stream_paused)
	var previous_variant = audio.last_footstep_variant.get("wood", -1)
	var no_repeats = true
	for i in range(8):
		audio.reset_footsteps()
		audio.update_footsteps(1.5, false, "wood")
		var variant = audio.last_footstep_variant["wood"]
		no_repeats = no_repeats and variant != previous_variant
		previous_variant = variant
	check("wood variants do not repeat consecutively", no_repeats)
	audio.play_event("ui")
	check("footsteps preserve interaction voice", audio.ui_audio.voices.any(func(p): return p.playing and p.stream == audio.streams["ui"]))
	audio.set_effects_muted(true)
	check("mute stops current footsteps", not any_step_playing())
	audio.update_footsteps(25.0, true, "wood")
	check("muted walking starts no voice", not any_step_playing())
	audio.set_effects_muted(false)
	check("unmute does not replay old footsteps", not any_step_playing())
	audio.set_effects_volume(0)
	audio.reset_footsteps()
	audio.update_footsteps(1.5, false, "wood")
	check("zero volume starts no voice", not any_step_playing())
	audio.set_effects_volume(0.35)
	audio.reset_footsteps()
	audio.update_footsteps(1.5, false, "wood")
	audio.set_effects_volume(0.2)
	check("slider updates footstep gain", absf(audio.footstep_voices[0].volume_db - (linear_to_db(0.2) - 10.0)) < 0.01)
	loop.enter("town")
	lane.weather.clear_weather()
	await wait_for(0.1)
	check("clear stops weather", not audio.ambient.playing)
	lane.weather.set_weather("snow")
	await wait_for(0.1)
	audio.update_footsteps(1.5, false, "stone")
	loop.state.phase = "result"
	await wait_for(0.1)
	check("result stops movement and step voices", not lane.is_physics_processing() and not any_step_playing())
	check("result stops snow ambience", not audio.ambient.playing)
	check("bounded footstep and event voices", audio.footstep_voices.size() == 2 and audio.effects.size() == 8)
	lane.queue_free()
	await wait_for(0.1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	Preferences.file_path = preferences_path
	Saves.directory = saves_directory
	print("WEATHER FOOTSTEPS VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
