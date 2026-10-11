extends Node
## Shared UI feedback. These four voices keep playing when a UI pauses the world.
const SOUNDS := {
	"ui_hover": [preload("res://Sounds/Walala/UI/Organic/hover.wav"), -2.0],
	"ui_click": [preload("res://Sounds/Walala/UI/Organic/click.wav"), 3.0],
	"ui_open": [preload("res://Sounds/Walala/UI/Organic/open.wav"), -5.0],
	"ui_close": [preload("res://Sounds/Walala/UI/Organic/close.wav"), 0.0],
	"ui_confirm": [preload("res://Sounds/Walala/UI/Organic/confirm.ogg"), -12.0],
	"ui_error": [preload("res://Sounds/Walala/UI/Organic/error.ogg"), -15.0],
	"ui_toggle": [preload("res://Sounds/Walala/UI/Organic/toggle.wav"), 2.0],
	"ui_slider": [preload("res://Sounds/Walala/UI/Organic/slider.wav"), 8.0],
	"ui_page": [preload("res://Sounds/Walala/UI/page.ogg"), -13.0],
	"ui_book_open": [preload("res://Sounds/Walala/UI/book_open.ogg"), -13.0],
	"ui_book_close": [preload("res://Sounds/Walala/UI/book_close.ogg"), -15.0],
}
var voices: Array[AudioStreamPlayer] = []
var volume := 0.35
var muted := false
var counts := {}
var last_play := {}
var next_voice := 0
var navigating := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func set_volume(value: float, disabled: bool) -> void:
	volume = clampf(value, 0.0, 1.0)
	muted = disabled
	for voice in voices:
		if muted or volume <= 0.0:
			voice.stop()
		else:
			voice.volume_db = linear_to_db(volume) + float(voice.get_meta("gain", -12.0))

func play(key: String) -> void:
	if key == "ui":
		key = "ui_click"
	if not SOUNDS.has(key) or muted or volume <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var interval := 90 if key in ["ui_hover", "ui_slider"] else 40
	if now - int(last_play.get(key, -1000)) < interval:
		return
	last_play[key] = now
	# A hover or slider tick never interrupts an active confirmation/page sound.
	var voice: AudioStreamPlayer = null
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		if key in ["ui_hover", "ui_slider"]:
			return
		voice = voices[next_voice]
		next_voice = (next_voice + 1) % voices.size()
	voice.stop()
	voice.stream = SOUNDS[key][0]
	voice.set_meta("gain", SOUNDS[key][1])
	voice.volume_db = linear_to_db(volume) + float(SOUNDS[key][1])
	voice.play()
	counts[key] = counts.get(key, 0) + 1

func bind_button(button: BaseButton) -> void:
	button.mouse_entered.connect(func():
		if not button.disabled and button.is_visible_in_tree():
			play("ui_hover"))
	button.focus_entered.connect(func():
		# The input event is tracked directly, including forwarded SubViewport input.
		if navigating and not button.disabled and button.is_visible_in_tree():
			play("ui_hover"))

func navigation_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction:
		navigating = event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_focus_next", true) or event.is_action_pressed("ui_focus_prev", true)
	elif event is InputEventMouse:
		navigating = false

func _input(event: InputEvent) -> void:
	navigation_input(event)

func bind_slider(slider: Slider) -> void:
	slider.value_changed.connect(func(_value: float): play("ui_slider"))

func stop() -> void:
	for voice in voices:
		voice.stop()
