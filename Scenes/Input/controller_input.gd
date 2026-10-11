extends Node
## SDL-normalized controllers. Settings stay separate from game progress.
signal controller_changed
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const LAYOUTS := ["auto", "xbox", "playstation", "switch"]
const DIRECTIONS := ["ui_left", "ui_right", "ui_up", "ui_down"]
const OWNED := ["move_up", "move_down", "move_left", "move_right", "run", "interact", "bag", "journal", "guide", "pause", "dialogue_next", "history", "map", "ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev", "pad_split", "pad_transfer"]
var layout := "auto"
var deadzone := 0.24
var active_device := -1
var using_controller := false
var pointer_active := false
var pointer_position := Vector2.ZERO
var pointer_axis := Vector2.ZERO
var sending_mouse := false
var mouse_buttons := 0
var navigation := Vector2.ZERO
var repeat_direction := ""
var repeat_left := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_connection_changed)
	Input.ignore_joypad_on_unfocused_application = true
	get_tree().node_added.connect(func(node: Node):
		if node.get_parent() == get_tree().root: _promote_input.call_deferred())
	_promote_input.call_deferred()
	reload_settings()

func _promote_input() -> void:
	# Observe events before scene handlers consume them, including paused modals.
	get_tree().root.move_child(self, -1)

static func family(name: String, vendor: int = 0) -> String:
	var lower := name.to_lower()
	if vendor == 0x057e or "nintendo" in lower or "switch" in lower or "joy-con" in lower or "joycon" in lower: return "switch"
	if vendor == 0x054c or "playstation" in lower or "dualshock" in lower or "dualsense" in lower or "ps3" in lower or "ps4" in lower or "ps5" in lower or lower == "wireless controller": return "playstation"
	return "xbox"

func device_layout(device: int) -> String:
	if layout != "auto": return layout
	if device < 0: return "xbox"
	var info := Input.get_joy_info(device)
	return family(Input.get_joy_name(device), int(info.get("vendor_id", 0)))

func current_layout() -> String:
	if active_device >= 0: return device_layout(active_device)
	var devices := Input.get_connected_joypads()
	return device_layout(devices[0]) if not devices.is_empty() else (layout if layout != "auto" else "xbox")

func reload_settings() -> void:
	var saved: Variant = Preferences.value("controller", "layout", "auto")
	layout = saved if saved is String and saved in LAYOUTS else "auto"
	var zone: Variant = Preferences.value("controller", "deadzone", 0.24)
	deadzone = clampf(float(zone), 0.1, 0.5) if (zone is float or zone is int) and is_finite(float(zone)) else 0.24
	rebuild_mappings()

func set_layout(value: String) -> void:
	if value not in LAYOUTS: return
	Preferences.set_value("controller", "layout", value)
	reload_settings()

func set_deadzone(value: float) -> void:
	Preferences.set_value("controller", "deadzone", clampf(value, 0.1, 0.5))
	reload_settings()

