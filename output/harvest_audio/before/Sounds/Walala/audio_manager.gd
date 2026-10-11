extends "res://Sounds/Walala/audio_settings.gd"
## Independent, bounded audio voices; no global buses or project settings altered.
const BASE = "res://Sounds/Walala/"
const MusicLibrary = preload("res://Sounds/Walala/music_library.gd")
const I18n = preload("res://Localization/localized_text.gd")
# Wind's source RMS is about -37 dBFS; the old -24 dB trim buried it under music.
# At default environment volume this yields about -40 dBFS, alongside rain at -43.
const AMBIENT_GAIN_DB = {"rain": -12.0, "wind": 6.0}
var streams = {}
var ui_audio
const FOOTSTEP_FILES = {
	"wood": ["wood_01.ogg", "wood_02.ogg", "wood_03.ogg"],
	"stone": ["stone_01.ogg"],
	"grass": ["grass_01.ogg", "grass_02.ogg"],
	"dirt": ["dirt_01.ogg"],
	"snow": ["snow_01.wav", "snow_02.wav", "snow_03.wav", "snow_04.wav", "snow_05.wav", "snow_06.wav"],
}
var footstep_streams = {}
var footstep_voices: Array[AudioStreamPlayer] = []
var footstep_rng = RandomNumberGenerator.new()
var last_footstep_variant = {}
var footstep_distance = 0.0
var footstep_moving = false
var music: Array[AudioStreamPlayer] = []
var effects: Array[AudioStreamPlayer] = []
var ambient: AudioStreamPlayer
var current_music = ""
var current_ambient = ""
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
	for key in ["day_town", "night_town3"]:
		streams[key] = MusicLibrary.looped(key)
	for key in ["gather", "process", "cook", "serve", "coins", "rain", "wind"]:
		var stream = load(BASE + key + ".ogg").duplicate()
		if key in ["rain", "wind"]:
			stream.loop = true
		streams[key] = stream
	streams["ui"] = ui_audio.SOUNDS["ui_click"][0]
	for key in ["chop", "mine", "cast", "bite", "catch"]:
		streams[key] = load(BASE + key + ".wav")
	footstep_rng.randomize()
	for surface in FOOTSTEP_FILES:
		footstep_streams[surface] = []
		for file in FOOTSTEP_FILES[surface]:
			footstep_streams[surface].append(load(BASE + "Footsteps/" + file))
	for i in range(2):
		var p = AudioStreamPlayer.new()
		# Background playback continues while menus pause the world.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		music.append(p)
	for i in range(8):
		var p = AudioStreamPlayer.new()
		# Let an already-started sound finish when a menu or backpack pauses gameplay.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		effects.append(p)
	ambient = AudioStreamPlayer.new()
	ambient.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ambient)
	for i in range(2):
		var p = AudioStreamPlayer.new()
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

func set_context(phase: String, location: String, weather: String) -> void:
	var target = "day_town" if phase == "day" else "night_town3"
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
		fade.tween_property(next, "volume_db", linear_to_db(maxf(channel_gain(music_volume), 0.0001)) - 6.0, 0.8)
		fade.chain().tween_callback(old.stop)
	var env = ""
	if location not in ["restaurant", "home", "blacksmith", "store", "furniture_store"] and phase != "result":
		env = "rain" if weather == "rain" else ("wind" if weather == "snow" else "")
	if env != current_ambient:
		current_ambient = env
		ambient.stop()
		if not env.is_empty():
			ambient.stream = streams[env]
			ambient.play()
	apply_volume()

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
			p.volume_db = linear_to_db(channel_gain(character_volume)) - 6.0
			p.stream_paused = false
			p.play()
			return

func apply_volume() -> void:
	ui_audio.set_volume(channel_gain(ui_volume), effects_muted)
	if not is_equal_approx(last_music_gain, channel_gain(music_volume)):
		_update_music_gain()
	for p in music:
		p.stream_paused = music_muted or channel_gain(music_volume) <= 0
	ambient.volume_db = linear_to_db(maxf(channel_gain(environment_volume), 0.0001)) + AMBIENT_GAIN_DB.get(current_ambient, -12.0)
	ambient.stream_paused = effects_muted or channel_gain(environment_volume) <= 0
	for p in effects:
		p.volume_db = linear_to_db(maxf(channel_gain(character_volume), 0.0001)) - 6.0
		if effects_muted or channel_gain(character_volume) <= 0: p.stop()
	for p in footstep_voices:
		p.volume_db = linear_to_db(maxf(channel_gain(character_volume), 0.0001)) + p.get_meta("step_gain", -10.0)
		# Do not resume a stale footstep after unmuting.
		if effects_muted or channel_gain(character_volume) <= 0:
			p.stop()

func _update_music_gain() -> void:
	if fade and fade.is_running():
		fade.kill()
	music[1-active].stop()
	last_music_gain = channel_gain(music_volume)
	music[active].volume_db = linear_to_db(maxf(last_music_gain, 0.0001)) - 6.0

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

func _exit_tree() -> void:
	if fade: fade.kill()
	for player in music + effects + footstep_voices:
		player.stop()
	if is_instance_valid(ambient): ambient.stop()
	if is_instance_valid(ui_audio): ui_audio.stop()
