extends SceneTree
## Native rendering and dialogue timing checks with isolated settings and saves.
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const Motion = preload("res://Scenes/UI/rich_text_motion.gd")
const OUT := "res://Scenes/UI/Verification/"
const PORTRAIT := "res://Art/Character/Storybook/WalalaWitch/walala-witch.png"
var lane
var loop
var hud
var service
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--rich-text-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("RICH TEXT TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for index in range(count): await process_frame

func shot(title: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + title, pixels.save_png(OUT + title + ".png") == OK)

func click(control: Control) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var position: Vector2 = container.position + control.get_global_rect().get_center() * container.scale
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

func motion_pixels() -> Image:
	RenderingServer.force_draw(false)
	return lane.viewport.get_texture().get_image().get_region(Rect2i(116, 207, 502, 119))

func check_motion() -> void:
	var jump := Motion.new("jump")
	var sway := Motion.new("sway")
	var fx := CharFXTransform.new()
	fx.elapsed_time = 0.25
	fx.offset = Vector2.ZERO
	jump._process_custom_fx(fx)
	check("jump displaces glyphs upward on pixel boundaries", fx.offset.y < 0 and fx.offset.y >= -2 and fx.offset == fx.offset.round())
	Preferences.set_value("game", "text_jump", false)
	fx.offset = Vector2(5, 7)
	jump._process_custom_fx(fx)
	check("disabled jump preserves the underlying glyph transform", fx.offset == Vector2(5, 7))
	fx.offset = Vector2.ZERO
	sway._process_custom_fx(fx)
	check("sway remains horizontal and independent of jump preference", fx.offset.x != 0 and fx.offset == fx.offset.round() and fx.offset.abs().x <= 2 and fx.offset.y == 0)
	fx.env = {"strength": 2, "speed": 1}
	var horizontal_offsets: Array[float] = []
	var baseline_preserved := true
	for elapsed in [0.0, 0.25, 0.5, 0.75, 1.0]:
		fx.elapsed_time = elapsed
		fx.offset = Vector2(5, 7)
		sway._process_custom_fx(fx)
		horizontal_offsets.append(fx.offset.x - 5)
		baseline_preserved = baseline_preserved and fx.offset.y == 7
	check("sway travels right and left and returns after one cycle", horizontal_offsets == [0.0, 2.0, 0.0, -2.0, 0.0])
	check("sway preserves the existing vertical baseline", baseline_preserved)
	fx.env = {}
	fx.elapsed_time = 0.25
	Preferences.set_value("game", "text_sway", false)
	fx.offset = Vector2(5, 7)
	sway._process_custom_fx(fx)
	check("disabled sway preserves the underlying glyph transform", fx.offset == Vector2(5, 7))
	Preferences.set_value("game", "text_jump", true)
	fx.offset = Vector2.ZERO
	jump._process_custom_fx(fx)
	check("jump remains independent of sway preference", fx.offset.y < 0)
	Preferences.set_value("game", "text_sway", true)
	fx.env = {"height": 999, "strength": 999, "speed": 999}
	fx.offset = Vector2.ZERO
	jump._process_custom_fx(fx)
	check("jump parameters stay within readable bounds", fx.offset.y >= -4 and fx.offset.y <= 0)
	fx.offset = Vector2.ZERO
	sway._process_custom_fx(fx)
	check("sway parameters stay within horizontal bounds", fx.offset.abs().x <= 3 and fx.offset.y == 0)
	fx.env = {"height": "invalid", "strength": "invalid", "speed": "invalid"}
	fx.offset = Vector2.ZERO
	jump._process_custom_fx(fx)
	sway._process_custom_fx(fx)
	check("invalid parameters use finite defaults", fx.offset.is_finite())
	var markup := "[jump height=2 speed=1.8][color=#247f78]跳动的文字[/color][/jump] · [sway strength=2 speed=1.2][color=#b14945]摇曳的文字[/color][/sway] · 普通文字"
	var plain := "跳动的文字 · 摇曳的文字 · 普通文字"
	hud.start_dialogue("Walala", PORTRAIT, [markup])
	check("motion tags nest with colors and preserve parsed length", hud.dialogue_text.get_parsed_text() == plain and hud.dialogue_text.get_total_character_count() == plain.length())
	hud._process(0.1)
	var visible_count: int = hud.dialogue_text.visible_characters
	Preferences.set_value("game", "text_jump", false)
	Preferences.set_value("game", "text_sway", false)
	check("motion toggles preserve typewriter and history markup", hud.dialogue_text.visible_characters == visible_count and hud.dialogue_text.text == markup and hud.history_label.text.ends_with(markup))
	Preferences.set_value("game", "text_jump", true)
	Preferences.set_value("game", "text_sway", true)
	hud.advance_dialogue()
	if capture:
		var samples: Array[PackedByteArray] = []
		var saved := true
		for index in range(24):
			await create_timer(0.08, true).timeout
			var pixels := motion_pixels()
			samples.append(pixels.get_data())
			pixels.resize(1004, 238, Image.INTERPOLATE_NEAREST)
			saved = pixels.save_png(OUT + "text_motion_%02d.png" % index) == OK and saved
		check("capture motion frames", saved)
		check("native text animates while gameplay is paused", paused and samples.any(func(sample): return sample != samples[0]))
		await shot("text_motion_demo")
		Preferences.set_value("game", "text_jump", false)
		Preferences.set_value("game", "text_sway", false)
		await frames()
		var still := motion_pixels().get_data()
		await create_timer(0.3, true).timeout
		check("both disabled effects produce identical rendered frames", still == motion_pixels().get_data())
		Preferences.set_value("game", "text_jump", true)
		await frames()
		var jump_frame := motion_pixels().get_data()
		await create_timer(0.25, true).timeout
		check("jump resumes on the existing label", jump_frame != motion_pixels().get_data())
		Preferences.set_value("game", "text_jump", false)
		Preferences.set_value("game", "text_sway", true)
		await frames()
		var sway_frame := motion_pixels().get_data()
		await create_timer(0.25, true).timeout
		check("sway resumes on the existing label", sway_frame != motion_pixels().get_data())
	Preferences.set_value("game", "text_jump", true)
	Preferences.set_value("game", "text_sway", true)
	hud.close_modal()

func check_motion_settings() -> void:
	loop.save_menu.show_menu()
	await click(loop.save_menu.panel.get_node("Settings"))
	await click(loop.audio.panel.get_node("GameTab"))
	var panel: Control = loop.audio.panel
	var jump_toggle: CheckButton = panel.get_node("TextJump")
	var sway_toggle: CheckButton = panel.get_node("TextSway")
	check("ingame settings expose two enabled motion toggles", jump_toggle.button_pressed and sway_toggle.button_pressed and paused)
	for locale in service.LOCALES:
		service.set_language(locale, false)
		await frames()
		var rows: Array[Control] = []
		for node_name in ["Language", "DialogueSpeed", "AutoRun", "ShowHotbar", "TextJump", "TextSway"]:
			rows.append(panel.get_node(node_name))
		var fits := true
		for index in range(rows.size()):
			fits = fits and Rect2(148, 68, 392, 192).encloses(rows[index].get_rect())
			if index > 0: fits = fits and not rows[index - 1].get_rect().intersects(rows[index].get_rect())
		check(locale + " six game settings fit without overlap", fits)
		await shot("text_motion_settings_" + locale)
	await click(jump_toggle)
	await click(sway_toggle)
	check("ingame toggles persist independently to disk", not Preferences.read().get_value("game", "text_jump", true) and not Preferences.read().get_value("game", "text_sway", true))
	await click(panel.get_node("CloseAudioSettings"))
	await click(loop.save_menu.panel.get_node("Settings"))
	await click(panel.get_node("GameTab"))
	check("motion settings retain values when reopened", not panel.get_node("TextJump").button_pressed and not panel.get_node("TextSway").button_pressed)
	var locale: String = service.language
	var music: float = loop.audio.music_volume
	await click(panel.get_node("ResetPage"))
	check("game defaults restore both motion effects without changing language or sound", Preferences.text_jump_enabled() and Preferences.text_sway_enabled() and panel.get_node("TextJump").button_pressed and panel.get_node("TextSway").button_pressed and service.language == locale and loop.audio.music_volume == music)
	await click(panel.get_node("CloseAudioSettings"))
	loop.save_menu.close_menu()
	service.set_language("zh_CN", false)

func run() -> void:
	var suffix := str(OS.get_process_id())
	Saves.directory = "user://rich_text_verification_" + suffix
	Preferences.file_path = "user://rich_text_verification_" + suffix + ".cfg"
	service = root.get_node("Localization")
	service.set_language("zh_CN", false)
	Preferences.set_value("game", "dialogue_speed", 30.0)
	Saves.begin_slot(1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(5)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	hud = loop.hud
	# Drive exact elapsed times instead of depending on rendering frame rate.
	hud.set_process(false)
	var before: Dictionary = loop.state.to_save_data().duplicate(true)
	var position: Vector2 = lane.player.position
	var markup := "[color=#247f78][b]Hello[/b][/color] [i]town[/i] [u]friend[/u] [s]old[/s] [font_size=18]A[/font_size] [lb]b[rb]"
	var plain := "Hello town friend old A [b]"
	hud.start_dialogue("Walala", PORTRAIT, [markup], [{"text": "OK", "action": hud.close_modal}])
	check("native BBCode parses nested styles and literal brackets", hud.dialogue_text.bbcode_enabled and hud.dialogue_text.get_parsed_text() == plain)
	check("only rendered characters count toward timing", hud.dialogue_text.get_total_character_count() == plain.length())
	check("body preserves input ownership", hud.dialogue_text.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud.dialogue_text.focus_mode == Control.FOCUS_NONE and not hud.dialogue_text.scroll_active)
	check("bold and italic retain pixel font with real variants", hud.dialogue_text.get_theme_font("bold_font") is FontVariation and hud.dialogue_text.get_theme_font("bold_font").variation_embolden > 0 and hud.dialogue_text.get_theme_font("italics_font").variation_transform != Transform2D.IDENTITY)
	check("style sizes match the base canvas", hud.dialogue_text.get_theme_font_size("bold_font_size") == 12 and hud.dialogue_text.get_theme_font_size("italics_font_size") == 12)
	hud._process(4.1 / 30.0)
	check("typewriter reveals letters without spending time on tags", hud.dialogue_text.visible_characters == 4 and not hud.choices_root.visible)
	hud._process((plain.length() - 4.0) / 30.0)
	check("choices appear at the rendered duration", hud.dialogue_text.visible_characters == plain.length() and hud.choices_root.visible)
	check("history keeps identical formatting", hud.history_label.bbcode_enabled and hud.history_label.text.ends_with(markup) and hud.history_label.get_parsed_text().ends_with(plain))
	await shot("rich_styles")
	await frames()
	check("reading preserves gameplay and pause", paused and loop.state.to_save_data() == before and lane.player.position == position)
	hud.close_modal()
	check("closing restores gameplay pause", not paused)
	await check_motion()
	hud.start_dialogue("Walala", PORTRAIT, ["[b]First[/b]", "[color=#247f78][/color]", "[i]Last[/i]"])
	hud.advance_dialogue()
	check("manual reveal uses parsed length", hud.dialogue_text.visible_characters == 5)
	hud.advance_dialogue()
	check("tag-only middle line has zero visible characters", hud.line_index == 1 and hud.dialogue_text.get_total_character_count() == 0)
	hud.advance_dialogue()
	check("multi-line dialogue advances past tag-only text", hud.line_index == 2 and hud.dialogue_text.visible_characters == 0)
	hud.advance_dialogue()
	hud.advance_dialogue()
	check("last styled line closes normally", hud.mode.is_empty() and not paused)
	hud.start_dialogue("Walala", PORTRAIT, ["[b][/b]"], [{"text": "OK", "action": hud.close_modal}])
	check("tag-only final line presents choices immediately", hud.choices_root.visible)
	hud.close_modal()
	Preferences.set_value("game", "dialogue_speed", 0.0)
	hud.start_dialogue("Walala", PORTRAIT, ["[b]Now[/b]"], [{"text": "OK", "action": hud.close_modal}])
	hud._process(0.0)
	check("instant speed reveals styled text and choices", hud.dialogue_text.visible_characters == 3 and hud.choices_root.visible)
	hud.dialogue_text.visible_characters = -1
	service.set_language("en", false)
	check("native all-visible sentinel stays complete on language switch", hud.dialogue_text.visible_characters == 3 and hud.choices_root.visible)
	hud.close_modal()
	Preferences.set_value("game", "dialogue_speed", 30.0)
	for locale in service.LOCALES:
		service.set_language(locale, false)
		hud.open_guide()
		check(locale + " guide translates before parsing", hud.dialogue_text.text == String(TranslationServer.translate(hud.lines[0])) and "[color=" not in hud.dialogue_text.get_parsed_text())
		hud._process(0.1)
		service.set_language("ja" if locale == "en" else "en", false)
		check(locale + " partial language switch restarts rendered text", hud.dialogue_text.visible_characters == 0 and not hud.choices_root.visible and hud.history_label.text.ends_with(hud.dialogue_text.text))
		hud.advance_dialogue()
		service.set_language(locale, false)
		check(locale + " completed language switch preserves completion", hud.dialogue_text.visible_characters == hud.dialogue_text.get_total_character_count() and hud.choices_root.visible and paused)
		await frames()
		check(locale + " guide fits its existing panel", hud.dialogue_text.get_content_height() <= hud.dialogue_text.size.y)
		await shot("rich_" + locale + "_dialogue")
		if locale == "zh_CN":
			hud.toggle_history()
			await shot("rich_history")
		hud.close_modal()
		hud.open_journal()
		await frames()
		var main: Label = loop.campaign_controller.list.get_node("MainQuest").get_child(0)
		var main_name: String = loop.state.Campaign.current_main(loop.state).name
		check(locale + " active main is localized", main.text.contains(String(TranslationServer.translate(main_name))))
		await shot("rich_" + locale + "_journal")
		service.set_language("ja" if locale == "en" else "en", false)
		main = loop.campaign_controller.list.get_node("MainQuest").get_child(0)
		check(locale + " open journal updates translation", main.text.contains(String(TranslationServer.translate(main_name))))
		hud.close_modal()
	service.set_language("zh_CN", false)
	await check_motion_settings()
	loop.enter("blacksmith")
	lane.player.position = loop.area.stations.service
	hud.open_equipment_upgrades(loop.area)
	check("equipment effect description accepts rich text", hud.modal.get_node("EquipmentUpgrades").detail.get_node("EquipmentDescription") is RichTextLabel)
	hud.close_modal()
	Saves.end_session()
	lane.queue_free()
	await frames(6)
	# Allow the audio thread to release the playbacks stopped during teardown.
	await create_timer(0.1).timeout
	for extension in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.slot_path(1) + extension))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("RICH TEXT VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
