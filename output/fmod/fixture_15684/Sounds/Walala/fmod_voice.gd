extends Node
## Scene-owned FMOD Core channel. AudioStream resources supply metadata only;
## FMOD decodes and mixes the original OGG/WAV bytes, including in exported PCKs.
var channel: FmodSound
var _path := ""
var _runtime: Node
var stream: AudioStream:
	set(value):
		if stream == value: return
		stop()
		_release_file()
		stream = value
var volume_db := 0.0:
	set(value):
		volume_db = value
		if _valid(): channel.set_volume(db_to_linear(volume_db))
var pitch_scale := 1.0:
	set(value):
		pitch_scale = value
		if _valid(): channel.set_pitch(pitch_scale)
var stream_paused := false:
	set(value):
		stream_paused = value
		_sync_pause()
var playing: bool:
	get: return _valid() and channel.is_playing()

func _valid() -> bool:
	return channel != null and channel.is_valid()

func play() -> void:
	stop()
	if stream == null or not is_inside_tree(): return
	_runtime = get_node("/root/WalalaFmod")
	if _path.is_empty():
		var path := String(stream.get_meta("fmod_source_path", stream.resource_path))
		var looping: bool = stream is AudioStreamOggVorbis and stream.loop
		if path.is_empty() or not _runtime.acquire(path, looping): return
		_path = path
	channel = FmodServer.create_sound_instance(_path)
	if not _valid():
		push_error("FMOD could not create channel: " + _path)
		channel = null
		return
	# Channels start paused: configure gain and pitch before the first sample.
	channel.set_volume(db_to_linear(volume_db))
	channel.set_pitch(pitch_scale)
	_sync_pause()

func stop() -> void:
	if _valid(): channel.stop()
	channel = null

func _sync_pause() -> void:
	if _valid(): channel.set_paused(stream_paused or (is_inside_tree() and not can_process()))

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_sync_pause()

func _release_file() -> void:
	if not _path.is_empty() and is_instance_valid(_runtime):
		_runtime.release_file(_path)
	_path = ""

func _exit_tree() -> void:
	stop()
	_release_file()
