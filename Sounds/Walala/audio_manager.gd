extends Node
## Independent, bounded audio voices; no global buses or project settings altered.
const BASE = "res://Sounds/Walala/"
var streams = {}
var music: Array[AudioStreamPlayer] = []
var effects: Array[AudioStreamPlayer] = []
var ambient: AudioStreamPlayer
var current_music = ""
var current_ambient = ""
var active = 0
var fade: Tween
var music_volume = 0.22
var effects_volume = 0.35
var music_muted = false
var effects_muted = false
var counts = {}
var panel: Panel
var credits: Panel

func _ready() -> void:
	for key in ["day_town", "night_town3", "gather", "process", "cook", "serve", "coins", "ui", "rain", "wind"]:
		var ext = ".mp3" if key in ["day_town", "night_town3"] else ".ogg"
		var stream = load(BASE + key + ext).duplicate()
		if key in ["day_town", "night_town3", "rain", "wind"]:
			stream.loop = true
		streams[key] = stream
	for key in ["chop", "mine", "cast", "bite", "catch"]:
		streams[key] = load(BASE + key + ".wav")
	for i in range(2):
		var p = AudioStreamPlayer.new()
		add_child(p)
		music.append(p)
	for i in range(8):
		var p = AudioStreamPlayer.new()
		add_child(p)
		effects.append(p)
	ambient = AudioStreamPlayer.new()
	add_child(ambient)

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
		fade = create_tween().set_parallel(true)
		fade.tween_property(old, "volume_db", -60.0, 0.8)
		fade.tween_property(next, "volume_db", linear_to_db(maxf(music_volume, 0.0001)) - 6.0, 0.8)
		fade.chain().tween_callback(old.stop)
	var env = ""
	if location not in ["restaurant", "home"] and phase != "result":
		env = "rain" if weather == "rain" else ("wind" if weather == "snow" else "")
	if env != current_ambient:
		current_ambient = env
		ambient.stop()
		if not env.is_empty():
			ambient.stream = streams[env]
			ambient.play()
	apply_volume()

func play_event(key: String) -> void:
	counts[key] = counts.get(key, 0) + 1
	if effects_muted or effects_volume <= 0:
		return
	for p in effects:
		if not p.playing:
			p.stream = streams[key]
			p.volume_db = linear_to_db(effects_volume) - 6.0
			p.play()
			return

func apply_volume() -> void:
	for p in music:
		p.stream_paused = music_muted or music_volume <= 0
	ambient.volume_db = linear_to_db(maxf(effects_volume, 0.0001)) + (-24.0 if current_ambient == "wind" else -12.0)
	ambient.stream_paused = effects_muted or effects_volume <= 0
	for p in effects:
		p.volume_db = linear_to_db(maxf(effects_volume, 0.0001)) - 6.0
		p.stream_paused = effects_muted or effects_volume <= 0

func set_music_volume(value: float) -> void:
	music_volume = value
	_update_music_gain()
	apply_volume()

func _update_music_gain() -> void:
	if fade and fade.is_running():
		fade.kill()
	music[1-active].stop()
	music[active].volume_db = linear_to_db(maxf(music_volume, 0.0001)) - 6.0

func set_effects_volume(value: float) -> void:
	effects_volume = value
	apply_volume()

func build_ui(layer: CanvasLayer, font: Font) -> void:
	var button = Button.new()
	button.text = "声音 / 鸣谢"
	button.position = Vector2(542, 340)
	button.size = Vector2(96, 20)
	var compact = StyleBoxFlat.new()
	compact.bg_color = Color("28312f")
	compact.content_margin_top = 1
	compact.content_margin_bottom = 1
	compact.content_margin_left = 2
	compact.content_margin_right = 2
	for style in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style, compact)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	layer.add_child(button)
	panel = Panel.new()
	var background = StyleBoxFlat.new()
	background.bg_color = Color("28312f")
	panel.add_theme_stylebox_override("panel", background)
	panel.position = Vector2(440, 64)
	panel.size = Vector2(200, 246)
	panel.visible = false
	layer.add_child(panel)
	button.pressed.connect(func(): panel.visible = not panel.visible; play_event("ui"))
	var title = Label.new()
	title.text = "声音设置（不暂停营业）"
	title.position = Vector2(8, 8)
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 12)
	panel.add_child(title)
	for i in range(2):
		var mute = CheckButton.new()
		mute.text = "音乐静音" if i == 0 else "音效/环境静音"
		mute.position = Vector2(6, 38 + i * 72)
		mute.add_theme_font_override("font", font)
		mute.add_theme_font_size_override("font_size", 12)
		mute.focus_mode = Control.FOCUS_NONE
		panel.add_child(mute)
		mute.toggled.connect(func(on):
			if i == 0: music_muted = on
			else: effects_muted = on
			apply_volume())
		var slider = HSlider.new()
		slider.position = Vector2(12, 74 + i * 72)
		slider.size = Vector2(176, 20)
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = music_volume if i == 0 else effects_volume
		slider.focus_mode = Control.FOCUS_NONE
		panel.add_child(slider)
		slider.value_changed.connect(set_music_volume if i == 0 else set_effects_volume)
	var thanks = Button.new()
	thanks.text = "音频来源与许可鸣谢"
	thanks.position = Vector2(8, 185)
	thanks.size = Vector2(184, 32)
	thanks.add_theme_font_override("font", font)
	thanks.add_theme_font_size_override("font_size", 12)
	panel.add_child(thanks)
	credits = Panel.new()
	credits.add_theme_stylebox_override("panel", background.duplicate())
	credits.position = Vector2(20, 68)
	credits.size = Vector2(600, 236)
	credits.visible = false
	layer.add_child(credits)
	var text = RichTextLabel.new()
	text.position = Vector2(12, 12)
	text.size = Vector2(570, 174)
	text.add_theme_font_override("normal_font", font)
	text.add_theme_font_size_override("normal_font_size", 12)
	text.text = FileAccess.get_file_as_string(BASE + "CREDITS.txt")
	credits.add_child(text)
	var close = Button.new()
	close.text = "关闭鸣谢"
	close.position = Vector2(240, 194)
	close.size = Vector2(120, 30)
	close.add_theme_font_override("font", font)
	close.add_theme_font_size_override("font_size", 12)
	credits.add_child(close)
	close.pressed.connect(credits.hide)
	thanks.pressed.connect(func(): credits.show(); play_event("ui"))

func _exit_tree() -> void:
	if fade: fade.kill()
