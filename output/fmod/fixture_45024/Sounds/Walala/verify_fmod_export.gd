extends Node
## Runs from a Windows release PCK, without any source project alongside it.
const Voice = preload("res://Sounds/Walala/fmod_voice.gd")
const Library = preload("res://Sounds/Walala/music_library.gd")
const CLICK = preload("res://Sounds/Walala/UI/Organic/hover.wav")
var failures := 0
var checks := 0

func check(title: String, passed: bool) -> void:
	checks += 1
	print("FMOD EXPORT ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func _ready() -> void:
	var runtime = get_node("/root/WalalaFmod")
	check("release native library loads", Engine.has_singleton("FmodServer"))
	for path in [CLICK.resource_path, Library.TRACKS.title.resource_path]:
		check("original bytes included " + path.get_extension(), FileAccess.get_file_as_bytes(path).size() > 100)
	var click := Voice.new()
	click.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(click)
	click.stream = CLICK
	click.volume_db = -40.0
	click.play()
	check("WAV plays through FMOD", click.playing)
	await get_tree().create_timer(CLICK.get_length() + 0.2).timeout
	check("WAV ends naturally", not click.playing)
	click.queue_free()
	await get_tree().process_frame
	var music := Voice.new()
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	music.stream = Library.looped("title")
	music.pitch_scale = 8.0
	music.volume_db = -80.0
	music.play()
	check("OGG plays through FMOD", music.playing)
	check("native gain matches settings", absf(music.channel.get_volume() - db_to_linear(-80.0)) < 0.00001)
	get_tree().paused = true
	await get_tree().create_timer(music.stream.get_length() / 8.0 + 0.3).timeout
	check("OGG loops while paused", music.playing)
	get_tree().paused = false
	music.queue_free()
	await get_tree().process_frame
	check("release cache fully freed", runtime.files.is_empty())
	print("FMOD EXPORT VERIFY END failures=", failures, " checks=", checks)
	get_tree().quit(0 if failures == 0 else 1)
