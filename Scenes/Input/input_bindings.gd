extends Node
## Global keyboard preferences. Game progress never contains input settings.
signal bindings_changed
signal capture_updated
signal capture_finished(applied: bool)
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "run", "interact", "bag", "journal", "guide", "pause", "dialogue_next", "history", "map"]
const LABELS := ["向上移动", "向下移动", "向左移动", "向右移动", "跑步 / 步行", "场景互动", "随身背包", "任务手记", "小镇指南", "暂停 / 返回", "对话继续", "对话回看", "区域地图"]
const DEFAULT_KEYS := [[KEY_W, KEY_UP], [KEY_S, KEY_DOWN], [KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT], [KEY_SHIFT, 0], [KEY_E, 0], [KEY_B, 0], [KEY_J, 0], [KEY_H, 0], [KEY_ESCAPE, 0], [KEY_SPACE, 0], [KEY_L, 0], [KEY_M, 0]]
const UI_DIRECTIONS := {"move_up": "ui_up", "move_down": "ui_down", "move_left": "ui_left", "move_right": "ui_right"}
var bindings: Dictionary = {}
var capture_active := false
var capture_action := ""
var capture_slot := 0
var pending_key := 0
var capture_error := ""
var conflict_action := ""
var conflict_slot := 0
var capture_owner: WeakRef
var suppressed_keys: Dictionary = {}
var prompts: Array[WeakRef] = []
var token_pattern := RegEx.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	token_pattern.compile("\\b(Esc|Space|Shift|WASD|W|S|A|D|E|B|J|H|L|M)\\b|" + "空格")
	apply_saved_bindings()
	Localization.language_changed.connect(func(_locale: String): refresh_prompts())

func defaults() -> Dictionary:
	var result := {}
	for index in range(ACTIONS.size()): result[ACTIONS[index]] = DEFAULT_KEYS[index].duplicate()
	return result

func apply_saved_bindings() -> void:
	var loaded := defaults()
	var config := Preferences.read()
	for action in ACTIONS:
		loaded[action] = config.get_value("input", action, loaded[action])
	# Preserve older custom bindings when M is already assigned to another action.
	if not config.has_section_key("input", "map"):
		var used: Array = []
		for action in ACTIONS:
			if action != "map" and loaded[action] is Array: used.append_array(loaded[action])
		var candidates: Array = [KEY_M]
		for code in range(KEY_F4, KEY_F35 + 1): candidates.append(code)
		for code in candidates:
			if code not in used:
				loaded.map = [code, 0]
				break
	bindings = loaded if valid_map(loaded) else defaults()
	_apply_map()
	bindings_changed.emit()
	refresh_prompts()

func valid_key(code: int) -> bool:
	return (code >= KEY_SPACE and code <= KEY_ASCIITILDE) or (code >= KEY_ESCAPE and code <= KEY_F35) or code in [KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_PERIOD, KEY_KP_ADD, KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]

func valid_map(value: Dictionary) -> bool:
	var used := {}
	for action in ACTIONS:
		var keys: Variant = value.get(action)
		if not keys is Array or keys.size() != 2: return false
		for slot in range(2):
			if not keys[slot] is int: return false
			var code: int = keys[slot]
			if code == 0 and slot == 1: continue
			if not valid_key(code) or code in used or code in [KEY_ENTER, KEY_KP_ENTER, KEY_TAB]: return false
			if code == KEY_ESCAPE and action != "pause": return false
			used[code] = true
	return true

func _keyboard_events(action: String, keys: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	# Preserve existing controller bindings, including menu D-pad navigation.
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: InputMap.action_erase_event(action, event)
	Input.action_release(action)
	for code in keys:
		if code == 0: continue
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event(action, event)

func _apply_map() -> void:
	for action in ACTIONS: _keyboard_events(action, bindings[action])
	# Menu navigation follows the primary movement keys; Enter/Tab/Esc stay usable.
	for action in UI_DIRECTIONS: _keyboard_events(UI_DIRECTIONS[action], [bindings[action][0]])
	var cancel: Array = bindings.pause.duplicate()
	if KEY_ESCAPE not in cancel: cancel.append(KEY_ESCAPE)
	_keyboard_events("ui_cancel", cancel)
	_keyboard_events("ui_accept", [KEY_ENTER, KEY_KP_ENTER])

func _commit(value: Dictionary) -> Dictionary:
	if not valid_map(value): return {"ok": false, "error": "无效的按键。"}
	if Preferences.save_bindings(value) != OK: return {"ok": false, "error": "无法保存按键设置。"}
	bindings = value
	_apply_map()
	bindings_changed.emit()
	refresh_prompts()
	return {"ok": true}

func assign_key(action: String, slot: int, code: int, swap: bool = false) -> Dictionary:
	if action not in ACTIONS or slot not in [0, 1] or not valid_key(code): return {"ok": false, "error": "无效的按键。"}
	if code in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB]: return {"ok": false, "error": "此按键用于界面操作。"}
	var candidate := bindings.duplicate(true)
	for other in ACTIONS:
		for other_slot in range(2):
			if candidate[other][other_slot] != code or (other == action and other_slot == slot): continue
			if other != action and not swap:
				return {"ok": false, "conflict": other, "slot": other_slot}
			var previous: int = candidate[action][slot]
			candidate[other][other_slot] = previous
			# Swapping from an empty alternate slot keeps the other action usable.
			if other_slot == 0 and previous == 0:
				if candidate[other][1] == 0: return {"ok": false, "error": "不能移除最后一个按键。"}
				candidate[other] = [candidate[other][1], 0]
			break
	candidate[action][slot] = code
	return _commit(candidate)

