extends SceneTree
const Library = preload("res://Sounds/Walala/dialogue_audio_library.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Campaign = preload("res://Scenes/Campaign/campaign_state.gd")
const Guide = preload("res://Scenes/Campaign/guide_profile.gd")
const OUT := "res://output/dialogue_audio_20261022/"
var failures := 0
var checks := 0
var lane
var loop
var audio
var hud

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	Campaign.pending_intro = false
	var state := State.new()
	state.campaign.introduced = true
	state.campaign.guide_met = true
	state.campaign.opening_stage = 3
	state.campaign.settling_in = false
	state.restaurant_leased = true
	state.day = 2
	Saves.pending = {"state": state.to_save_data(), "world": {"location": "town", "position": [408,364], "town_position": [408,364], "weather": "clear", "facing": 0}}
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("DIALOGUE ", title, ": ", "PASS" if passed else "FAIL")

func count() -> int:
	return int(audio.counts.get("dialogue_voice", 0))

func silent() -> bool:
	return audio.dialogue_voices.all(func(v): return not v.playing)

func latest():
	return audio.dialogue_voices[(audio.dialogue_next + audio.dialogue_voices.size() - 1) % audio.dialogue_voices.size()]

func wait_for_cadence() -> void:
	# Match the audio throttle's monotonic clock, independent of frame delta.
	var deadline := Time.get_ticks_usec() + 140000
	while Time.get_ticks_usec() < deadline: await process_frame

func open_lines(value: Array) -> void:
	if not hud.mode.is_empty(): hud.close_modal()
	hud.start_dialogue(Guide.NAME, Guide.PORTRAIT, value, [], Rect2())
	hud.set_process(false)

func run() -> void:
	Preferences.set_value("game", "dialogue_speed", 30.0)
	for actor in Library.POOLS:
		for stream in Library.POOLS[actor]:
			check("one-shot " + stream.resource_path.get_file(), stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and absf(stream.get_length() - 0.125) < 0.001)
			var playback = stream.instantiate_playback()
			playback.start()
			var energy := 0.0
			for sample in playback.mix_audio(1.0, 5512): energy += sample.length_squared()
			playback.stop()
			check("audible PCM " + stream.resource_path.get_file(), energy > 1.0)
	for id in Library.PROFILES:
		check("stable profile " + id, Library.profile(id) == Library.profile("res://Art/Characters/NPC32/portraits/" + id + ".aseprite") and Library.POOLS.has(Library.profile(id)[0]))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	for i in range(8): await process_frame
	loop = lane.get_node("GameLoop")
	lane.automation = true
	loop.paused_for_test = true
	loop.campaign_controller.set_process(false)
	audio = loop.audio
	hud = loop.hud
	audio.set_master_volume(1.0)
	audio.set_character_volume(0.5)
	audio.set_ui_volume(0.0)
	audio.set_environment_volume(0.0)
	audio.set_music_volume(0.0)
	for actor in Library.POOLS:
		for stream in Library.POOLS[actor]:
			var voice = audio.dialogue_voices[0]
			voice.stream = stream
			voice.volume_db = -20.0
			voice.stream_paused = false
			voice.play()
			check("FMOD source " + stream.resource_path.get_file(), voice.playing and voice.channel != null)
			voice.stop()
	open_lines(["小镇的灯火很温柔。", "今晚的风也很轻。"])
	var before := count()
	hud._process(0.04)
	check("typewriter starts real FMOD while modal pauses world", paused and count() == before + 1 and latest().playing and latest().channel != null)
	check("dialogue independent of UI environment music", latest().volume_db > -30.0 and latest().can_process())
	check("guide uses Karen voice", latest().stream in Library.POOLS.karen)
	var first_stream: AudioStream = latest().stream
	for i in range(100): audio.play_dialogue_voice(1.0, Guide.PORTRAIT)
	check("same-frame flood bounded", count() == before + 1 and audio.dialogue_voices.size() == 3)
	await wait_for_cadence()
	hud._process(0.1)
	check("natural next syllable without immediate repetition", count() == before + 2 and latest().stream != first_stream)
	hud.advance_dialogue()
	check("skip completes text and stops sound", silent() and hud.dialogue_text.visible_characters == hud.dialogue_text.get_total_character_count())
	before = count()
	hud._process(1.0)
	check("skip never replays missed syllables", count() == before)
	hud.advance_dialogue()
	hud._process(0.04)
	check("next line resumes with clean voice", count() == before + 1)
	hud.toggle_history()
	var visible_chars: int = hud.dialogue_text.visible_characters
	before = count()
	hud._process(1.0)
	check("history quiet and reveal paused", silent() and count() == before and hud.dialogue_text.visible_characters == visible_chars)
	hud.toggle_history()
	await wait_for_cadence()
	hud._process(0.1)
	check("history close resumes typewriter", count() == before + 1)
	hud.close_modal()
	check("dialogue close stops all syllables", silent())
	open_lines(["，。！？；：、 …—-~"])
	before = count()
	hud._process(1.0)
	check("punctuation and whitespace silent", count() == before)
	Preferences.set_value("game", "dialogue_speed", 0.0)
	open_lines(["小镇的灯火很温柔。"])
	before = count()
	hud._process(0.1)
	check("instant text silent without burst", count() == before and hud.dialogue_text.visible_characters == hud.dialogue_text.get_total_character_count())
	Preferences.set_value("game", "dialogue_speed", 60.0)
	open_lines(["小镇的灯火很温柔。"])
	before = count()
	hud._process(5.0)
	check("slow frame emits at most one syllable", count() == before + 1)
	hud.close_modal()
	audio.play_dialogue_voice(1.0, "ember")
	check("resident uses Sean voice", latest().stream in Library.POOLS.sean)
	audio.set_character_volume(0.0)
	check("character zero stops current voice", silent())
	before = count()
	audio.play_dialogue_voice(1.0, "ember")
	check("character zero blocks new voice", count() == before)
	audio.set_character_volume(0.5)
	audio.stop_dialogue_voice()
	audio.play_dialogue_voice(1.0, "walala-witch")
	check("player uses Meghan voice", latest().stream in Library.POOLS.meghan)
	audio.set_master_volume(0.0)
	check("master zero immediately silent", silent())
	audio.set_master_volume(1.0)
	audio.stop_dialogue_voice()
	audio.play_dialogue_voice()
	audio.set_effects_muted(true)
	check("legacy effects mute stops dialogue", silent())
	before = count()
	audio.play_dialogue_voice()
	check("muted playback rejected", count() == before)
	audio.set_effects_muted(false)
	Preferences.set_value("game", "dialogue_speed", 30.0)
	open_lines([{"source": "小镇的灯火很温柔。", "args": [], "speaker": "主角", "translate_speaker": false, "portrait": "res://Art/Character/Storybook/WalalaWitchAseprite32/walala-witch.aseprite"}])
	var identity: String = hud.dialogue_voice_id
	var localization = root.get_node("Localization")
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		localization.set_language(locale)
		check("voice identity survives language " + locale, hud.dialogue_voice_id == identity and silent())
	hud.close_modal()
	localization.set_language("zh_CN")
	check("credit contains author and license", "Super Dialogue Audio Pack — Dillon Becker" in preload("res://Localization/localized_text.gd").credits() and "https://creativecommons.org/licenses/by/4.0/" in preload("res://Localization/localized_text.gd").credits())
	audio.stop()
	lane.queue_free()
	paused = false
	await process_frame
	Saves.end_session()
	print("DIALOGUE VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
