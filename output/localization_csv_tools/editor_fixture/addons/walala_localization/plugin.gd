@tool
extends EditorPlugin
## Development-only Excel export. Shipped games only need the generated CSV.
const DIRECTORY := "res://Excel/Localization"
const BUILDER := "res://Localization/build_catalog.py"
var _elapsed := 0.0
var _last_fingerprint := ""
var _last_error := ""
var _python := ""
var _python_args := PackedStringArray()

func _enter_tree() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0:
		return
	_elapsed = 0.0
	_sync(false)

func _build() -> bool:
	return _sync(true)

func _fingerprint(directory: String = DIRECTORY) -> String:
	var parts := PackedStringArray()
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_lower() == "xlsx" and not filename.begins_with("~$"):
			var path := directory.path_join(filename)
			parts.append(path + ":" + FileAccess.get_sha256(path))
	for folder in DirAccess.get_directories_at(directory):
		parts.append(_fingerprint(directory.path_join(folder)))
	parts.sort()
	return "\n".join(parts).sha256_text()

func _find_python() -> bool:
	var configured: String = ProjectSettings.get_setting("walala/localization/python_executable", "")
	var candidates := PackedStringArray([configured, OS.get_environment("WALALA_PYTHON")])
	# Also support the Python bundled with Codex on a development workstation.
	var profile := OS.get_environment("USERPROFILE")
	if not profile.is_empty():
		candidates.append(profile.path_join(".cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"))
	candidates.append_array(PackedStringArray(["python3", "python", "py"]))
	for candidate in candidates:
		if candidate.is_empty():
			continue
		var prefix := PackedStringArray(["-3"]) if candidate == "py" else PackedStringArray()
		var arguments := prefix.duplicate()
		arguments.append_array(PackedStringArray(["-c", "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)"]))
		if OS.execute(candidate, arguments, [], true, false) == 0:
			_python = candidate
			_python_args = prefix
			return true
	return false

func _sync(force: bool) -> bool:
	var fingerprint := _fingerprint()
	if not force and fingerprint == _last_fingerprint:
		return true
	if _python.is_empty() and not _find_python():
		_report_error("Python 3.10+ is required for Excel export. Set WALALA_PYTHON or walala/localization/python_executable.")
		return false
	var output: Array = []
	var arguments := _python_args.duplicate()
	arguments.append_array(PackedStringArray(["-X", "utf8"]))
	arguments.append(ProjectSettings.globalize_path(BUILDER))
	var result := OS.execute(_python, arguments, output, true, false)
	if result != 0:
		_report_error("Excel localization export failed; previous CSV preserved.\n" + "\n".join(output))
		return false
	_last_fingerprint = fingerprint
	_last_error = ""
	print("\n".join(output).strip_edges())
	get_editor_interface().get_resource_filesystem().scan()
	return true

func _report_error(message: String) -> void:
	if message != _last_error:
		push_warning(message)
		_last_error = message
