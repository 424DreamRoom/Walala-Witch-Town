extends Node
## Two scene-owned FMOD voices crossfade scenery without restarting each frame.
const Voice = preload("res://Sounds/Walala/fmod_voice.gd")
const Library = preload("res://Sounds/Walala/world_audio_library.gd")
var voices: Array[Voice] = []
var keys := ["", ""]
var weights := [0.0, 0.0]
var current_key := ""
var active := 0
var volume := 0.35
var muted := false
var intensity := 0.0
var fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var voice := Voice.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		voices.append(voice)

func set_key(key: String) -> void:
	if key == current_key: return
	current_key = key
	if fade: fade.kill()
	fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if key.is_empty():
		for i in range(2):
			fade.tween_method(_set_weight.bind(i), weights[i], 0.0, 0.8)
		fade.chain().tween_callback(_stop_silent)
		return
	var old := active
	active = 1 - active
	voices[active].stop()
	keys[active] = key
	weights[active] = 0.0
	voices[active].stream = Library.looped(key)
	_apply_voice(active)
	voices[active].play()
	fade.tween_method(_set_weight.bind(old), weights[old], 0.0, 0.8)
	fade.tween_method(_set_weight.bind(active), 0.0, 1.0, 0.8)
	fade.chain().tween_callback(_stop_silent)

func _set_weight(value: float, index: int) -> void:
	weights[index] = value
	_apply_voice(index)

func _apply_voice(index: int) -> void:
	var pressure := 1.0 + intensity * 0.18
	voices[index].volume_db = linear_to_db(maxf(volume * weights[index] * pressure, 0.000001)) + Library.AMBIENCE_GAIN_DB.get(keys[index], 0.0)
	voices[index].stream_paused = muted or volume <= 0.0

func set_volume(value: float, silence: bool) -> void:
	volume = clampf(value, 0.0, 1.0)
	muted = silence
	for i in range(voices.size()): _apply_voice(i)

func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	for i in range(voices.size()): _apply_voice(i)

func _stop_silent() -> void:
	for i in range(2):
		if weights[i] <= 0.001:
			voices[i].stop()
			# Release FMOD's cached source when a location is no longer audible.
			voices[i].stream = null
			keys[i] = ""

func stop() -> void:
	if fade: fade.kill()
	current_key = ""
	for i in range(voices.size()):
		voices[i].stop()
		voices[i].stream = null
		weights[i] = 0.0
		keys[i] = ""

func _exit_tree() -> void:
	stop()
