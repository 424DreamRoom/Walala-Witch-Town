extends Control
## A paused 3×7 piano board: rows are octaves and columns are natural notes.
const InstrumentLibrary = preload("res://Scenes/Instrument/instrument_library.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")

const COLUMNS := 7
const KEY_CODES := [
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U,
	KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J,
	KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M,
]
const ROW_COLORS := [Color("e6c483"), Color("d5b879"), Color("b6c38e")]
const ROW_HOVER_COLORS := [Color("f0d99d"), Color("e5ca91"), Color("cbd9a5")]

var hud
var loop
var instrument_kind := "piano"
var title_label: Label
var close_button: Button
var note_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _panel(rect: Rect2, parent: Node) -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.add_theme_stylebox_override("panel", UISkin.panel_style())
	parent.add_child(result)
	return result

func _button_style(color: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(border_width)
	result.corner_radius_top_left = 2
	result.corner_radius_top_right = 2
	result.corner_radius_bottom_left = 2
	result.corner_radius_bottom_right = 2
	result.content_margin_left = 2
	result.content_margin_right = 2
	result.content_margin_top = 2
	result.content_margin_bottom = 2
	return result

func _build() -> void:
	var frame := _panel(Rect2(24, 14, 592, 332), self)
	title_label = Label.new()
	title_label.name = "InstrumentTitle"
	title_label.text = tr("钢琴")
	title_label.position = Vector2(18, 8)
	title_label.size = Vector2(260, 28)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIFont.apply_control(title_label, 20)
	frame.add_child(title_label)
	close_button = Button.new()
	close_button.name = "CloseInstrument"
	close_button.text = tr("返回")
	close_button.position = Vector2(500, 8)
	close_button.size = Vector2(72, 26)
	close_button.focus_mode = Control.FOCUS_ALL
	UIFont.apply_control(close_button)
	UISkin.compact_button(close_button)
	close_button.pressed.connect(func(): hud.close_modal())
	frame.add_child(close_button)
	var board := _panel(Rect2(28, 52, 536, 246), frame)
	board.name = "PianoBoard"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var origin := Vector2(8, 14)
	var key_size := Vector2(70, 62)
	var gap := Vector2(5, 7)
	for index in range(InstrumentLibrary.NOTE_NAMES.size()):
		var row := floori(index / float(COLUMNS))
		var column := index % COLUMNS
		var key := Button.new()
		key.name = "PianoKey_%s" % InstrumentLibrary.NOTE_NAMES[index]
		key.text = InstrumentLibrary.NOTE_NAMES[index]
		key.position = origin + Vector2(column, row) * (key_size + gap)
		key.size = key_size
		key.focus_mode = Control.FOCUS_ALL
		key.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UIFont.apply_control(key, 14)
		UISkin.compact_button(key)
		key.add_theme_stylebox_override("normal", _button_style(ROW_COLORS[row], Color("6c513c")))
		key.add_theme_stylebox_override("hover", _button_style(ROW_HOVER_COLORS[row], Color("8a603a"), 2))
		key.add_theme_stylebox_override("pressed", _button_style(ROW_HOVER_COLORS[row], Color("493b3c"), 2))
		key.add_theme_stylebox_override("focus", _button_style(Color(1, 1, 1, 0.18), Color("fff0b7"), 2))
		key.pressed.connect(_play_note.bind(index))
		board.add_child(key)
		note_buttons.append(key)
	if not note_buttons.is_empty():
		note_buttons[0].grab_focus()

func _play_note(index: int) -> void:
	if index < 0 or index >= InstrumentLibrary.NOTE_NAMES.size():
		return
	loop.audio.play_instrument_note(index)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	# Let the HUD handle the configured pause/return key before piano shortcuts.
	# A custom pause key may itself be one of the piano's QWERTY keys.
	if event.is_action_pressed("ui_cancel"):
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var index := KEY_CODES.find(code)
	if index < 0:
		return
	_play_note(index)
	get_viewport().set_input_as_handled()

func refresh_language() -> void:
	if is_instance_valid(title_label): title_label.text = tr("钢琴")
	if is_instance_valid(close_button): close_button.text = tr("返回")

