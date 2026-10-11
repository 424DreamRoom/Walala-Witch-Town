extends SceneTree
## Uses isolated preferences and saves; never touches a player's progress.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Catalog = preload("res://Localization/catalog.gd")
const I18n = preload("res://Localization/localized_text.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const OUT := "res://Localization/Verification/"
var failures := 0
var capture := false
var menu
var lane
var loop
var hud
var service

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("LOCALIZATION TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func shot(name: String, viewport: SubViewport) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels := viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + name, pixels.save_png(OUT + name + ".png") == OK)

func click(control: Control, container: SubViewportContainer) -> void:
	var position := container.position + control.get_global_rect().get_center() * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func popup_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func action_key(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode if event.physical_keycode != 0 else event.keycode
	return KEY_NONE

func check_buttons(parent: Node, context: String) -> void:
	var forbidden := RegEx.new()
	forbidden.compile("\\b(WASD|Enter|Esc|Shift)\\b|点击|點擊|左键|右键")
	for child in parent.get_children():
		if child is Control and child.is_visible_in_tree() and not str(child.name).begins_with("Bind_"):
			var copy: String = child.tr(child.tooltip_text)
			if child is Label or child is Button or child is RichTextLabel: copy += " " + child.tr(child.text)
			check(context + " no operation instructions " + child.name, forbidden.search(copy) == null)
		if child is Label and child.is_visible_in_tree() and child.autowrap_mode == TextServer.AUTOWRAP_OFF and not child.clip_text and not child.text.is_empty():
			var width: float = child.get_theme_font("font").get_multiline_string_size(child.tr(child.text), HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
			check(context + " label fits " + child.name, width <= child.size.x + 1)
			if parent is Control and parent.size.x > 0:
				check(context + " label stays inside " + child.name, child.position.x + child.size.x <= parent.size.x + 1)
		if child is Button and child.is_visible_in_tree() and not child.text.is_empty():
			var text: String = child.tr(child.text)
			if child.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED: text = child.text
			var width: float = child.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
			var padding: float = child.get_theme_stylebox("normal").get_minimum_size().x
			if child is OptionButton: padding += 14
			check(context + " fits " + child.name, width + padding <= child.size.x + 1)
		check_buttons(child, context)

func run() -> void:
	service = root.get_node("Localization")
	Preferences.file_path = "user://localization_%d.cfg" % OS.get_process_id()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preferences="): Preferences.file_path = argument.trim_prefix("--preferences=")
	if "--write-preference" in OS.get_cmdline_user_args():
		Preferences.set_value("audio", "music_volume", 0.41)
		service.set_language("ja")
		check("restart write", Preferences.read().get_value("game", "language") == "ja")
		print("LOCALIZATION VERIFY END failures=", failures)
		quit(failures)
		return
	if "--read-preference" in OS.get_cmdline_user_args():
		menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
		root.add_child(menu)
		await frames(5)
		check("restart restores Japanese", service.language == "ja" and root.title == "わらら魔女の町")
		check("restart preserves audio", is_equal_approx(menu.audio.music_volume, 0.41))
		menu.audio.stop()
		menu.queue_free()
		await create_timer(0.15).timeout
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
		print("LOCALIZATION VERIFY END failures=", failures)
		quit(failures)
		return
	Saves.directory = "user://localization_saves_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	service.apply_saved_language()
	check("default simplified Chinese", service.language == "zh_CN")
	# Validate the actual shipped font against every translated character.
	var missing := {}
	for row in Catalog.ROWS:
		for text in row:
			for character in text:
				if character not in ["\n", "\r", "\t"] and not UIFont.get_font().has_char(character.unicode_at(0)):
					missing[character] = true
	print("MISSING GLYPHS ", missing.keys())
	check("font covers all four languages", missing.is_empty())
	for index in range(service.LOCALES.size()):
		service.set_language(service.LOCALES[index])
		var translated := true
		for row in Catalog.ROWS:
			translated = translated and String(TranslationServer.translate(row[0])) == row[index]
		check("complete runtime catalog " + service.language, translated)
	service.set_language("zh_CN")
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(5)
	menu._open_settings()
	menu.dialog.select_page(2)
	var language: OptionButton = menu.dialog.get_node("Language")
	check("four native language names", language.item_count == 4 and range(4).all(func(index): return language.get_item_text(index) == service.LANGUAGE_NAMES[index]))
	if capture:
		await click(language, menu.container)
		check("language dropdown opens", language.get_popup().visible)
		await shot("language_dropdown", menu.viewport)
		await popup_key(action_key("ui_down"))
		await popup_key(action_key("ui_down"))
		await popup_key(KEY_ENTER)
		check("real popup selects English", service.language == "en")
	Preferences.set_value("audio", "music_volume", 0.41)
	for index in range(4):
		language.select(index)
		language.item_selected.emit(index)
		await frames()
		check("selector applies and saves " + service.LOCALES[index], service.language == service.LOCALES[index] and Preferences.read().get_value("game", "language") == service.LOCALES[index])
		check_buttons(menu.dialog, service.language + " settings")
		await shot(service.language + "_settings", menu.viewport)
		for page in [0, 1, 3]:
			menu.dialog.select_page(page)
			await frames()
			check_buttons(menu.dialog, service.language + " page" + str(page))
		menu.dialog.select_page(2)
	check("language keeps other preferences", is_equal_approx(Preferences.read().get_value("audio", "music_volume"), 0.41))
	menu.dialog._reset_page()
	await frames()
	check("game reset preserves language", service.language == "zh_TW" and Preferences.value("game", "language", "") == "zh_TW")
	menu._close_dialog()
	for locale in service.LOCALES:
		service.set_language(locale)
		await frames()
		check_buttons(menu.canvas, locale + " title")
		var title: Label = menu.canvas.get_node("GameTitle")
		var title_width := UIFont.get_font().get_string_size(String(TranslationServer.translate(title.text)), HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
		check(locale + " game title fits", title_width <= title.size.x)
		await shot(locale + "_title", menu.viewport)
		menu._start_game()
		check_buttons(menu.dialog, locale + " slots")
		await shot(locale + "_slots_empty", menu.viewport)
		menu._close_dialog()
		menu._open_credits()
		check(locale + " keeps credit attributions", "TakWolf" in menu.credits_text.text and "Kenney" in menu.credits_text.text and "Godot" in menu.credits_text.text)
		menu._close_dialog()
	service.set_language("en")
	menu.audio.stop()
	menu.queue_free()
	await create_timer(0.15).timeout
	check("new slot starts", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	hud = loop.hud
	loop.state.day = 2
	loop.state.coins = 128
	loop.state.raw = [2, 1, 1]
	loop.state.resources.wood = 3
	loop.state.journal.gather = 3
	loop.state.set_message("采得%s ×%d", ["蘑菇", 1])
	loop._refresh()
	check("scene handoff keeps English", service.language == "en" and hud.date_label.text == "D2 · Tue")
	check("dynamic ingredient notice", loop.state.get_message_text() == "Gathered Mushroom ×1")
	check("progress can be saved in English", loop.save_progress().ok)
	var saved: Dictionary = Saves.read_slot(1).data.state
	loop.save_menu.show_menu()
	loop.save_menu.manual_save()
	loop.save_menu.show_settings()
	loop.audio.panel.select_page(2)
	var before: Dictionary = loop.state.to_save_data().duplicate(true)
	var position: Vector2 = lane.player.position
	var clock: float = loop.state.remaining
	for locale in service.LOCALES:
		service.set_language(locale)
		await frames()
		check(locale + " paused settings uses native names", loop.audio.panel.get_node("Language").selected == service.LOCALES.find(locale))
		check(locale + " switching preserves state", loop.state.to_save_data() == before and lane.player.position == position and loop.state.remaining == clock and paused)
		check(locale + " pause menu omits decorative labels and construction", loop.save_menu.panel.find_children("*", "Label", false, false).size() == 1 and not loop.save_menu.panel.has_node("BuildFurniture"))
		check(locale + " saved notice updates", loop.save_menu.status.text == I18n.format("已保存到存档 %02d", [1]))
		check_buttons(loop.audio.panel, locale + " paused settings")
		await shot(locale + "_paused_settings", lane.viewport)
	loop.save_menu.close_settings()
	await shot("zh_TW_pause", lane.viewport)
	loop.save_menu.close_menu()
	for locale in service.LOCALES:
		service.set_language(locale)
		await frames()
		check(locale + " clock fits", UIFont.get_font().get_string_size(hud.period_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= hud.period_label.size.x)
		hud.open_bag()
		var used: int = loop.state.bag_slots.filter(func(slot): return not slot.is_empty()).size()
		check(locale + " bag count", hud.bag_info.text == I18n.format("背包 · %d / %d 格", [used, loop.state.bag_capacity()]))
		service.set_language("ja" if locale == "en" else "en")
		check(locale + " open bag refreshes immediately", hud.bag_info.text == I18n.format("背包 · %d / %d 格", [used, loop.state.bag_capacity()]) and paused)
		service.set_language(locale)
		check_buttons(hud.modal, locale + " bag")
		await shot(locale + "_bag", lane.viewport)
		hud.close_modal()
		hud.open_journal()
		service.set_language("ja" if locale == "en" else "en")
		var objective: String = hud.Journal.QUESTS[hud.selected_quest].objective
		check(locale + " open journal refreshes immediately", String(TranslationServer.translate(objective)) in hud.quest_list.get_child(0).get_child(1).text and paused)
		service.set_language(locale)
		await frames()
		check_buttons(hud.modal, locale + " journal")
		await shot(locale + "_journal", lane.viewport)
		hud.close_modal()
		Preferences.set_value("game", "dialogue_speed", 0.0)
		hud.open_guide()
		await frames()
		check(locale + " dialogue reveals translated length", hud.dialogue_text.text == String(TranslationServer.translate(hud.lines[0])) and hud.dialogue_text.visible_characters == hud.dialogue_text.get_total_character_count() and hud.choices_root.visible)
		check(locale + " dialogue history translated", hud.dialogue_text.text in hud.history_label.text)
		service.set_language("ja" if locale == "en" else "en")
		check(locale + " open dialogue refreshes immediately", hud.dialogue_text.text == String(TranslationServer.translate(hud.lines[0])) and hud.dialogue_text.visible_characters == hud.dialogue_text.get_total_character_count() and hud.dialogue_text.text in hud.history_label.text and hud.choices_root.visible and paused)
		service.set_language(locale)
		check_buttons(hud.modal, locale + " dialogue")
		await shot(locale + "_dialogue", lane.viewport)
		hud.close_modal()
		for business in ["blacksmith", "store"]:
			loop.enter(business)
			lane.player.position = loop.area.stations.service
			loop.area.interact()
			await frames()
			check(locale + " " + business + " panel opens", loop.area.service_panel.visible)
			check_buttons(loop.area.service_panel, locale + " " + business)
			await shot(locale + "_" + business, lane.viewport)
			loop.area.service_panel.hide()
		loop.enter("dock")
		await shot(locale + "_dock", lane.viewport)
		loop.enter("field")
		await shot(locale + "_field", lane.viewport)
		loop.enter("town")
		loop.enter("restaurant")
		loop._refresh()
		check(locale + " dish and price localized", loop.menu_buttons[0].text == I18n.format("%s  %d金", [State.DISHES[0], 12]))
		await shot(locale + "_restaurant", lane.viewport)
		loop.enter("town")
	# A previously written Chinese-source save has the same resource/task IDs.
	var restored := State.new()
	check("save compatible across languages", restored.restore_save_data(saved) and restored.raw == [2, 1, 1] and restored.journal.gather == 3 and restored.resources.wood == 3 and restored.coins == 128)
	check("save format independent of locale", not saved.has("language") and saved.message == "采得蘑菇 ×1")
	service.set_language("en")
	loop.save_menu.report_save({"ok": false, "error": "写入失败，请检查磁盘空间和权限。"})
	check("save failure retains source text in state", loop.state.message == "写入失败，请检查磁盘空间和权限。" and loop.state.get_message_text() == "Write failed. Check free disk space and permissions.")
	service.set_language("ja")
	check("save failure refreshes in another language", loop.state.get_message_text() == String(TranslationServer.translate(loop.state.message)))
	service.set_language("en")
	loop.state.end_phase()
	loop.state.end_phase()
	loop._refresh()
	check("settlement uses localized numbers", "Day 2 Results" in loop.summary.text and "Total: 128" in loop.summary.text)
	await shot("en_settlement", lane.viewport)
	service.set_language("unknown")
	check("unknown language falls back safely", service.language == "zh_CN" and String(TranslationServer.translate("开始游戏")) == "开始游戏")
	loop.save_menu.show_menu()
	loop.save_menu.close_menu()
	lane.queue_free()
	await create_timer(0.15).timeout
	Saves.end_session()
	service.set_language("en")
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	await frames(5)
	menu._start_game()
	check("saved slot summary translated", "Day 2" in menu.slot_buttons[0].get_child(1).text)
	await shot("en_slots_saved", menu.viewport)
	menu.audio.stop()
	menu.queue_free()
	await create_timer(0.15).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	print("LOCALIZATION VERIFY END failures=", failures)
	quit(failures)
