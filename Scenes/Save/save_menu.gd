extends Node
## An always-processing overlay so pausing also freezes timers and movement.
const Saves = preload("res://Scenes/Save/save_store.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const I18n = preload("res://Localization/localized_text.gd")
var loop
var layer: CanvasLayer
var indicator_layer: CanvasLayer
var indicator
var overlay: ColorRect
var panel: Panel
var status: Label
var last_save_message := ""
var last_save_source := ""
var last_save_arguments: Array = []
var open := false
var leaving := false
var paused_before := false
var accept_quit_before := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	accept_quit_before = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	layer = CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	# The container must still forward GUI input while its world is paused.
	loop.lane.viewport.get_parent().process_mode = Node.PROCESS_MODE_ALWAYS
	loop.lane.viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	loop.lane.viewport.add_child(layer)
	indicator_layer = CanvasLayer.new()
	indicator_layer.name = "SavingIndicatorLayer"
	indicator_layer.layer = 90
	indicator_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	loop.lane.viewport.add_child(indicator_layer)
	indicator = preload("res://Scenes/Save/saving_indicator.gd").new()
	indicator.name = "SavingIndicator"
	indicator_layer.add_child(indicator)
	# Settings are accessible from Esc without a permanent bottom toolbar.
	loop.audio.panel.reparent(layer, false)
	loop.audio.panel.position = Vector2(40, 24)
	loop.audio.credits.reparent(layer, false)
	loop.audio.panel.close_requested.connect(close_settings)
	Localization.language_changed.connect(_refresh_language)
	InputBindings.bindings_changed.connect(func(): _refresh_language(Localization.language))

func _refresh_language(_locale: String) -> void:
	if not open: return
	status.text = I18n.format(last_save_source, last_save_arguments) if not last_save_source.is_empty() else ""
	status.visible = not status.text.is_empty()
	panel.size.y = 194 if status.visible else 152
	panel.position.y = (360 - panel.size.y) / 2

func _label(text: String, rect: Rect2, parent: Node, font_size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UISkin.INK)
	UIFont.apply_control(label, font_size)
	parent.add_child(label)
	return label

func _button(text: String, rect: Rect2, parent: Node, callback: Callable, cue: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	UIFont.apply_control(button)
	loop.audio.ui_audio.bind_button(button)
	button.pressed.connect(func():
		if leaving: return
		if not cue.is_empty(): loop.audio.play_event(cue)
		callback.call())
	parent.add_child(button)
	return button

func show_menu() -> void:
	if loop.campaign_controller != null and loop.campaign_controller.opening_active(): return
	if open or leaving:
		return
	if loop.hud != null and not loop.hud.mode.is_empty():
		loop.hud.close_modal()
	loop.harvest.cancel()
	loop.audio.reset_footsteps()
	paused_before = get_tree().paused
	get_tree().paused = true
	open = true
	loop.audio.play_event("ui_open")
	overlay = ColorRect.new()
	overlay.name = "SaveOverlay"
	overlay.size = Vector2(640, 360)
	overlay.color = Color(0.12, 0.08, 0.14, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	panel = Panel.new()
	panel.position = Vector2(192, 104)
	panel.size = Vector2(256, 152)
	panel.add_theme_stylebox_override("panel", UISkin.panel_style())
	overlay.add_child(panel)
	var resume := _button("继续游戏", Rect2(32, 18, 192, 26), panel, close_menu)
	resume.name = "Resume"
	var save := _button("保存进度", Rect2(32, 48, 192, 26), panel, manual_save)
	save.name = "Save"
	save.disabled = Saves.active_slot == 0
	var settings := _button("设置", Rect2(32, 78, 192, 26), panel, show_settings)
	settings.name = "Settings"
	var back := _button("保存并返回主菜单", Rect2(32, 108, 192, 26), panel, return_to_title)
	back.name = "SaveAndReturn"
	back.text = "返回主菜单" if Saves.active_slot == 0 else back.text
	status = _label("", Rect2(12, 140, 232, 42), panel)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_language(Localization.language)
	resume.grab_focus()

func close_menu() -> void:
	if not open or leaving:
		return
	loop.audio.play_event("ui_close")
	loop.audio.panel.hide()
	loop.audio.credits.hide()
	overlay.hide()
	overlay.queue_free()
	open = false
	get_tree().paused = paused_before

func show_settings() -> void:
	panel.hide()
	loop.audio.panel.show()
	layer.move_child(loop.audio.panel, -1)
	layer.move_child(loop.audio.credits, -1)
	loop.audio.play_event("ui_open")

func close_settings() -> void:
	loop.audio.panel.hide()
	loop.audio.credits.hide()
	panel.show()
	if loop.hud != null: loop.hud.refresh()
	panel.get_node("Settings").grab_focus()
	loop.audio.play_event("ui_close")

func report_save(result: Dictionary, automatic: bool = false) -> void:
	if not automatic:
		loop.audio.play_event("ui_confirm" if result.ok else "ui_error")
	last_save_source = ("自动保存完成" if automatic else "已保存到存档 %02d") if result.ok else result.error
	last_save_arguments = [Saves.active_slot] if result.ok and not automatic else []
	var text: String = I18n.format(last_save_source, last_save_arguments)
	last_save_message = text
	if open:
		_refresh_language(Localization.language)
	elif not result.ok:
		loop.state.message = last_save_source
		loop._show_feedback()

func manual_save() -> void:
	if leaving: return
	report_save(loop.save_progress())

func return_to_title() -> void:
	if leaving:
		return
	if Saves.active_slot > 0:
		var result: Dictionary = loop.save_progress()
		if not result.ok:
			report_save(result)
			return
	loop.audio.play_event("ui_confirm")
	leaving = true
	get_tree().paused = true
	await get_tree().create_timer(maxf(0.3, indicator.remaining_time())).timeout
	get_tree().paused = false
	var error := await SceneTransition.change_scene("res://Scenes/MainMenu/main_menu.tscn")
	if error != OK:
		leaving = false
		get_tree().paused = open or paused_before
		report_save({"ok": false, "error": "无法进入主菜单。"})

func _input(event: InputEvent) -> void:
	if loop.campaign_controller != null and loop.campaign_controller.opening_active(): return
	if InputBindings.capture_active: return
	if loop.builder != null and loop.builder.active(): return
	if event.is_action_pressed("ui_cancel") and not leaving:
		if open and loop.audio.panel.visible and loop.audio.panel.has_open_popup():
			return
		if open:
			if loop.audio.credits.visible:
				loop.audio.credits.hide()
				loop.audio.play_event("ui_close")
			elif loop.audio.panel.visible:
				close_settings()
			else:
				close_menu()
		elif loop.hud != null and not loop.hud.mode.is_empty():
			loop.hud.close_modal()
		elif loop.harvest.busy():
			# Preserve Esc as immediate cancellation during a harvest action.
			loop.harvest.cancel()
		elif loop.location in ["blacksmith", "store"] and loop.area.service_panel.visible:
			loop.area.service_panel.hide()
			loop.audio.play_event("ui_close")
		elif loop.audio.credits.visible:
			loop.audio.credits.hide()
			loop.audio.play_event("ui_close")
		elif loop.audio.panel.visible:
			loop.audio.panel.hide()
			loop.audio.play_event("ui_close")
		else:
			show_menu()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not leaving:
		if Saves.active_slot > 0:
			var result: Dictionary = loop.save_progress()
			if not result.ok:
				show_menu()
				report_save(result)
				return
		leaving = true
		get_tree().paused = true
		loop.audio.stop()
		await get_tree().create_timer(maxf(0.05, indicator.remaining_time())).timeout
		get_tree().quit()

func _exit_tree() -> void:
	if open:
		get_tree().paused = paused_before
	get_tree().auto_accept_quit = accept_quit_before
	if is_instance_valid(layer):
		layer.queue_free()
	if is_instance_valid(indicator_layer):
		indicator_layer.queue_free()
