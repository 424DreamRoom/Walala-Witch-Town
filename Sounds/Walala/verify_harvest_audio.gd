extends SceneTree

const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Library = preload("res://Sounds/Walala/harvest_audio.gd")
var failures := 0
var checks := 0
var audio
var lane
var loop

func _initialize() -> void:
	Preferences.file_path = "res://output/harvest_audio/test_%d.cfg" % OS.get_process_id()
	if "--audio-only" not in OS.get_cmdline_user_args():
		var saves = load("res://Scenes/Save/save_store.gd")
		saves.directory = "res://output/harvest_audio/test_%d_saves" % OS.get_process_id()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("HARVEST AUDIO ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func stop_effects() -> void:
	for player in audio.effects: player.stop()

func count_event(key: String) -> int:
	return audio.counts.get(key, 0)

func resource(id: String):
	for node in loop.area.resource_nodes:
		if node.resource_id == id: return node
	return null

func run() -> void:
	audio = load("res://Sounds/Walala/audio_manager.gd").new()
	root.add_child(audio)
	print("DRIVER ", AudioServer.get_driver_name())
	var metrics := {}
	for key in Library.SOUNDS:
		for i in range(Library.SOUNDS[key].size()):
			var stream: AudioStreamOggVorbis = Library.SOUNDS[key][i]
			check("short one-shot %s %d" % [key, i], stream.get_length() > 0.1 and stream.get_length() < 1.1 and not stream.loop)
			# Fresh decoder avoids streams parsed before the audio mixer initializes.
			var decoder := AudioStreamOggVorbis.load_from_file(stream.resource_path)
			var playback := decoder.instantiate_playback()
			playback.start()
			var decode_rate: float = AudioServer.get_mix_rate()
			if decode_rate <= 0: decode_rate = 44100.0
			var frames := ceili(stream.get_length() * decode_rate)
			var decoded := 0
			var peak := 0.0
			var energy := 0.0
			while decoded < frames:
				var pcm := playback.mix_audio(1.0, mini(4096, frames - decoded))
				if pcm.is_empty(): break
				for frame in pcm:
					peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
					energy += frame.length_squared() / 2.0
				decoded += pcm.size()
			playback.stop()
			print("DECODE ", key, " ", i, " frames=", decoded, "/", frames, " energy=", energy, " peak=", peak)
			var full_volume_peak: float = peak * db_to_linear(Library.gain_db(key, i))
			# Godot's resampler drains a few filter frames at the end of a one-shot.
			check("full PCM and headroom %s %d" % [key, i], decoded >= frames - 16 and energy > 0.001 and full_volume_peak < 1.0)
			metrics["%s_%02d" % [key, i + 1]] = {"seconds": stream.get_length(), "peak": peak, "rms_db": linear_to_db(sqrt(energy / maxf(decoded, 1))), "default_output_rms_db": linear_to_db(sqrt(energy / maxf(decoded, 1)) * audio.DEFAULT_EFFECTS) + Library.gain_db(key, i)}
		var previous: AudioStream = null
		var variation_ok := true
		for repeat in range(12):
			stop_effects()
			audio.play_event(key)
			var voice = audio.effects[0]
			variation_ok = variation_ok and voice.playing and Library.SOUNDS[key].has(voice.stream)
			if Library.SOUNDS[key].size() > 1: variation_ok = variation_ok and voice.stream != previous
			variation_ok = variation_ok and voice.pitch_scale >= 0.97 and voice.pitch_scale <= 1.03
			previous = voice.stream
		check("variants and bounded pitch " + key, variation_ok)
		check("single event count " + key, count_event(key) == 12)
		var selected_gain: float = Library.gain_db(key, Library.SOUNDS[key].find(audio.effects[0].stream))
		check("event gain " + key, absf(audio.effects[0].volume_db - (linear_to_db(0.35) + selected_gain)) < 0.01)
		if audio.effects[0].has_method("_valid"):
			check("FMOD channel gain and pitch " + key, is_equal_approx(audio.effects[0].channel.get_volume(), db_to_linear(audio.effects[0].volume_db)) and is_equal_approx(audio.effects[0].channel.get_pitch(), audio.effects[0].pitch_scale))
		stop_effects()
		audio.play_event(key)
		audio.apply_volume()
		selected_gain = Library.gain_db(key, Library.SOUNDS[key].find(audio.effects[0].stream))
		check("frame volume preserves gain " + key, absf(audio.effects[0].volume_db - (linear_to_db(0.35) + selected_gain)) < 0.01)
	FileAccess.open("res://output/harvest_audio/metrics_%d.json" % OS.get_process_id(), FileAccess.WRITE).store_string(JSON.stringify(metrics, "\t"))
	stop_effects()
	audio.play_event("mine")
	audio.set_master_volume(0.5)
	audio.set_character_volume(0.6)
	check("live channel gain", absf(audio.effects[0].volume_db - (linear_to_db(0.3) - 8.0)) < 0.01)
	audio.set_character_volume(0.0)
	audio.play_event("chop")
	check("zero character volume", audio.effects.all(func(p): return not p.playing))
	audio.set_character_volume(0.35)
	audio.set_master_volume(0.0)
	audio.play_event("catch")
	check("zero master volume", audio.effects.all(func(p): return not p.playing))
	audio.set_master_volume(1.0)
	audio.effects_muted = true
	audio.apply_volume()
	audio.play_event("bite")
	check("legacy mute", audio.effects.all(func(p): return not p.playing))
	audio.effects_muted = false
	audio.apply_volume()
	check("unmute has no stale replay", audio.effects.all(func(p): return not p.playing))
	for i in range(8): audio.play_event("mine")
	var voices_before: Array = audio.effects.map(func(p): return p.stream)
	audio.play_event("chop")
	check("eight voices bounded without stealing", audio.effects.size() == 8 and audio.effects.all(func(p): return p.playing) and voices_before == audio.effects.map(func(p): return p.stream))
	stop_effects()
	audio.play_event("chop")
	var voice = audio.effects[0]
	paused = true
	var before: float = voice.get_playback_position() if voice.has_method("get_playback_position") else 0.0
	await create_timer(0.12, true).timeout
	check("tail continues while paused", voice.playing and not voice.stream_paused and voice.process_mode == Node.PROCESS_MODE_ALWAYS)
	if AudioServer.get_driver_name() != "Dummy" and voice.has_method("get_playback_position"):
		check("WASAPI playback advances during pause", voice.get_playback_position() > before)
	# Allow hardware / FMOD buffering beyond the 0.33-second source duration.
	await create_timer(0.8, true).timeout
	check("one-shot reaches end during pause", not voice.playing)
	paused = false
	stop_effects()
	if "--audio-only" in OS.get_cmdline_user_args():
		audio.queue_free()
		await process_frame
		audio = null
		print("HARVEST AUDIO END failures=", failures, " checks=", checks)
		quit(0 if failures == 0 else 1)
		return
	# Real gameplay entry points, with deterministic animation timing and isolated data.
	audio.queue_free()
	await process_frame
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await process_frame
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	audio = loop.audio
	audio.music_muted = true
	audio.apply_volume()
	loop.enter("field")
	lane.player.position = loop.area.points[0]
	var gathered := count_event("gather")
	loop.interact()
	check("plant success emits once", count_event("gather") == gathered + 1)
	loop.state.nodes[0] = 0
	loop.interact()
	check("depleted plant silent", count_event("gather") == gathered + 1)
	for pair in [["field_tree_7", "chop"], ["field_ore_0", "mine"]]:
		var node = resource(pair[0])
		lane.player.position = node.anchor
		var initial := count_event(pair[1])
		loop.harvest.start(node)
		loop.harvest.advance(loop.state.swing_seconds(node.resource_kind) * 0.49)
		check("before impact silent " + pair[1], count_event(pair[1]) == initial)
		loop.harvest.advance(loop.state.swing_seconds(node.resource_kind) * 0.02)
		loop.harvest.advance(0.01)
		check("one impact one cue " + pair[1], count_event(pair[1]) == initial + 1)
		loop.harvest.cancel()
		loop.state.tools.wand = 0
		loop.harvest.start(node)
		check("missing tool silent " + pair[1], not loop.harvest.busy() and count_event(pair[1]) == initial + 1)
		loop.state.tools.wand = 1
	var pond = resource("field_pond")
	lane.player.position = pond.anchor
	var casts := count_event("cast")
	loop.harvest.start(pond)
	loop.harvest.advance(0.2)
	check("cast arc has no early splash", count_event("cast") == casts)
	loop.harvest.cancel()
	check("cancelled cast silent", count_event("cast") == casts)
	loop.harvest.start(pond)
	loop.harvest.advance(0.45)
	check("bobber landing emits splash once", count_event("cast") == casts + 1 and loop.harvest.action == "wait")
	var bites := count_event("bite")
	loop.harvest.advance(loop.harvest.wait_seconds + 0.01)
	check("bite emits once", count_event("bite") == bites + 1 and loop.harvest.action == "bite")
	var catches := count_event("catch")
	loop.harvest.interact()
	loop.harvest.advance(0.61)
	check("successful catch emits once", count_event("catch") == catches + 1 and loop.state.resources.fish == 1)
	loop.harvest.start(pond)
	loop.harvest.advance(0.45)
	loop.harvest.interact()
	check("early reel gives no catch cue", not loop.harvest.busy() and count_event("catch") == catches + 1)
	loop.harvest.start(pond)
	loop.harvest.advance(0.45)
	loop.harvest.advance(loop.harvest.wait_seconds + 0.01)
	loop.harvest.advance(loop.harvest.BITE_WINDOW + 0.01)
	check("missed bite gives no catch cue", not loop.harvest.busy() and count_event("catch") == catches + 1)
	var idle_counts: Dictionary = audio.counts.duplicate()
	await create_timer(0.15).timeout
	check("idle frames do not replay cues", audio.counts == idle_counts)
	lane.queue_free()
	await process_frame
	loop = null
	lane = null
	audio = null
	await create_timer(0.1).timeout
	print("HARVEST AUDIO END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
