extends "res://Sounds/Walala/audio_settings.gd"
## Bounded FMOD Core voices with independent channel controls.
const Voice = preload("res://Sounds/Walala/fmod_voice.gd")
const BASE = "res://Sounds/Walala/"
const MusicLibrary = preload("res://Sounds/Walala/music_library.gd")
const HarvestAudio = preload("res://Sounds/Walala/harvest_audio.gd")
const WorldAudio = preload("res://Sounds/Walala/world_audio_library.gd")
const InstrumentLibrary = preload("res://Scenes/Instrument/instrument_library.gd")
const I18n = preload("res://Localization/localized_text.gd")
const DialogueAudio = preload("res://Sounds/Walala/dialogue_audio_library.gd")
# Wind's source RMS is about -37 dBFS; the old -24 dB trim buried it under music.
# At default environment volume this yields about -40 dBFS, alongside rain at -43.
const AMBIENT_GAIN_DB = {"rain": -12.0, "wind": 6.0}
var streams = {}
var harvest_rng := RandomNumberGenerator.new()
var last_harvest_variant := {}
var ui_audio
const FOOTSTEP_FILES = {
	"wood": ["wood_01.ogg", "wood_02.ogg", "wood_03.ogg"],
	"stone": ["stone_01.ogg"],
	"grass": ["grass_01.ogg", "grass_02.ogg"],
	"dirt": ["dirt_01.ogg"],
	"snow": ["snow_01.wav", "snow_02.wav", "snow_03.wav", "snow_04.wav", "snow_05.wav", "snow_06.wav"],
}
var footstep_streams = {}
var instrument_streams: Array[AudioStream] = []
var footstep_voices: Array[Voice] = []
var footstep_rng = RandomNumberGenerator.new()
var last_footstep_variant = {}
var footstep_distance = 0.0
var footstep_moving = false
var music: Array[Voice] = []
var effects: Array[Voice] = []
var dialogue_voices: Array[Voice] = []
var dialogue_next := 0
var dialogue_rng := RandomNumberGenerator.new()
var dialogue_next_usec := 0
var last_dialogue_variant := {}
var ambient: Voice
var soundscape
var current_music = ""
var current_ambient = ""
var music_intensity := 0.0
var active = 0
var fade: Tween
var last_music_gain := -1.0
var counts = {}
var panel: Panel
var credits: Panel
var credits_text: RichTextLabel

func _ready() -> void:
	ui_audio = preload("res://Sounds/Walala/ui_audio.gd").new()
	add_child(ui_audio)
	load_audio_preferences()
	for key in MusicLibrary.TRACKS:
		if key == "title": continue
		streams[key] = MusicLibrary.looped(key)
	for key in ["process", "cook", "serve", "coins", "rain", "wind"]:
		var stream = load(BASE + key + ".ogg").duplicate()
		stream.set_meta("fmod_source_path", BASE + key + ".ogg")
		if key in ["rain", "wind"]:
			stream.loop = true
		streams[key] = stream
	streams["ui"] = ui_audio.SOUNDS["ui_click"][0]
	for key in HarvestAudio.SOUNDS:
		streams[key] = HarvestAudio.SOUNDS[key][0]
	for key in WorldAudio.SOUNDS:
		streams[key] = WorldAudio.SOUNDS[key][0]
	instrument_streams = InstrumentLibrary.load_streams()
	harvest_rng.randomize()
	footstep_rng.randomize()
	dialogue_rng.randomize()
	for surface in FOOTSTEP_FILES:
		footstep_streams[surface] = []
		for file in FOOTSTEP_FILES[surface]:
			footstep_streams[surface].append(load(BASE + "Footsteps/" + file))
	for i in range(2):
		var p = Voice.new()
		# Background playback continues while menus pause the world.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		music.append(p)
	for i in range(8):
		var p = Voice.new()
		# Let an already-started sound finish when a menu or backpack pauses gameplay.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		effects.append(p)
	for i in range(3):
		var p = Voice.new()
		# Dialogue blips continue while the dialogue modal pauses the world.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		dialogue_voices.append(p)
	ambient = Voice.new()
	ambient.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ambient)
	soundscape = preload("res://Sounds/Walala/environment_audio.gd").new()
	add_child(soundscape)
	for i in range(2):
		var p = Voice.new()
		add_child(p)
		footstep_voices.append(p)
	apply_volume()

