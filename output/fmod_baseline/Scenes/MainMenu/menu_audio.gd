extends "res://Sounds/Walala/audio_settings.gd"
## Title-screen audio only; gameplay loads its own effects after scene handoff.
const MusicLibrary = preload("res://Sounds/Walala/music_library.gd")
var music: AudioStreamPlayer
var ui_audio
var fade: Tween

func _ready() -> void:
	load_audio_preferences()
	music = AudioStreamPlayer.new()
	music.stream = MusicLibrary.looped("title")
	add_child(music)
	ui_audio = preload("res://Sounds/Walala/ui_audio.gd").new()
	add_child(ui_audio)
	apply_volume()
	music.volume_db = -60.0
	music.play()
	fade = create_tween()
	fade.tween_property(music, "volume_db", linear_to_db(maxf(channel_gain(music_volume), 0.0001)) - 6.0, 0.8)

func apply_volume() -> void:
	if fade and fade.is_running():
		fade.kill()
	music.volume_db = linear_to_db(maxf(channel_gain(music_volume), 0.0001)) - 6.0
	music.stream_paused = music_muted or channel_gain(music_volume) <= 0.0
	ui_audio.set_volume(channel_gain(ui_volume), effects_muted)

func play_event(key: String) -> void:
	ui_audio.play(key)

func stop() -> void:
	if fade:
		fade.kill()
	music.stop()
	ui_audio.stop()

func _exit_tree() -> void:
	stop()
