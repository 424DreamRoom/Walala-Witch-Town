extends Panel
## One pixel-native settings panel shared by the title and paused game.
signal close_requested
signal credits_requested
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const PAGE_NAMES := ["声音", "画面", "游戏", "按键", "手柄"]
const CONTROLLER_DEADZONES := [0.1, 0.15, 0.24, 0.3, 0.4, 0.5]
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const FRAME_LIMITS := [30, 60, 120, 0]
const DIALOGUE_SPEEDS := [15.0, 30.0, 60.0, 0.0]
var audio
var close_button_name := "Back"
var selected_page := 0
var tabs: Array[Button] = []
var page_controls: Array = [[], [], [], [], []]
var controller_values: Dictionary = {}
var master_slider: HSlider
var music_slider: HSlider
var character_slider: HSlider
var environment_slider: HSlider
var ui_slider: HSlider
var brightness_slider: HSlider
var fullscreen_toggle: CheckButton
var resolution: OptionButton
var reset_button: Button
var binding_buttons: Dictionary = {}
var capture_overlay: ColorRect
var capture_title: Label
var capture_message: Label
var swap_button: Button
var retry_button: Button
var clear_button: Button
var cancel_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(560, 312)
	add_theme_stylebox_override("panel", UISkin.panel_style())
	_label("设置", Rect2(24, 14, 320, 32), 24)
	_rule(Rect2(20, 52, 520, 1))
	var paper := Panel.new()
	paper.position = Vector2(148, 68)
	paper.size = Vector2(392, 192)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_theme_stylebox_override("panel", UISkin.panel_style(true))
	add_child(paper)
	for index in range(PAGE_NAMES.size()):
		var tab := _button(PAGE_NAMES[index], Rect2(20, 68 + index * 36, 112, 30), select_page.bind(index))
		tab.name = ["AudioTab", "DisplayTab", "GameTab", "ControlsTab", "ControllerTab"][index]
		tab.toggle_mode = true
		tabs.append(tab)
	_rule(Rect2(20, 272, 520, 1))
	reset_button = _button("恢复本页", Rect2(20, 280, 112, 22), _reset_page)
	reset_button.name = "ResetPage"
	_button("鸣谢", Rect2(160, 280, 80, 22), func(): credits_requested.emit()).name = "Credits"
	_button("返回", Rect2(428, 280, 112, 22), func(): close_requested.emit()).name = close_button_name
	_build_audio()
	_build_display()
	_build_game()
	_build_controls()
	_build_controller()
	ControllerInput.controller_changed.connect(_refresh_controller_bindings)
	InputBindings.bindings_changed.connect(_refresh_bindings)
	InputBindings.capture_updated.connect(_refresh_capture)
	InputBindings.capture_finished.connect(_finish_capture)
	select_page(0, false)
	Localization.language_changed.connect(func(locale: String):
		var language := get_node_or_null("Language") as OptionButton
		if language != null: language.select(Localization.LOCALES.find(locale))
		_refresh_bindings()
		_refresh_controller_bindings()
		_refresh_capture())
	visibility_changed.connect(func():
		if is_visible_in_tree(): tabs[selected_page].grab_focus.call_deferred())