func update_footsteps(distance: float, running: bool, surface: String) -> void:
	# Only displacement from move_and_slide counts; scene jumps never reach here.
	if distance <= 0.01:
		footstep_distance = 0.0
		footstep_moving = false
		return
	var stride = 140.0 / 6.5 if running else 90.0 / 4.5
	if not footstep_moving:
		footstep_moving = true
		_play_footstep(surface, running)
	else:
		footstep_distance += distance
		if footstep_distance >= stride:
			footstep_distance = fmod(footstep_distance, stride)
			_play_footstep(surface, running)

func reset_footsteps() -> void:
	footstep_distance = 0.0
	footstep_moving = false
	for p in footstep_voices:
		p.stop()

func _play_footstep(surface: String, running: bool) -> void:
	if effects_muted or channel_gain(character_volume) <= 0:
		return
	var variants: Array = footstep_streams.get(surface, footstep_streams["grass"])
	var index = footstep_rng.randi_range(0, variants.size() - 1)
	if variants.size() > 1 and index == last_footstep_variant.get(surface, -1):
		index = (index + footstep_rng.randi_range(1, variants.size() - 1)) % variants.size()
	last_footstep_variant[surface] = index
	# Two reusable voices keep step tails without stealing interaction sounds.
	var voice = footstep_voices[0]
	if voice.playing:
		voice = footstep_voices[1]
	voice.stop()
	voice.stream = variants[index]
	voice.pitch_scale = footstep_rng.randf_range(0.96, 1.04) * (1.04 if running else 1.0)
	voice.set_meta("step_gain", -8.0 if running else -10.0)
	voice.volume_db = linear_to_db(channel_gain(character_volume)) + voice.get_meta("step_gain")
	voice.stream_paused = false
	voice.play()
	var key = "footstep_" + surface
	counts[key] = counts.get(key, 0) + 1

func set_context(phase: String, location: String, weather: String, region: String = "field", cooking: bool = false) -> void:
	var target = MusicLibrary.context_key(phase, location, region)
	if target != current_music:
		current_music = target
		if fade and fade.is_running():
			fade.kill()
		var old = music[active]
		active = 1 - active
		var next = music[active]
		next.stop()
		next.stream = streams[target]
		next.volume_db = -60
		next.play()
		fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		fade.tween_property(old, "volume_db", -60.0, 0.8)
		fade.tween_property(next, "volume_db", linear_to_db(maxf(channel_gain(music_volume), 0.0001)) + MusicLibrary.gain_db(target) + music_intensity * 1.5, 0.8)
		fade.chain().tween_callback(old.stop)
	var env = ""
	if location not in ["restaurant", "home", "blacksmith", "store", "furniture_store"] and phase != "result":
		env = "rain" if weather == "rain" else ("wind" if weather == "snow" else "")
	if env != current_ambient:
		current_ambient = env
		ambient.stop()
		if not env.is_empty():
			ambient.stream = streams[env]
			ambient.volume_db = linear_to_db(maxf(channel_gain(environment_volume), 0.0001)) + AMBIENT_GAIN_DB[env]
			ambient.stream_paused = effects_muted or channel_gain(environment_volume) <= 0
			ambient.play()
	soundscape.set_key(WorldAudio.ambience_key(phase, location, weather, region, cooking))
	apply_volume()

func play_transition(source: String, destination: String) -> void:
	if source == destination: return
	if destination in WorldAudio.INDOORS:
		play_event("door_open")
	elif source in WorldAudio.INDOORS:
		play_event("door_close")

