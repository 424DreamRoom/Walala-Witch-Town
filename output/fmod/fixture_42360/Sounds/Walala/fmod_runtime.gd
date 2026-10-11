extends Node
## Shared FMOD file cache and update pump, including while the world pauses.
var files := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	FmodServer.update()

func acquire(path: String, looping: bool) -> bool:
	if files.has(path):
		if files[path].looping != looping:
			push_error("Conflicting FMOD loop mode: " + path)
			return false
		files[path].users += 1
		return true
	if not FileAccess.file_exists(path):
		push_error("Missing FMOD audio source: " + path)
		return false
	var file = FmodServer.load_file_as_music(path) if looping else FmodServer.load_file_as_sound(path)
	if file == null:
		push_error("FMOD could not load: " + path)
		return false
	files[path] = {"file": file, "users": 1, "looping": looping}
	return true

func release_file(path: String) -> void:
	if not files.has(path): return
	files[path].users -= 1
	if files[path].users == 0:
		FmodServer.unload_file(path)
		files.erase(path)

func _exit_tree() -> void:
	for path in files:
		FmodServer.unload_file(path)
	files.clear()
