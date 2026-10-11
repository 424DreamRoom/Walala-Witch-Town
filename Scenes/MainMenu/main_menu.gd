extends Node
## The project entry point. All UI is authored on the native pixel canvas.
const GAME_SCENE := "res://Scenes/LanternLane/lantern_lane.tscn"
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Audio = preload("res://Scenes/MainMenu/menu_audio.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const I18n = preload("res://Localization/localized_text.gd")
const INK := Color("572f3c")
const CREAM := Color("fff0cf")
var viewport: SubViewport
var container: SubViewportContainer
var canvas: Control
var audio
var buttons: Array[Button] = []
var overlay: ColorRect
var dialog: Panel
var modal := ""
var last_focus: Control
var transitioning := false
var music_slider: HSlider
var fullscreen_toggle: CheckButton
var credits_text: RichTextLabel
var slot_buttons: Array[Button] = []
var slot_status: Label
var slot_delete_buttons: Dictionary = {}
var delete_overlay: ColorRect
var delete_dialog: Panel
var delete_slot_number := 0
var delete_return_focus: Control
var motion

func _ready() -> void:
	Localization.apply_saved_language()
	InputBindings.apply_saved_bindings()
	# Keep existing command-line capture/regression entry points usable from F5.
	for argument in OS.get_cmdline_user_args():
		if argument in ["--lane-test", "--lane-capture", "--witch-capture", "--no-loop"]:
			get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
			return
	Saves.end_session()
	container = SubViewportContainer.new()
	container.name = "PixelCanvas"
	container.size = Vector2(640, 360)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	Preferences.attach_brightness(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.disable_3d = true
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(viewport)
	viewport.add_child(preload("res://Scenes/MainMenu/menu_backdrop.gd").new())
	canvas = Control.new()
	canvas.name = "MenuUI"
	canvas.size = Vector2(640, 360)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(canvas)
	audio = Audio.new()
	add_child(audio)
	_build_menu()
	get_viewport().size_changed.connect(_fit_canvas)
	_fit_canvas()
	Preferences.apply_display()
	buttons[0].grab_focus.call_deferred()

func _fit_canvas() -> void:
	var available := get_viewport().get_visible_rect().size
	var factor := minf(available.x / 640.0, available.y / 360.0)
	if factor >= 1.0:
		factor = floorf(factor)
	container.scale = Vector2.ONE * maxf(factor, 0.1)
	container.position = ((available - Vector2(640, 360) * factor) / 2.0).floor()

func _label(text: String, rect: Rect2, parent: Node, font_size: int = 12, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFont.apply_control(label, font_size)
	label.add_theme_color_override("font_color", UISkin.INK if parent == dialog and color == CREAM else color)
	parent.add_child(label)
	return label

func _button(text: String, rect: Rect2, parent: Node, action: Callable, cue: String = "ui_click") -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	UIFont.apply_control(button)
	audio.ui_audio.bind_button(button)
	button.pressed.connect(func():
		if not cue.is_empty(): audio.play_event(cue)
		action.call())
	parent.add_child(button)
	return button

func _build_menu() -> void:
	var subtitle := _label("—  WALALA WITCH TOWN  —", Rect2(120, 30, 400, 18), canvas, 12, Color("e6b29b"))
	var title := _label("哗啦啦魔女镇", Rect2(40, 57, 560, 66), canvas, 48)
	title.name = "GameTitle"
	title.add_theme_color_override("font_outline_color", Color("612f43"))
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_color_override("font_shadow_color", Color("bd7968"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	var names := ["StartGame", "Settings", "Credits", "QuitGame"]
	var labels := ["开始游戏", "设置", "鸣谢", "退出游戏"]
	var actions := [_start_game, _open_settings, _open_credits, _open_quit]
	for i in range(4):
		var button := _button(labels[i], Rect2(248, 180 + i * 32, 144, 24), canvas, actions[i], "")
		button.name = names[i]
		buttons.append(button)
	for i in range(buttons.size()):
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		buttons[i].focus_next = buttons[i].focus_neighbor_bottom
		buttons[i].focus_previous = buttons[i].focus_neighbor_top
	motion = preload("res://Scenes/MainMenu/menu_motion.gd").new()
	motion.name = "MenuMotion"
	canvas.add_child(motion)
	motion.setup(title, subtitle, buttons)

func _make_dialog(kind: String, title: String, rect: Rect2) -> void:
	last_focus = viewport.gui_get_focus_owner()
	modal = kind
	audio.play_event("ui_open")
	for button in buttons:
		button.disabled = true
	overlay = ColorRect.new()
	overlay.name = "ModalOverlay"
	overlay.size = Vector2(640, 360)
	overlay.color = Color(0.13, 0.09, 0.16, 0.83)
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	dialog = Panel.new()
	dialog.name = kind.capitalize() + "Dialog"
	dialog.position = rect.position
	dialog.size = rect.size
	dialog.add_theme_stylebox_override("panel", UISkin.panel_style())
	overlay.add_child(dialog)
	_label(title, Rect2(12, 12, rect.size.x - 24, 30), dialog, 24)
	_reveal_dialog.call_deferred(overlay)

func _reveal_dialog(shade: ColorRect) -> void:
	# Settings replaces the placeholder panel before this deferred entrance runs.
	if not is_instance_valid(shade) or shade != overlay or shade.is_queued_for_deletion():
		return
	var panel := dialog
	var destination := panel.position
	panel.position.y += 6.0
	var tween := shade.create_tween().set_parallel(true)
	tween.tween_property(shade, "modulate:a", 1.0, 0.16)
	tween.tween_method(func(progress: float):
		panel.position = destination + Vector2(0, roundf(6.0 * (1.0 - progress))),
		0.0, 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _open_settings() -> void:
	_make_dialog("settings", "", Rect2(40, 24, 560, 312))
	var placeholder := dialog
	overlay.remove_child(placeholder)
	placeholder.queue_free()
	var settings := preload("res://Scenes/UI/settings_panel.gd").new()
	settings.name = "SettingsDialog"
	settings.position = Vector2(40, 24)
	settings.audio = audio
	settings.close_requested.connect(_close_dialog)
	settings.credits_requested.connect(func(): _close_dialog(); _open_credits())
	overlay.add_child(settings)
	dialog = settings
	music_slider = settings.music_slider
	fullscreen_toggle = settings.fullscreen_toggle
	settings.tabs[0].grab_focus()

func _open_credits() -> void:
	_make_dialog("credits", "鸣谢", Rect2(80, 24, 480, 312))
	credits_text = RichTextLabel.new()
	credits_text.name = "CreditsText"
	credits_text.position = Vector2(22, 53)
	credits_text.size = Vector2(436, 202)
	credits_text.focus_mode = Control.FOCUS_ALL
	UIFont.apply_rich_text(credits_text)
	credits_text.add_theme_color_override("default_color", UISkin.INK)
	credits_text.text = I18n.credits()
	dialog.add_child(credits_text)
	var back := _button("返回", Rect2(180, 268, 120, 30), dialog, _close_dialog, "")
	back.name = "Back"
	back.grab_focus()

func _open_quit() -> void:
	_make_dialog("quit", "退出游戏？", Rect2(160, 104, 320, 152))
	_label("下次再来小镇坐坐吧。", Rect2(16, 52, 288, 20), dialog)
	var back := _button("再待一会", Rect2(24, 96, 124, 30), dialog, _close_dialog, "")
	back.name = "CancelQuit"
	var confirm := _button("退出游戏", Rect2(172, 96, 124, 30), dialog, _quit_game, "")
	confirm.name = "ConfirmQuit"
	back.focus_neighbor_right = back.get_path_to(confirm)
	confirm.focus_neighbor_left = confirm.get_path_to(back)
	back.grab_focus()

func _close_dialog() -> void:
	if modal.is_empty() or transitioning:
		return
	if is_instance_valid(delete_overlay):
		_close_delete_dialog()
		return
	audio.play_event("ui_close")
	overlay.hide()
	overlay.queue_free()
	modal = ""
	for button in buttons:
		button.disabled = false
	if is_instance_valid(last_focus):
		last_focus.grab_focus()
	else:
		buttons[0].grab_focus()

func _input(event: InputEvent) -> void:
	if InputBindings.capture_active: return
	if is_instance_valid(motion):
		motion.handle_input(event)
	if event.is_action_pressed("ui_cancel") and not modal.is_empty():
		if modal == "settings" and dialog.has_open_popup():
			return
		_close_dialog()
		get_viewport().set_input_as_handled()

func _start_game() -> void:
	if transitioning:
		return
	_make_dialog("slots", "选择存档", Rect2(44, 14, 552, 332))
	slot_buttons.clear()
	slot_delete_buttons.clear()
	for index in range(Saves.SLOT_COUNT):
		var slot := index + 1
		var card := _button("", Rect2(22 + (index % 2) * 258, 68 + (index / 2) * 68, 250, 62), dialog, _select_slot.bind(slot), "")
		card.name = "Slot%02d" % slot
		_label("", Rect2(10, 4, 230, 17), card, 12, CREAM).name = "SlotTitle"
		_label("", Rect2(10, 22, 230, 16), card, 12, CREAM).name = "SlotDetail"
		_label("", Rect2(10, 39, 230, 16), card, 12, Color("f5d7ad")).name = "SlotFooter"
		card.get_node("SlotTitle").clip_text = true
		card.get_node("SlotFooter").clip_text = true
		slot_buttons.append(card)
		_refresh_slot(slot)
	var back := _button("返回", Rect2(216, 278, 120, 30), dialog, _close_dialog, "")
	back.name = "Back"
	slot_status = _label("", Rect2(16, 311, 520, 16), dialog, 12, UISkin.MUTED_INK)
	_wire_slot_focus()
	slot_buttons[0].grab_focus()

func _slot_title(slot: int, info: Dictionary) -> String:
	if info.ok and not info.empty and not info.data.state.campaign.player_name.is_empty():
		return tr("存档 %02d · %s") % [slot, info.data.state.campaign.player_name]
	return tr("存档 %02d") % slot

func _refresh_slot(slot: int) -> void:
	var info := Saves.read_slot(slot)
	var card := slot_buttons[slot - 1]
	var occupied: bool = not info.ok or not info.empty
	var title: Label = card.get_node("SlotTitle")
	title.text = _slot_title(slot, info)
	title.size.x = 178 if occupied else 230
	var detail := "— 空存档 —"
	var footer := ""
	if not info.ok:
		detail = "无法读取存档"
		footer = info.error
	elif not info.empty:
		var data: Dictionary = info.data
		detail = I18n.format("第 %d 天 · %s · %d 金", [data.state.day, {"day": "白天", "night": "营业", "result": "结算"}[data.state.phase], data.state.coins])
		footer = "%s · %s" % [tr(Saves.LOCATION_NAMES[data.world.location]), data.saved_at_text.substr(5, 11)]
		if info.recovered:
			footer = "已找到可恢复的备份"
	card.get_node("SlotDetail").text = detail
	card.get_node("SlotFooter").text = footer
	if occupied and not slot_delete_buttons.has(slot):
		# A sibling button consumes its own mouse input without starting the slot.
		var remove := _button("删除", Rect2(card.position + Vector2(194, 4), Vector2(48, 18)), dialog, _open_delete_slot.bind(slot), "")
		remove.name = "DeleteSlot%02d" % slot
		UISkin.compact_button(remove)
		remove.size = Vector2(48, 18)
		remove.add_theme_color_override("font_color", Color("ffd0bf"))
		slot_delete_buttons[slot] = remove
	elif not occupied and slot_delete_buttons.has(slot):
		var remove: Button = slot_delete_buttons[slot]
		remove.hide()
		remove.queue_free()
		slot_delete_buttons.erase(slot)

func _wire_slot_focus() -> void:
	var order: Array[Control] = []
	for index in range(slot_buttons.size()):
		var card := slot_buttons[index]
		card.focus_neighbor_top = card.get_path_to(slot_buttons[posmod(index - 2, Saves.SLOT_COUNT)])
		card.focus_neighbor_bottom = card.get_path_to(slot_buttons[(index + 2) % Saves.SLOT_COUNT])
		card.focus_neighbor_left = card.get_path_to(slot_buttons[index ^ 1])
		card.focus_neighbor_right = card.focus_neighbor_left
		order.append(card)
		if slot_delete_buttons.has(index + 1):
			var remove: Button = slot_delete_buttons[index + 1]
			card.focus_neighbor_right = card.get_path_to(remove)
			remove.focus_neighbor_left = remove.get_path_to(card)
			remove.focus_neighbor_right = remove.get_path_to(slot_buttons[index ^ 1])
			remove.focus_neighbor_top = remove.get_path_to(slot_buttons[posmod(index - 2, Saves.SLOT_COUNT)])
			remove.focus_neighbor_bottom = remove.get_path_to(slot_buttons[(index + 2) % Saves.SLOT_COUNT])
			order.append(remove)
	var back: Button = dialog.get_node("Back")
	back.focus_neighbor_top = back.get_path_to(slot_buttons[4])
	back.focus_neighbor_bottom = back.get_path_to(slot_buttons[0])
	order.append(back)
	for index in range(order.size()):
		order[index].focus_next = order[index].get_path_to(order[(index + 1) % order.size()])
		order[index].focus_previous = order[index].get_path_to(order[posmod(index - 1, order.size())])

func _set_slots_disabled(disabled: bool) -> void:
	for button in slot_buttons:
		button.disabled = disabled
	for button in slot_delete_buttons.values():
		button.disabled = disabled
	dialog.get_node("Back").disabled = disabled

func _open_delete_slot(slot: int) -> void:
	if transitioning or modal != "slots" or is_instance_valid(delete_overlay):
		return
	var info := Saves.read_slot(slot)
	if info.ok and info.empty:
		_refresh_slot(slot)
		_wire_slot_focus()
		slot_buttons[slot - 1].grab_focus()
		return
	delete_slot_number = slot
	delete_return_focus = viewport.gui_get_focus_owner()
	_set_slots_disabled(true)
	audio.play_event("ui_open")
	delete_overlay = ColorRect.new()
	delete_overlay.name = "DeleteOverlay"
	delete_overlay.size = Vector2(640, 360)
	delete_overlay.color = Color(0.13, 0.09, 0.16, 0.7)
	delete_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(delete_overlay)
	delete_dialog = Panel.new()
	delete_dialog.name = "DeleteSaveDialog"
	delete_dialog.position = Vector2(140, 100)
	delete_dialog.size = Vector2(360, 160)
	delete_dialog.add_theme_stylebox_override("panel", UISkin.panel_style())
	delete_overlay.add_child(delete_dialog)
	_label("删除存档？", Rect2(12, 12, 336, 30), delete_dialog, 24, UISkin.INK)
	var title := _label(_slot_title(slot, info), Rect2(16, 51, 328, 18), delete_dialog, 12, UISkin.INK)
	title.name = "SaveTitle"
	title.clip_text = true
	_label("删除后无法恢复。", Rect2(16, 76, 328, 18), delete_dialog, 12, UISkin.MUTED_INK)
	var cancel := _button("取消", Rect2(40, 114, 124, 30), delete_dialog, _close_delete_dialog, "")
	cancel.name = "CancelDelete"
	var confirm := _button("删除", Rect2(196, 114, 124, 30), delete_dialog, _confirm_delete_slot, "")
	confirm.name = "ConfirmDelete"
	for button in [cancel, confirm]:
		var other: Button = confirm if button == cancel else cancel
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
	# Clicking the modal backdrop keeps keyboard confirmation on the safe choice.
	for surface in [delete_overlay, delete_dialog]:
		surface.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				cancel.grab_focus())
	cancel.grab_focus()

func _close_delete_dialog() -> void:
	if not is_instance_valid(delete_overlay):
		return
	audio.play_event("ui_close")
	delete_overlay.hide()
	delete_overlay.queue_free()
	delete_overlay = null
	delete_dialog = null
	_set_slots_disabled(false)
	if is_instance_valid(delete_return_focus) and not delete_return_focus.disabled:
		delete_return_focus.grab_focus()
	else:
		slot_buttons[delete_slot_number - 1].grab_focus()
	delete_return_focus = null

func _confirm_delete_slot() -> void:
	if transitioning or not is_instance_valid(delete_overlay):
		return
	var slot := delete_slot_number
	var result := Saves.delete_slot(slot)
	_close_delete_dialog()
	if not result.ok:
		slot_status.text = result.error
		audio.play_event("ui_error")
		return
	_refresh_slot(slot)
	_wire_slot_focus()
	slot_buttons[slot - 1].grab_focus()
	slot_status.text = ""
	audio.play_event("ui_confirm")

func _select_slot(slot: int) -> void:
	if transitioning or is_instance_valid(delete_overlay):
		return
	var result := Saves.begin_slot(slot)
	if not result.ok:
		slot_status.text = result.error
		audio.play_event("ui_error")
		return
	audio.play_event("ui_confirm")
	_enter_game()

func _enter_game() -> void:
	if transitioning or SceneTransition.active: return
	preload("res://Scenes/Campaign/campaign_state.gd").pending_intro = not Saves.pending.get("state", {}).get("campaign", {}).get("introduced", false)
	transitioning = true
	for button in buttons:
		button.disabled = true
	_set_slots_disabled(true)
	var error := await SceneTransition.change_scene(GAME_SCENE)
	if error != OK:
		transitioning = false
		Saves.end_session()
		for button in buttons:
			button.disabled = false
		_set_slots_disabled(false)
		slot_status.text = tr("无法进入游戏：") + error_string(error)
		audio.play_event("ui_error")

func _quit_game() -> void:
	if transitioning:
		return
	transitioning = true
	audio.play_event("ui_confirm")
	await get_tree().create_timer(0.3).timeout
	audio.stop()
	# Give the audio server one mix cycle to release active playback resources.
	await get_tree().create_timer(0.05).timeout
	get_tree().quit()