func play_event(key: String) -> void:
	if key == "ui" or key.begins_with("ui_"):
		counts[key] = counts.get(key, 0) + 1
		ui_audio.play(key)
		return
	counts[key] = counts.get(key, 0) + 1
	if effects_muted or channel_gain(character_volume) <= 0:
		return
	for p in effects:
		if not p.playing:
			p.stream = streams[key]
			p.pitch_scale = 1.0
			var gain_db: float = HarvestAudio.gain_db(key)
			if HarvestAudio.SOUNDS.has(key):
				var variants: Array = HarvestAudio.SOUNDS[key]
				var index := harvest_rng.randi_range(0, variants.size() - 1)
				if variants.size() > 1 and index == last_harvest_variant.get(key, -1):
					index = (index + harvest_rng.randi_range(1, variants.size() - 1)) % variants.size()
				last_harvest_variant[key] = index
				p.stream = variants[index]
				gain_db = HarvestAudio.gain_db(key, index)
				# A stable bite cue stays recognizable; other gestures vary slightly.
				p.pitch_scale = 1.0 if key == "bite" else harvest_rng.randf_range(0.97, 1.03)
			elif WorldAudio.SOUNDS.has(key):
				var variants: Array = WorldAudio.SOUNDS[key]
				var index := harvest_rng.randi_range(0, variants.size() - 1)
				if variants.size() > 1 and index == last_harvest_variant.get(key, -1):
					index = (index + 1) % variants.size()
				last_harvest_variant[key] = index
				p.stream = variants[index]
				gain_db = -10.0
			p.set_meta("event_gain_db", gain_db)
			p.volume_db = linear_to_db(channel_gain(character_volume)) + gain_db
			p.stream_paused = false
			p.play()
			return

func play_instrument_note(index: int) -> void:
	if index < 0 or index >= instrument_streams.size():
		return
	counts["instrument_note"] = counts.get("instrument_note", 0) + 1
	counts["instrument_note_%02d" % index] = counts.get("instrument_note_%02d" % index, 0) + 1
	if effects_muted or channel_gain(character_volume) <= 0:
		return
	var stream: AudioStream = instrument_streams[index]
	if stream == null:
		return
	for p in effects:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0
			p.set_meta("event_gain_db", -4.0)
			p.volume_db = linear_to_db(channel_gain(character_volume)) - 4.0
			p.stream_paused = false
			p.play()
			return

func stop_dialogue_voice() -> void:
	for voice in dialogue_voices: voice.stop()
	dialogue_next_usec = 0

func play_dialogue_voice(pitch_scale: float = 1.0, speaker_id: String = "") -> void:
	if effects_muted or channel_gain(character_volume) <= 0 or dialogue_voices.is_empty():
		return
	var now := Time.get_ticks_usec()
	if now < dialogue_next_usec: return
	dialogue_next_usec = now + DialogueAudio.MIN_INTERVAL_USEC
	var profile := DialogueAudio.profile(speaker_id)
	var actor: String = profile[0]
	var pool: Array = DialogueAudio.POOLS[actor]
	var variant := dialogue_rng.randi_range(0, pool.size() - 1)
	if variant == last_dialogue_variant.get(actor, -1):
		variant = (variant + 1) % pool.size()
	last_dialogue_variant[actor] = variant
	var voice: Voice = dialogue_voices[dialogue_next]
	dialogue_next = (dialogue_next + 1) % dialogue_voices.size()
	voice.stop()
	voice.stream = pool[variant]
	voice.set_meta("dialogue_gain_db", DialogueAudio.GAIN_DB)
	voice.volume_db = linear_to_db(channel_gain(character_volume)) + voice.get_meta("dialogue_gain_db")
	voice.pitch_scale = clampf(pitch_scale * float(profile[1]) + dialogue_rng.randf_range(-0.018, 0.018), 0.82, 1.22)
	voice.stream_paused = false
	voice.play()
	counts["dialogue_voice"] = counts.get("dialogue_voice", 0) + 1

