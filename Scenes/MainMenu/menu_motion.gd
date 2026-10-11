extends Node2D
## Short, interruptible entrances and feedback on the native pixel grid.
signal entrance_finished

const ENTRANCE_DURATION := 0.8
var elapsed := 0.0
var entrance_complete := false
var keyboard_navigation := true
var title: Label
var subtitle: Label
var buttons: Array[Button] = []
var origins: Array[Vector2] = []
var highlights: Array[float] = []
var title_origin := Vector2.ZERO
var subtitle_origin := Vector2.ZERO

func setup(heading: Label, caption: Label, choices: Array[Button]) -> void:
	title = heading
	subtitle = caption
	title_origin = title.position
	subtitle_origin = subtitle.position
	buttons = choices
	for button in buttons:
		origins.append(button.position)
		highlights.append(0.0)
	_update_controls(0.0)

func finish_entrance() -> void:
	# Input always wins over presentation; there is no animation input lock.
	elapsed = maxf(elapsed, ENTRANCE_DURATION)
	_update_controls(0.0)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		keyboard_navigation = false
	elif event is InputEventMouseButton and event.pressed:
		keyboard_navigation = false
		finish_entrance()
	elif (event is InputEventKey and event.pressed and not event.echo) or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		keyboard_navigation = true
		finish_entrance()

func _process(delta: float) -> void:
	if not is_instance_valid(title):
		return
	elapsed += delta
	_update_controls(delta)
	queue_redraw()

func _reveal(control: Control, origin: Vector2, delay: float, distance: float) -> void:
	var progress := clampf((elapsed - delay) / 0.32, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	control.position = origin + Vector2(0, roundf(distance * (1.0 - eased)))
	control.modulate.a = eased

func _active_button() -> int:
	# Follow the most recently used input, including a parked mouse cursor.
	if not keyboard_navigation:
		for i in range(buttons.size()):
			if not buttons[i].disabled and buttons[i].is_hovered():
				return i
	for i in range(buttons.size()):
		if not buttons[i].disabled and buttons[i].has_focus():
			return i
	return -1

func _update_controls(delta: float) -> void:
	_reveal(subtitle, subtitle_origin, 0.0, 5.0)
	_reveal(title, title_origin, 0.06, 10.0)
	# One native pixel of breathing keeps the heading crisp at every scale.
	if elapsed >= ENTRANCE_DURATION:
		title.position.y = title_origin.y + roundf(sin((elapsed - ENTRANCE_DURATION) * 1.1))
	var active := _active_button()
	for i in range(buttons.size()):
		var button := buttons[i]
		_reveal(button, origins[i], 0.18 + i * 0.08, 9.0)
		highlights[i] = move_toward(highlights[i], 1.0 if i == active else 0.0, delta * 8.0)
		button.self_modulate = Color.WHITE.lerp(Color(1.12, 1.06, 1.0), highlights[i])
		if not button.disabled and button.is_pressed():
			button.position.y += 1.0
	if not entrance_complete and elapsed >= ENTRANCE_DURATION:
		entrance_complete = true
		entrance_finished.emit()

func _draw() -> void:
	for i in range(buttons.size()):
		if buttons[i].disabled or highlights[i] <= 0.0:
			continue
		var button := buttons[i]
		var alpha := highlights[i] * button.modulate.a
		var drift := roundf(sin(elapsed * 3.0) * 2.0)
		for side in [-1.0, 1.0]:
			var x: float = button.position.x + button.size.x * 0.5 + side * (button.size.x * 0.5 + 10.0 + drift)
			var center := Vector2(x, button.position.y + button.size.y * 0.5)
			draw_rect(Rect2(center - Vector2(4, 4), Vector2(9, 9)), Color(1.0, 0.77, 0.43, alpha * 0.08))
			draw_rect(Rect2(center - Vector2(2, 0), Vector2(5, 1)), Color(1.0, 0.87, 0.63, alpha))
			draw_rect(Rect2(center - Vector2(0, 2), Vector2(1, 5)), Color(1.0, 0.87, 0.63, alpha))
