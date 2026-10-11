extends SceneTree
## All disk operations use a process-specific directory and preference file.
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://output/save_deletion/"
var failures := 0
var menu
var capture := false

func _initialize() -> void:
	capture = "--delete-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("SAVE DELETE TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed:
		failures += 1

func frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame

func click(control: Control) -> void:
	var position: Vector2 = menu.container.position + control.get_global_rect().get_center() * menu.container.scale
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

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func shot(name: String) -> void:
	if not capture:
		return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = menu.viewport.get_texture().get_image()
	pixels.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	check("screenshot " + name, pixels.save_png(OUT + name + ".png") == OK)

func write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)
	file.close()

func fingerprint(slot: int) -> Dictionary:
	var result := {}
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = Saves.slot_path(slot) + suffix
		if FileAccess.file_exists(path):
			result[suffix] = FileAccess.get_file_as_bytes(path)
	return result

func make_slot(slot: int) -> void:
	check("create fixture " + str(slot), Saves.begin_slot(slot).ok)
	var snapshot: Dictionary = Saves.pending.duplicate(true)
	snapshot.state.day = 3
	snapshot.state.coins = 83
	snapshot.state.campaign.player_name = "小女巫"
	check("create backup " + str(slot), Saves.write_slot(slot, snapshot).ok)
	Saves.end_session()