func _label(text: String, rect: Rect2, font_size: int = 12, color: Color = UISkin.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFont.apply_control(label, font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _rule(rect: Rect2) -> void:
	var rule := ColorRect.new()
	rule.color = Color("b98c57")
	rule.position = rect.position
	rule.size = rect.size
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	UIFont.apply_control(button)
	UISkin.compact_button(button)
	add_child(button)
	audio.ui_audio.bind_button(button)
	button.pressed.connect(callback)
	return button

func _page_label(page: int, text: String, rect: Rect2, color: Color = UISkin.INK) -> Label:
	var label := _label(text, rect, 12, color)
	page_controls[page].append(label)
	return label

func _heading(page: int, text: String) -> void:
	_page_label(page, text, Rect2(168, 80, 348, 18), UISkin.MUTED_INK)

func _slider(text: String, y: int, initial: float, setter: Callable, node_name: String) -> HSlider:
	_page_label(0, text, Rect2(168, y, 140, 24))
	var percent := _page_label(0, "%d" % roundi(initial * 100), Rect2(486, y, 36, 24))
	percent.name = node_name + "Value"
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.name = node_name
	slider.position = Vector2(320, y + 3)
	slider.size = Vector2(154, 20)
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	add_child(slider)
	page_controls[0].append(slider)
	slider.value_changed.connect(func(next: float):
		setter.call(next)
		percent.text = "%d" % roundi(next * 100))
	audio.ui_audio.bind_slider(slider)
	return slider

func _toggle(page: int, text: String, y: int, initial: bool, setter: Callable, node_name: String) -> CheckButton:
	_page_label(page, text, Rect2(168, y, 164, 24))
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.position = Vector2(438, y - 2)
	toggle.size = Vector2(84, 28)
	if page == 2:
		toggle.position.y = y
		toggle.size.y = 24
	toggle.text = "开" if initial else "关"
	toggle.button_pressed = initial
	UIFont.apply_control(toggle)
	toggle.add_theme_color_override("font_color", UISkin.INK)
	add_child(toggle)
	page_controls[page].append(toggle)
	toggle.toggled.connect(func(enabled: bool):
		setter.call(enabled)
		toggle.text = "开" if enabled else "关"
		audio.play_event("ui_toggle"))
	audio.ui_audio.bind_button(toggle)
	return toggle

func _option(page: int, text: String, y: int, items: Array, selected: int, setter: Callable, node_name: String) -> OptionButton:
	_page_label(page, text, Rect2(168, y, 104, 24))
	var option := OptionButton.new()
	option.name = node_name
	option.position = Vector2(330, y - 2)
	option.size = Vector2(192, 28)
	if page == 2:
		option.position.y = y
		option.size.y = 24
	UIFont.apply_control(option)
	for item in items: option.add_item(item)
	option.select(maxi(selected, 0))
	add_child(option)
	page_controls[page].append(option)
	audio.ui_audio.bind_button(option)
	var popup := option.get_popup()
	var popup_theme := UISkin.THEME.duplicate() as Theme
	popup_theme.set_font("font", "PopupMenu", UIFont.get_font())
	popup_theme.set_font_size("font_size", "PopupMenu", 12)
	popup_theme.set_color("font_color", "PopupMenu", UISkin.INK)
	popup_theme.set_stylebox("panel", "PopupMenu", UISkin.panel_style(true))
	for icon_name in ["radio_checked", "radio_unchecked", "radio_checked_disabled", "radio_unchecked_disabled"]:
		popup_theme.set_icon(icon_name, "PopupMenu", UISkin.THEME.get_icon(icon_name, "CheckBox"))
	popup_theme.set_constant("v_separation", "PopupMenu", 6)
	popup.theme = popup_theme
	option.item_selected.connect(func(index: int):
		setter.call(index)
		audio.play_event("ui_toggle"))
	return option

func _build_audio() -> void:
	master_slider = _slider("全局音量", 82, audio.master_volume, audio.set_master_volume, "MasterSlider")
	music_slider = _slider("音乐", 116, 0.0 if audio.music_muted else audio.music_volume, audio.set_music_volume, "MusicSlider")
	character_slider = _slider("角色音效", 150, 0.0 if audio.effects_muted else audio.character_volume, audio.set_character_volume, "CharacterSlider")
	environment_slider = _slider("环境音效", 184, 0.0 if audio.effects_muted else audio.environment_volume, audio.set_environment_volume, "EnvironmentSlider")
	ui_slider = _slider("UI音效", 218, 0.0 if audio.effects_muted else audio.ui_volume, audio.set_ui_volume, "UISlider")

func _build_display() -> void:
	fullscreen_toggle = _toggle(1, "全屏显示", 82, Preferences.value("display", "fullscreen", false), func(enabled: bool):
		Preferences.set_fullscreen(enabled)
		resolution.disabled = enabled, "FullscreenToggle")
	resolution = _option(1, "窗口尺寸", 116, ["1280 × 720", "1600 × 900", "1920 × 1080"], WINDOW_SIZES.find(Preferences.value("display", "window_size", WINDOW_SIZES[0])), func(index: int): Preferences.set_display("window_size", WINDOW_SIZES[index]), "WindowSize")
	resolution.disabled = fullscreen_toggle.button_pressed
	_toggle(1, "垂直同步", 150, Preferences.value("display", "vsync", true), func(enabled: bool): Preferences.set_display("vsync", enabled), "VSync")
	_option(1, "帧率上限", 184, ["30", "60", "120", "不限"], FRAME_LIMITS.find(int(Preferences.value("display", "frame_limit", 60))), func(index: int): Preferences.set_display("frame_limit", FRAME_LIMITS[index]), "FrameLimit")
	_build_brightness()

func _build_brightness() -> void:
	_page_label(1, "画面亮度", Rect2(168, 218, 140, 24)).name = "BrightnessLabel"
	var number := _page_label(1, str(roundi(Preferences.brightness())), Rect2(486, 218, 36, 24))
	number.name = "BrightnessValue"
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	brightness_slider = HSlider.new()
	brightness_slider.name = "BrightnessSlider"
	brightness_slider.position = Vector2(320, 221)
	brightness_slider.size = Vector2(154, 20)
	brightness_slider.min_value = -50.0
	brightness_slider.max_value = 50.0
	brightness_slider.step = 1.0
	brightness_slider.value = Preferences.brightness()
	add_child(brightness_slider)
	page_controls[1].append(brightness_slider)
	brightness_slider.value_changed.connect(func(next: float):
		Preferences.set_brightness(next)
		number.text = str(roundi(next)))
	audio.ui_audio.bind_slider(brightness_slider)

func _build_game() -> void:
	_heading(2, "游玩偏好")
	var language := _option(2, "语言", 100, Localization.LANGUAGE_NAMES, Localization.LOCALES.find(Localization.language), func(index: int): Localization.set_language(Localization.LOCALES[index]), "Language")
	# Every language stays identifiable in its own script.
	language.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_option(2, "对话速度", 126, ["慢", "标准", "快", "即时"], DIALOGUE_SPEEDS.find(Preferences.dialogue_speed()), func(index: int): Preferences.set_value("game", "dialogue_speed", DIALOGUE_SPEEDS[index]), "DialogueSpeed")
	_toggle(2, "默认跑步", 152, Preferences.value("game", "auto_run", false), func(enabled: bool): Preferences.set_value("game", "auto_run", enabled), "AutoRun")
	_toggle(2, "道具栏显示", 178, Preferences.value("game", "show_hotbar", true), func(enabled: bool): Preferences.set_value("game", "show_hotbar", enabled), "ShowHotbar")
	_toggle(2, "文字跳动", 204, Preferences.text_jump_enabled(), func(enabled: bool): Preferences.set_value("game", "text_jump", enabled), "TextJump")
	_toggle(2, "文字晃动", 230, Preferences.text_sway_enabled(), func(enabled: bool): Preferences.set_value("game", "text_sway", enabled), "TextSway")

func _build_controls() -> void:
	_heading(3, "键盘操作")
	for column in range(2):
		var heading := _page_label(3, ["主按键", "备用按键"][column], Rect2(312 + column * 96, 80, 88, 18), UISkin.MUTED_INK)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.name = "BindingsScroll"
	scroll.position = Vector2(160, 106)
	scroll.size = Vector2(368, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().step = 28.0
	add_child(scroll)
	page_controls[3].append(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 348
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	binding_buttons.clear()
	for index in range(InputBindings.ACTIONS.size()):
		var action: String = InputBindings.ACTIONS[index]
		var row := Control.new()
		row.custom_minimum_size = Vector2(348, 26)
		list.add_child(row)
		var label := Label.new()
		label.text = InputBindings.LABELS[index]
		label.position = Vector2(8, 0)
		label.size = Vector2(140, 24)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", UISkin.INK)
		UIFont.apply_control(label)
		row.add_child(label)
		binding_buttons[action] = []
		for slot in range(2):
			var button := Button.new()
			button.name = "Bind_" + action + "_" + str(slot)
			button.position = Vector2(152 + slot * 96, 0)
			button.size = Vector2(88, 24)
			button.clip_text = true
			UIFont.apply_control(button)
			UISkin.compact_button(button)
			row.add_child(button)
			audio.ui_audio.bind_button(button)
			button.pressed.connect(_begin_capture.bind(action, slot))
			binding_buttons[action].append(button)
	_refresh_bindings()

func _refresh_bindings() -> void:
	for action in binding_buttons:
		for slot in range(2):
			var button: Button = binding_buttons[action][slot]
			button.text = InputBindings.key_name(InputBindings.bindings[action][slot])
			button.tooltip_text = button.text

func _build_controller() -> void:
	_heading(4, "手柄")
	_option(4, "按钮布局", 100, ["自动", "Xbox", "PlayStation", "Switch"], ControllerInput.LAYOUTS.find(ControllerInput.layout), func(index: int): ControllerInput.set_layout(ControllerInput.LAYOUTS[index]), "ControllerLayout")
	var closest := 0
	for index in range(CONTROLLER_DEADZONES.size()):
		if absf(CONTROLLER_DEADZONES[index] - ControllerInput.deadzone) < absf(CONTROLLER_DEADZONES[closest] - ControllerInput.deadzone): closest = index
	_option(4, "摇杆死区", 126, ["10%", "15%", "24%", "30%", "40%", "50%"], closest, func(index: int): ControllerInput.set_deadzone(CONTROLLER_DEADZONES[index]), "ControllerDeadzone")
	var scroll := ScrollContainer.new()
	scroll.name = "ControllerBindingsScroll"
	scroll.position = Vector2(168, 156)
	scroll.size = Vector2(354, 94)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	add_child(scroll)
	page_controls[4].append(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 332
	scroll.add_child(list)
	controller_values.clear()
	var entries := ["move_up", "interact", "bag", "pause", "map", "journal", "guide", "run", "dialogue_next", "history"]
	entries.append_array(["ui_accept", "ui_cancel", "pointer", "pointer_accept", "pointer_secondary", "pad_split", "pad_transfer"])
	var names := {"ui_accept": "界面确认", "ui_cancel": "界面返回", "pointer": "光标", "pointer_accept": "主操作", "pointer_secondary": "次操作", "pad_split": "拆分物品", "pad_transfer": "快速转移"}
	for action in entries:
		var row := HBoxContainer.new()
		list.add_child(row)
		var caption := Label.new()
		caption.text = "移动" if action == "move_up" else InputBindings.LABELS[InputBindings.ACTIONS.find(action)] if action in InputBindings.ACTIONS else names[action]
		caption.custom_minimum_size.x = 142
		caption.add_theme_color_override("font_color", UISkin.INK)
		UIFont.apply_control(caption)
		row.add_child(caption)
		var value := Label.new()
		value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		value.add_theme_color_override("font_color", UISkin.MUTED_INK)
		UIFont.apply_control(value)
		row.add_child(value)
		controller_values[action] = value
	_refresh_controller_bindings()

func _refresh_controller_bindings() -> void:
	for action in controller_values: controller_values[action].text = ControllerInput.button_text(action)
	var layout_option := get_node_or_null("ControllerLayout") as OptionButton
	if layout_option != null: layout_option.select(ControllerInput.LAYOUTS.find(ControllerInput.layout))

func is_capturing() -> bool:
	return InputBindings.capture_active and InputBindings.capture_owner != null and InputBindings.capture_owner.get_ref() == self

func _begin_capture(action: String, slot: int) -> void:
	capture_overlay = ColorRect.new()
	capture_overlay.name = "KeyCaptureOverlay"
	capture_overlay.position = -position
	capture_overlay.size = Vector2(640, 360)
	capture_overlay.color = Color(0.12, 0.08, 0.15, 0.8)
	capture_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(capture_overlay)
	var popup := Panel.new()
	popup.position = Vector2(154, 108)
	popup.size = Vector2(332, 144)
	popup.add_theme_stylebox_override("panel", UISkin.panel_style())
	capture_overlay.add_child(popup)
	capture_title = Label.new()
	capture_title.position = Vector2(16, 10)
	capture_title.size = Vector2(300, 32)
	capture_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_title.add_theme_color_override("font_color", UISkin.INK)
	UIFont.apply_control(capture_title, 24)
	popup.add_child(capture_title)
	capture_message = Label.new()
	capture_message.position = Vector2(18, 48)
	capture_message.size = Vector2(296, 48)
	capture_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capture_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	capture_message.add_theme_color_override("font_color", UISkin.MUTED_INK)
	UIFont.apply_control(capture_message)
	popup.add_child(capture_message)
	swap_button = _capture_button("交换按键", Vector2(16, 106), popup, InputBindings.confirm_swap)
	retry_button = _capture_button("重新选择", Vector2(118, 106), popup, InputBindings.retry_capture)
	clear_button = _capture_button("清除", Vector2(16, 106), popup, InputBindings.clear_alternate)
	cancel_button = _capture_button("取消", Vector2(220, 106), popup, InputBindings.cancel_capture)
	InputBindings.begin_capture(self, action, slot)
	audio.play_event("ui_open")

func _capture_button(text: String, pos: Vector2, parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(96, 24)
	UIFont.apply_control(button)
	UISkin.compact_button(button)
	parent.add_child(button)
	audio.ui_audio.bind_button(button)
	button.pressed.connect(callback)
	return button

func _refresh_capture() -> void:
	if not is_capturing() or not is_instance_valid(capture_overlay): return
	var conflict: bool = not InputBindings.conflict_action.is_empty()
	capture_title.text = tr("按键冲突" if conflict else "绑定按键")
	if conflict:
		capture_message.text = tr("%s 已用于「%s」") % [InputBindings.key_name(InputBindings.pending_key), InputBindings.action_name(InputBindings.conflict_action)]
	elif not InputBindings.capture_error.is_empty():
		capture_message.text = tr(InputBindings.capture_error)
	else:
		capture_message.text = "%s · %s" % [InputBindings.action_name(InputBindings.capture_action), tr("主按键" if InputBindings.capture_slot == 0 else "备用按键")]
	swap_button.visible = conflict
	retry_button.visible = conflict
	clear_button.visible = not conflict and InputBindings.capture_slot == 1
	if conflict: swap_button.grab_focus.call_deferred()
	else: cancel_button.grab_focus.call_deferred()

func _finish_capture(applied: bool) -> void:
	if not is_instance_valid(capture_overlay): return
	capture_overlay.hide()
	capture_overlay.queue_free()
	_refresh_bindings()
	var action: String = InputBindings.capture_action
	if action in binding_buttons: binding_buttons[action][InputBindings.capture_slot].grab_focus.call_deferred()
	audio.play_event("ui_confirm" if applied else "ui_close")

func select_page(index: int, sound: bool = true) -> void:
	selected_page = index
	for page in range(PAGE_NAMES.size()):
		tabs[page].set_pressed_no_signal(page == index)
		for control in page_controls[page]: control.visible = page == index
	reset_button.disabled = false
	if sound: audio.play_event("ui_page")

func has_open_popup() -> bool:
	for control in page_controls[selected_page]:
		if control is OptionButton and control.get_popup().visible:
			return true
	return false

func _reset_page() -> void:
	match selected_page:
		0:
			audio.reset_audio()
		1:
			for pair in [["fullscreen", false], ["window_size", WINDOW_SIZES[0]], ["vsync", true], ["frame_limit", 60], ["brightness", 0.0]]:
				Preferences.set_value("display", pair[0], pair[1])
			Preferences.apply_display()
		2:
			Preferences.set_value("game", "dialogue_speed", 30.0)
			Preferences.set_value("game", "auto_run", false)
			Preferences.set_value("game", "show_hotbar", true)
			Preferences.set_value("game", "text_jump", true)
			Preferences.set_value("game", "text_sway", true)
		3:
			var result: Dictionary = InputBindings.reset_defaults()
			audio.play_event("ui_confirm" if result.ok else "ui_error")
			return
		4:
			ControllerInput.set_layout("auto")
			ControllerInput.set_deadzone(0.24)
		_:
			return
	for control in page_controls[selected_page]:
		remove_child(control)
		control.queue_free()
	page_controls[selected_page].clear()
	match selected_page:
		0: _build_audio()
		1: _build_display()
		2: _build_game()
		4: _build_controller()
	select_page(selected_page, false)
	reset_button.grab_focus()
	audio.play_event("ui_confirm")

func _exit_tree() -> void:
	if is_capturing():
		# The owner/audio may be leaving the tree; cancel without rebuilding its UI.
		InputBindings.capture_finished.disconnect(_finish_capture)
		InputBindings.cancel_capture()
