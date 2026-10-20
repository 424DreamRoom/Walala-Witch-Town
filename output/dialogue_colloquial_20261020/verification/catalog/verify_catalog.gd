extends SceneTree
## Uses isolated preferences and saves; never touches a player's progress.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Catalog = preload("res://Localization/catalog.gd")
const I18n = preload("res://Localization/localized_text.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const OUT := "res://output/dialogue_colloquial_20261020/verification/catalog/"
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
	print("LOCALIZATION VERIFY END failures=", failures)
	quit(failures)