func run() -> void:
	Saves.directory = "user://save_delete_verification_%d" % OS.get_process_id()
	Preferences.file_path = "user://save_delete_verification_%d.cfg" % OS.get_process_id()
	check("isolated paths", Saves.directory != "user://saves" and Preferences.file_path != "user://preferences.cfg")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Saves.directory))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	make_slot(1)
	make_slot(2)
	write_file(Saves.slot_path(1) + ".tmp", "unfinished write")
	var other := fingerprint(2)
	write_file(Saves.directory.path_join("unrelated.txt"), "keep")
	check("delete rejects invalid slots", not Saves.delete_slot(0).ok and not Saves.delete_slot(7).ok)
	check("delete complete slot", Saves.delete_slot(1).ok and fingerprint(1).is_empty())
	check("deleted slot cannot recover a backup", Saves.read_slot(1).ok and Saves.read_slot(1).empty)
	check("deleting an empty slot is harmless", Saves.delete_slot(1).ok)
	check("other files unchanged", fingerprint(2) == other and FileAccess.get_file_as_string(Saves.directory.path_join("unrelated.txt")) == "keep")
	check("begin protected slot", Saves.begin_slot(2).ok)
	var pending_before: Dictionary = Saves.pending.duplicate(true)
	var busy := Saves.delete_slot(2)
	check("active progress protected", not busy.ok and busy.code == "busy" and fingerprint(2) == other and Saves.pending == pending_before and Saves.active_slot == 2)
	Saves.end_session()
	make_slot(1)
	write_file(Saves.slot_path(1) + ".tmp", "unfinished write")
	write_file(Saves.slot_path(3), "corrupt primary")
	write_file(Saves.slot_path(3) + ".bak", "corrupt backup")
	make_slot(4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(4)))
	write_file(Saves.slot_path(5), JSON.stringify({"game": Saves.GAME_ID, "version": 999}))
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(6)
	await create_timer(0.3).timeout
	await click(menu.buttons[0])
	await create_timer(0.25).timeout
	check("occupied unreadable and backup slots can be deleted", menu.modal == "slots" and menu.slot_delete_buttons.size() == 5 and not menu.slot_delete_buttons.has(6))
	check("save card layout preserved", menu.slot_buttons[0].position == Vector2(22, 68) and menu.slot_buttons[5].position == Vector2(280, 204))
	check("delete buttons do not cover details", menu.slot_delete_buttons.keys().all(func(slot): return not menu.slot_delete_buttons[slot].get_global_rect().intersects(menu.slot_buttons[slot - 1].get_node("SlotDetail").get_global_rect())))
	await shot("save_slots_delete")
	var original := fingerprint(1)
	await click(menu.slot_delete_buttons[1])
	check("delete click does not start the game", is_instance_valid(menu.delete_dialog) and not menu.transitioning and Saves.active_slot == 0)
	check("confirmation identifies named slot", menu.delete_dialog.get_node("SaveTitle").text == "存档 01 · 小女巫")
	check("cancel focused by default", menu.viewport.gui_get_focus_owner().name == "CancelDelete")
	check("background is disabled", menu.slot_buttons.all(func(button): return button.disabled) and menu.slot_delete_buttons.values().all(func(button): return button.disabled) and menu.dialog.get_node("Back").disabled)
	await shot("delete_confirmation")
	await click(menu.slot_buttons[1])
	menu._select_slot(2)
	check("confirmation blocks background slot selection", Saves.active_slot == 0 and is_instance_valid(menu.delete_dialog))
	await key(KEY_ENTER)
	check("default confirmation cancels without changing disk", not is_instance_valid(menu.delete_dialog) and fingerprint(1) == original and menu.modal == "slots")
	check("cancel restores deletion focus", menu.viewport.gui_get_focus_owner() == menu.slot_delete_buttons[1])
	await click(menu.slot_delete_buttons[1])
	await key(KEY_ESCAPE)
	check("escape closes only confirmation", menu.modal == "slots" and not is_instance_valid(menu.delete_dialog) and fingerprint(1) == original)
	menu.slot_buttons[0].grab_focus()
	await key(KEY_D)
	check("directional navigation reaches delete", menu.viewport.gui_get_focus_owner() == menu.slot_delete_buttons[1])
	await key(KEY_ENTER)
	await key(KEY_TAB)
	check("tab reaches confirm", menu.viewport.gui_get_focus_owner().name == "ConfirmDelete")
	await key(KEY_TAB)
	check("confirmation focus stays within dialog", menu.viewport.gui_get_focus_owner().name == "CancelDelete")
	await click(menu.delete_dialog.get_node("CancelDelete"))
	await click(menu.slot_delete_buttons[1])
	await click(menu.delete_dialog.get_node("ConfirmDelete"))
	check("confirmed deletion removes primary backup and temporary", fingerprint(1).is_empty() and Saves.read_slot(1).empty)
	check("deleted card refreshes in place", menu.modal == "slots" and menu.slot_buttons[0].get_node("SlotDetail").text == "— 空存档 —" and not menu.slot_delete_buttons.has(1) and menu.viewport.gui_get_focus_owner() == menu.slot_buttons[0])
	check("successful deletion leaves status empty", menu.slot_status.text.is_empty())
	check("neighbor progress survives UI deletion", fingerprint(2) == other)
	await shot("deleted_slot")
	check("deleted slot can start a fresh game", Saves.begin_slot(1).ok and Saves.pending.state.day == 1 and Saves.pending.state.coins == 0 and Saves.pending.state.campaign.player_name == preload("res://Scenes/Campaign/campaign_state.gd").DEFAULT_PLAYER_NAME)
	Saves.end_session()
	menu._refresh_slot(1)
	menu._wire_slot_focus()
	var blocked := Saves.slot_path(2) + ".tmp"
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked))
	await click(menu.slot_delete_buttons[2])
	await click(menu.delete_dialog.get_node("ConfirmDelete"))
	check("failed delete reports error without losing slot", menu.slot_status.text == "无法删除存档文件。" and fingerprint(2) == other and menu.slot_delete_buttons.has(2) and not is_instance_valid(menu.delete_dialog))
	check("directory collision is never removed", DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(blocked)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked))
	await click(menu.slot_delete_buttons[2])
	await click(menu.delete_dialog.get_node("ConfirmDelete"))
	check("delete can be retried without a stale status", Saves.read_slot(2).empty and not menu.slot_delete_buttons.has(2) and menu.slot_status.text.is_empty())
	for slot in [3, 4, 5]:
		await click(menu.slot_delete_buttons[slot])
		await click(menu.delete_dialog.get_node("ConfirmDelete"))
		check("delete damaged backup-only or incompatible slot " + str(slot), Saves.read_slot(slot).empty and fingerprint(slot).is_empty() and not menu.slot_delete_buttons.has(slot))
	for locale in ["en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		menu._refresh_slot(1)
		await click(menu.slot_delete_buttons[1])
		check("localized confirmation " + locale, TranslationServer.translate("删除") != "删除" and menu.delete_dialog.get_node("SaveTitle").text.begins_with(TranslationServer.translate("存档 %02d") % 1))
		for button_name in ["CancelDelete", "ConfirmDelete"]:
			var button: Button = menu.delete_dialog.get_node(button_name)
			var width := button.get_theme_font("font").get_string_size(button.tr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			check("localized button fits " + locale + " " + button_name, width < button.size.x - 8)
		await shot("delete_confirmation_" + locale)
		await click(menu.delete_dialog.get_node("CancelDelete"))
	root.get_node("Localization").set_language("zh_CN", false)
	await click(menu.dialog.get_node("Back"))
	check("back still returns to menu", menu.modal.is_empty() and menu.viewport.gui_get_focus_owner() == menu.buttons[0])
	menu.audio.stop()
	menu.queue_free()
	await frames(4)
	Saves.end_session()
	for slot in range(1, Saves.SLOT_COUNT + 1):
		Saves.delete_slot(slot)
	for path in [Saves.directory.path_join("unrelated.txt"), Preferences.file_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	print("SAVE DELETE VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