func _button(action: String, index: int, device: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	InputMap.action_add_event(action, event)

func _axis(action: String, axis: int, value: float, device: int) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

func rebuild_mappings() -> void:
	for action in OWNED:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: InputMap.action_erase_event(action, event)
	for action in InputBindings.UI_DIRECTIONS: InputMap.action_set_deadzone(action, deadzone)
	var devices := Input.get_connected_joypads()
	if devices.is_empty(): devices.append(-1)
	for device in devices: map_device(device, device_layout(device))
	controller_changed.emit()

func map_device(device: int, kind: String) -> void:
	# Godot indices follow physical Xbox positions; Nintendo's A is east.
	var accept := JOY_BUTTON_B if kind == "switch" else JOY_BUTTON_A
	var cancel := JOY_BUTTON_A if kind == "switch" else JOY_BUTTON_B
	for action in ["interact", "dialogue_next", "ui_accept"]: _button(action, accept, device)
	for action in ["pause", "ui_cancel"]:
		_button(action, cancel, device)
		_button(action, JOY_BUTTON_START, device)
	_button("bag", JOY_BUTTON_Y if kind == "switch" else JOY_BUTTON_X, device)
	_button("history", JOY_BUTTON_X if kind == "switch" else JOY_BUTTON_Y, device)
	_button("pad_split", JOY_BUTTON_X if kind == "switch" else JOY_BUTTON_Y, device)
	_button("pad_transfer", JOY_BUTTON_RIGHT_SHOULDER, device)
	_button("journal", JOY_BUTTON_LEFT_SHOULDER, device)
	_button("guide", JOY_BUTTON_RIGHT_SHOULDER, device)
	_button("map", JOY_BUTTON_BACK, device)
	_button("run", JOY_BUTTON_LEFT_STICK, device)
	_button("ui_focus_prev", JOY_BUTTON_LEFT_SHOULDER, device)
	_button("ui_focus_next", JOY_BUTTON_RIGHT_SHOULDER, device)
	for item in [["move_up", "ui_up", JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0], ["move_down", "ui_down", JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0], ["move_left", "ui_left", JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0], ["move_right", "ui_right", JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0]]:
		_button(item[0], item[2], device)
		_axis(item[0], item[3], item[4], device)
		_button(item[1], item[2], device)
	# Left-stick menu navigation is edge-triggered below, with held repetition.

func _connection_changed(device: int, connected: bool) -> void:
	if not connected and device == active_device:
		_release_controller()
		active_device = -1
		using_controller = false
		pointer_active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rebuild_mappings()

func _release_controller() -> void:
	for action in OWNED: Input.action_release(action)
	navigation = Vector2.ZERO
	pointer_axis = Vector2.ZERO
	repeat_direction = ""
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if mouse_buttons & (1 << (button - 1)): _mouse_button(button, false)

func _mouse_button(button: int, pressed: bool) -> void:
	var mask := 1 << (button - 1)
	mouse_buttons = (mouse_buttons | mask) if pressed else (mouse_buttons & ~mask)
	var event := InputEventMouseButton.new()
	event.position = pointer_position
	event.global_position = pointer_position
	event.button_index = button
	event.button_mask = mouse_buttons
	event.pressed = pressed
	sending_mouse = true
	get_tree().root.push_input(event, true)
	sending_mouse = false

func _navigate(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_tree().root.push_input(event, true)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	get_tree().root.push_input(event, true)

func _stick_direction() -> String:
	if navigation.length() < 0.55: return ""
	if absf(navigation.x) > absf(navigation.y): return "ui_right" if navigation.x > 0.0 else "ui_left"
	return "ui_down" if navigation.y > 0.0 else "ui_up"

func _navigation_enabled() -> bool:
	if get_tree().paused: return true
	var scene := get_tree().current_scene
	var loop = scene.get_node_or_null("GameLoop") if scene != null else null
	if loop == null: return true
	if loop.state.phase == "result": return true
	return loop.location in ["blacksmith", "store"] and loop.area.service_panel.visible

func _input(event: InputEvent) -> void:
	if sending_mouse: return
	if event is InputEventMouseMotion and using_controller and pointer_active and event.position.is_equal_approx(pointer_position): return
	if event is InputEventMouse or (event is InputEventKey and event.pressed):
		using_controller = false
		pointer_active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	var intentional: bool = event.pressed if event is InputEventJoypadButton else absf(event.axis_value) >= deadzone
	if not intentional and event.device != active_device: return
	if active_device != event.device:
		navigation = Vector2.ZERO
		pointer_axis = Vector2.ZERO
		repeat_direction = ""
		active_device = event.device
		controller_changed.emit()
	if intentional: using_controller = true
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_X: pointer_axis.x = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_Y: pointer_axis.y = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_X: navigation.x = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_Y: navigation.y = event.axis_value
		elif event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			if InputBindings.capture_active: return
			var button := MOUSE_BUTTON_LEFT if event.axis == JOY_AXIS_TRIGGER_RIGHT else MOUSE_BUTTON_RIGHT
			var down: bool = event.axis_value > 0.55
			if down != bool(mouse_buttons & (1 << (button - 1))):
				if not pointer_active: pointer_position = get_tree().root.get_mouse_position()
				pointer_active = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_button(button, down)
	elif event.pressed and event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		pointer_active = false
		if not _navigation_enabled(): get_viewport().set_input_as_handled()
	if using_controller and not pointer_active: Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(delta: float) -> void:
	if not using_controller: return
	if not InputBindings.capture_active and pointer_axis.length() > deadzone:
		if not pointer_active: pointer_position = get_tree().root.get_mouse_position()
		pointer_active = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var previous := pointer_position
		var strength := (pointer_axis.length() - deadzone) / (1.0 - deadzone)
		pointer_position += pointer_axis.normalized() * minf(strength, 1.0) * 720.0 * minf(delta, 0.05)
		pointer_position = pointer_position.clamp(Vector2.ZERO, get_tree().root.get_visible_rect().size - Vector2.ONE)
		var event := InputEventMouseMotion.new()
		event.position = pointer_position
		event.global_position = pointer_position
		event.relative = pointer_position - previous
		event.button_mask = mouse_buttons
		sending_mouse = true
		if DisplayServer.get_name() != "headless": Input.warp_mouse(pointer_position)
		get_tree().root.push_input(event, true)
		sending_mouse = false
	if not _navigation_enabled():
		repeat_direction = ""
		return
	var direction := _stick_direction()
	var dpad := false
	for action in DIRECTIONS:
		if Input.is_action_pressed(action):
			direction = action
			dpad = true
			break
	if direction.is_empty():
		repeat_direction = ""
		return
	if direction != repeat_direction:
		repeat_direction = direction
		repeat_left = 0.38
		pointer_active = false
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		if not dpad: _navigate(direction)
	else:
		repeat_left -= delta
		if repeat_left <= 0.0:
			repeat_left = 0.1
			_navigate(direction)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: _release_controller()

func button_text(action: String) -> String:
	var kind := current_layout()
	var face := {"interact": "A", "dialogue_next": "A", "pause": "B / Menu", "bag": "X", "history": "Y", "journal": "LB", "guide": "RB", "map": "View", "run": "LS"}
	if kind == "playstation": face = {"interact": "×", "dialogue_next": "×", "pause": "○ / Options", "bag": "□", "history": "△", "journal": "L1", "guide": "R1", "map": "Share / Create", "run": "L3"}
	elif kind == "switch": face = {"interact": "A", "dialogue_next": "A", "pause": "B / +", "bag": "Y", "history": "X", "journal": "L", "guide": "R", "map": "-", "run": "LS"}
	if action in InputBindings.UI_DIRECTIONS: return tr("左摇杆 / 方向键")
	if action == "ui_accept": return face.interact
	if action == "ui_cancel": return face.pause
	if action == "pointer": return tr("右摇杆")
	if action == "pointer_accept": return {"xbox": "RT", "playstation": "R2", "switch": "ZR"}[kind]
	if action == "pointer_secondary": return {"xbox": "LT", "playstation": "L2", "switch": "ZL"}[kind]
	if action == "pad_split": return face.history
	if action == "pad_transfer": return face.guide
	return face.get(action, "—")
