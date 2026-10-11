extends Button
var activate: Callable

func _gui_input(event: InputEvent) -> void:
	if disabled: return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		grab_focus()
		activate.call(event.button_index == MOUSE_BUTTON_RIGHT, event.shift_pressed)
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		activate.call(false, false)
		accept_event()
	elif event.is_action_pressed("pad_split"):
		activate.call(true, false)
		accept_event()
	elif event.is_action_pressed("pad_transfer"):
		activate.call(false, true)
		accept_event()