func apply_volume() -> void:
	ui_audio.set_volume(channel_gain(ui_volume), effects_muted)
	if not is_equal_approx(last_music_gain, channel_gain(music_volume)):
		_update_music_gain()
	for p in music:
		p.stream_paused = music_muted or channel_gain(music_volume) <= 0
	ambient.volume_db = linear_to_db(maxf(channel_gain(environment_volume), 0.0001)) + AMBIENT_GAIN_DB.get(current_ambient, -12.0)
	ambient.stream_paused = effects_muted or channel_gain(environment_volume) <= 0
	soundscape.set_volume(channel_gain(environment_volume), effects_muted)
	for p in effects:
		p.volume_db = linear_to_db(maxf(channel_gain(character_volume), 0.0001)) + p.get_meta("event_gain_db", -6.0)
		if effects_muted or channel_gain(character_volume) <= 0: p.stop()
	for p in dialogue_voices:
		p.volume_db = linear_to_db(maxf(channel_gain(character_volume), 0.0001)) + p.get_meta("dialogue_gain_db", -14.0)
		if effects_muted or channel_gain(character_volume) <= 0: p.stop()
	for p in footstep_voices:
		p.volume_db = linear_to_db(maxf(channel_gain(character_volume), 0.0001)) + p.get_meta("step_gain", -10.0)
		# Do not resume a stale footstep after unmuting.
		if effects_muted or channel_gain(character_volume) <= 0:
			p.stop()

func set_music_intensity(value: float) -> void:
	music_intensity = clampf(value, 0.0, 1.0)
	if music.size() > active and music[active].playing:
		music[active].volume_db = linear_to_db(maxf(channel_gain(music_volume), 0.0001)) + MusicLibrary.gain_db(current_music) + music_intensity * 1.5

func _update_music_gain() -> void:
	if fade and fade.is_running():
		fade.kill()
	music[1-active].stop()
	last_music_gain = channel_gain(music_volume)
	music[active].volume_db = linear_to_db(maxf(last_music_gain, 0.0001)) + MusicLibrary.gain_db(current_music) + music_intensity * 1.5

func build_ui(layer: CanvasLayer, font: Font) -> void:
	var skin = preload("res://Scenes/Gameplay/ui_skin.gd")
	panel = preload("res://Scenes/UI/settings_panel.gd").new()
	panel.audio = self
	panel.close_button_name = "CloseAudioSettings"
	var background = skin.panel_style()
	panel.position = Vector2(40, 24)
	panel.visible = false
	layer.add_child(panel)
	credits = Panel.new()
	credits.add_theme_stylebox_override("panel", background.duplicate())
	credits.position = Vector2(20, 68)
	credits.size = Vector2(600, 236)
	credits.visible = false
	layer.add_child(credits)
	var text = RichTextLabel.new()
	credits_text = text
	text.position = Vector2(12, 12)
	text.size = Vector2(570, 174)
	text.add_theme_font_override("normal_font", font)
	text.add_theme_font_size_override("normal_font_size", 12)
	text.add_theme_color_override("default_color", skin.INK)
	text.text = I18n.credits()
	credits.add_child(text)
	var close = Button.new()
	close.text = "关闭鸣谢"
	close.position = Vector2(240, 194)
	close.size = Vector2(120, 30)
	close.add_theme_font_override("font", font)
	close.add_theme_font_size_override("font_size", 12)
	credits.add_child(close)
	ui_audio.bind_button(close)
	close.pressed.connect(func(): credits.hide(); play_event("ui_close"))
	panel.credits_requested.connect(func(): credits.show(); play_event("ui_open"); close.grab_focus())
	Localization.language_changed.connect(func(_locale: String): credits_text.text = I18n.credits())

func stop() -> void:
	if fade: fade.kill()
	for player in music + effects + dialogue_voices + footstep_voices:
		player.stop()
	if is_instance_valid(ambient): ambient.stop()
	if is_instance_valid(soundscape): soundscape.stop()
	if is_instance_valid(ui_audio): ui_audio.stop()

func _exit_tree() -> void:
	stop()