func reset_defaults() -> Dictionary:
	return _commit(defaults())

func begin_capture(owner: Node, action: String, slot: int) -> void:
	if action not in ACTIONS or slot not in [0, 1]: return
	if capture_active: cancel_capture()
	capture_owner = weakref(owner)
	capture_action = action
	capture_slot = slot
	capture_active = true
	retry_capture()

func retry_capture() -> void:
	pending_key = 0
	conflict_action = ""
	capture_error = ""
	capture_updated.emit()

func confirm_swap() -> void:
	if capture_active and not conflict_action.is_empty(): _capture_result(assign_key(capture_action, capture_slot, pending_key, true))

func clear_alternate() -> void:
	if not capture_active or capture_slot != 1: return
	var candidate := bindings.duplicate(true)
	candidate[capture_action][1] = 0
	_capture_result(_commit(candidate))

func cancel_capture() -> void:
	if not capture_active: return
	capture_active = false
	capture_owner = null
	capture_finished.emit(false)

func _capture_result(result: Dictionary) -> void:
	if result.ok:
		capture_active = false
		capture_owner = null
		capture_finished.emit(true)
	else:
		conflict_action = result.get("conflict", "")
		conflict_slot = int(result.get("slot", 0))
		capture_error = result.get("error", "")
		capture_updated.emit()

func _release_captured_key(code: int) -> void:
	for action in ACTIONS:
		if code in bindings[action]: Input.action_release(action)
	for action in UI_DIRECTIONS:
		if code == bindings[action][0]: Input.action_release(UI_DIRECTIONS[action])
	if code in bindings.pause or code == KEY_ESCAPE: Input.action_release("ui_cancel")

func _input(event: InputEvent) -> void:
	if capture_active and not event is InputEventKey:
		if event.is_action_pressed("ui_cancel"):
			cancel_capture()
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code in suppressed_keys:
		_release_captured_key(code)
		if not event.pressed: suppressed_keys.erase(code)
		get_viewport().set_input_as_handled()
		return
	if not capture_active: return
	if capture_owner == null or not is_instance_valid(capture_owner.get_ref()):
		cancel_capture()
		return
	if event.pressed and code == KEY_ESCAPE:
		suppressed_keys[code] = true
		cancel_capture()
	elif not conflict_action.is_empty():
		# Let the conflict buttons receive ordinary GUI navigation and confirmation.
		return
	elif event.pressed and not event.echo:
		pending_key = code
		suppressed_keys[code] = true
		_release_captured_key(code)
		_capture_result(assign_key(capture_action, capture_slot, code))
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_capture()
		suppressed_keys.clear()

func is_bound_event(event: InputEventKey) -> bool:
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	for keys in bindings.values():
		if code in keys: return true
	return false

func is_action_press(event: InputEvent) -> bool:
	return (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction) and event.is_pressed() and not event.is_echo()

func key_name(code: int) -> String:
	if code == 0: return "—"
	if code == KEY_ESCAPE: return "Esc"
	if code == KEY_SPACE: return tr("空格")
	if code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]: return {KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}[code]
	return OS.get_keycode_string(code)

func key_text(action: String, include_alternate: bool = false) -> String:
	var keys: Array = bindings.get(action, [0, 0])
	return key_name(keys[0]) + (" / " + key_name(keys[1]) if include_alternate and keys[1] != 0 else "")

func action_name(action: String) -> String:
	return tr(LABELS[ACTIONS.find(action)]) if action in ACTIONS else action

func prompt(source: String) -> String:
	var text := String(TranslationServer.translate(source))
	var replacements := {"E": key_text("interact"), "Esc": key_text("pause"), "Space": key_text("dialogue_next"), "空格": key_text("dialogue_next"), "Shift": key_text("run"), "B": key_text("bag"), "J": key_text("journal"), "H": key_text("guide"), "L": key_text("history"), "W": key_text("move_up", false), "S": key_text("move_down", false), "A": key_text("move_left", false), "D": key_text("move_right", false)}
	replacements["WASD"] = " / ".join([key_text("move_up", false), key_text("move_left", false), key_text("move_down", false), key_text("move_right", false)])
	replacements["M"] = key_text("map")
	# Substitute from right to left, once, so swapped bindings never cascade.
	var matches := token_pattern.search_all(text)
	for index in range(matches.size() - 1, -1, -1):
		var item: RegExMatch = matches[index]
		text = text.substr(0, item.get_start()) + replacements[item.get_string()] + text.substr(item.get_end())
	return text

func track_prompt(control: Control, source: String) -> void:
	if token_pattern.search(source) == null: return
	control.set_meta("input_prompt_source", source)
	control.text = prompt(source)
	if control is Button:
		control.clip_text = true
		control.tooltip_text = control.text
	prompts.append(weakref(control))

func refresh_prompts() -> void:
	var alive: Array[WeakRef] = []
	for reference in prompts:
		var control = reference.get_ref()
		if is_instance_valid(control) and control.has_meta("input_prompt_source"):
			control.text = prompt(control.get_meta("input_prompt_source"))
			if control is Button: control.tooltip_text = control.text
			alive.append(reference)
	prompts = alive
