extends CanvasLayer
## Persistent full-window cover for both world swaps and SceneTree changes.
signal finished

const FADE_OUT_SECONDS := 0.25
const FADE_IN_SECONDS := 0.25
var active := false
var cover: ColorRect
var tween: Tween
var paused_before := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	cover = ColorRect.new()
	cover.name = "SceneFade"
	cover.color = Color(0, 0, 0, 0)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.focus_mode = Control.FOCUS_NONE
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.hide()
	set_process_input(false)

func _begin() -> void:
	active = true
	paused_before = get_tree().paused
	get_tree().paused = true
	# Input runs in reverse tree order, including always-processing HUDs.
	get_tree().root.move_child(self, -1)
	set_process_input(true)
	cover.color.a = 0.0
	cover.show()

func _fade(alpha: float, seconds: float) -> void:
	tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cover, "color:a", alpha, seconds)
	await tween.finished

func _finish() -> void:
	await _fade(0.0, FADE_IN_SECONDS)
	cover.hide()
	set_process_input(false)
	get_tree().paused = paused_before
	active = false
	finished.emit()

func run(action: Callable) -> Error:
	if active: return ERR_BUSY
	_begin()
	await _fade(1.0, FADE_OUT_SECONDS)
	# Present a fully covered frame before any synchronous resource loading.
	await get_tree().process_frame
	var error := OK
	if action.is_valid():
		action.call()
	else:
		error = ERR_DOES_NOT_EXIST
	get_tree().paused = true
	await get_tree().process_frame
	await _finish()
	return error

func change_scene(path: String) -> Error:
	if active: return ERR_BUSY
	_begin()
	await _fade(1.0, FADE_OUT_SECONDS)
	await get_tree().process_frame
	# New scenes must capture their own pause state (intro, dialogue, menus).
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(path)
	if error == OK:
		await get_tree().scene_changed
		get_tree().root.move_child(self, -1)
		await get_tree().process_frame
		paused_before = get_tree().paused
	get_tree().paused = true
	await _finish()
	return error

func _input(_event: InputEvent) -> void:
	if active:
		get_viewport().set_input_as_handled()
