extends Node
## Shared channel controls for the title and gameplay audio players.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const DEFAULT_MUSIC := 0.22
const DEFAULT_EFFECTS := 0.35
var master_volume := 1.0
var music_volume := DEFAULT_MUSIC
var character_volume := DEFAULT_EFFECTS
var environment_volume := DEFAULT_EFFECTS
var ui_volume := DEFAULT_EFFECTS
var music_muted := false
var effects_muted := false
# Retained for development tools that silence every effect together.
var effects_volume: float:
	get: return character_volume
	set(value):
		character_volume = clampf(value, 0.0, 1.0)
		environment_volume = character_volume
		ui_volume = character_volume

func load_audio_preferences() -> void:
	var saved := Preferences.read()
	master_volume = clampf(float(saved.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(saved.get_value("audio", "music_volume", DEFAULT_MUSIC)), 0.0, 1.0)
	var legacy_effects := float(saved.get_value("audio", "effects_volume", DEFAULT_EFFECTS))
	character_volume = clampf(float(saved.get_value("audio", "character_volume", legacy_effects)), 0.0, 1.0)
	environment_volume = clampf(float(saved.get_value("audio", "environment_volume", legacy_effects)), 0.0, 1.0)
	ui_volume = clampf(float(saved.get_value("audio", "ui_volume", legacy_effects)), 0.0, 1.0)
	music_muted = bool(saved.get_value("audio", "music_muted", false))
	effects_muted = bool(saved.get_value("audio", "effects_muted", false))

func channel_gain(channel: float) -> float:
	return master_volume * channel

func apply_volume() -> void:
	pass

func save_preferences() -> void:
	Preferences.save_audio({
		"master_volume": master_volume, "music_volume": music_volume,
		"character_volume": character_volume, "environment_volume": environment_volume,
		"ui_volume": ui_volume, "effects_volume": effects_volume,
		"music_muted": music_muted, "effects_muted": effects_muted,
	})

func _commit_audio() -> void:
	apply_volume()
	save_preferences()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_commit_audio()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	music_muted = false
	_commit_audio()

func _clear_effects_mute() -> void:
	if effects_muted:
		# An old mute remains zero on the other sliders when one channel changes.
		effects_volume = 0.0
		effects_muted = false

func set_character_volume(value: float) -> void:
	_clear_effects_mute()
	character_volume = clampf(value, 0.0, 1.0)
	_commit_audio()

func set_environment_volume(value: float) -> void:
	_clear_effects_mute()
	environment_volume = clampf(value, 0.0, 1.0)
	_commit_audio()

func set_ui_volume(value: float) -> void:
	_clear_effects_mute()
	ui_volume = clampf(value, 0.0, 1.0)
	_commit_audio()

func reset_audio() -> void:
	master_volume = 1.0
	music_volume = DEFAULT_MUSIC
	effects_volume = DEFAULT_EFFECTS
	music_muted = false
	effects_muted = false
	_commit_audio()

func set_effects_volume(value: float) -> void:
	effects_volume = value
	_commit_audio()

func set_music_muted(value: bool) -> void:
	music_muted = value
	_commit_audio()

func set_effects_muted(value: bool) -> void:
	effects_muted = value
	_commit_audio()
