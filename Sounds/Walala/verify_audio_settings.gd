extends SceneTree
## Channel isolation, legacy preferences, real slider input and localized captures.
const Voice = preload("res://Sounds/Walala/fmod_voice.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/audio_settings/"
var failures := 0
var checks := 0
var menu
var capture := false

func _initialize() -> void:
	capture = "--audio-settings-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("AUDIO SETTINGS ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func gain(player: Voice, volume: float, offset: float) -> bool:
	return absf(player.volume_db - (linear_to_db(volume) + offset)) < 0.01 and (not player.playing or absf(player.channel.get_volume() - db_to_linear(player.volume_db)) < 0.00001)

func wait_for(seconds: float = 0.1) -> void:
	await create_timer(seconds).timeout

func slider_input(slider: HSlider, ratio: float) -> void:
	var rect := slider.get_global_rect()
	var position: Vector2 = menu.container.position + (rect.position + Vector2(6 + (rect.size.x - 12) * ratio, rect.size.y / 2)) * menu.container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = "res://output/audio_settings_%d.cfg" % OS.get_process_id()
	Saves.directory = "res://output/audio_settings_%d_saves" % OS.get_process_id()
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "music_volume", 0.47)
	legacy.set_value("audio", "effects_volume", 0.61)
	legacy.save(Preferences.file_path)
	var audio = load("res://Sounds/Walala/audio_manager.gd").new()
	root.add_child(audio)
	check("old preferences inherit all three effects", is_equal_approx(audio.master_volume, 1.0) and is_equal_approx(audio.music_volume, 0.47) and is_equal_approx(audio.character_volume, 0.61) and is_equal_approx(audio.environment_volume, 0.61) and is_equal_approx(audio.ui_volume, 0.61))
	audio.set_context("day", "town", "rain")
	await wait_for(0.9)
	audio.set_master_volume(0.5)
	audio.set_music_volume(0.4)
	audio.set_character_volume(0.6)
	audio.set_environment_volume(0.8)
	audio.set_ui_volume(0.3)
	audio.play_event("chop")
	audio.update_footsteps(1.5, false, "wood")
	check("master multiplies music", gain(audio.music[audio.active], 0.2, -6.0))
	check("master multiplies weather", gain(audio.ambient, 0.4, -12.0))
	check("master multiplies actions", audio.effects[0].playing and gain(audio.effects[0], 0.3, -6.0))
	check("master multiplies footsteps", audio.footstep_voices[0].playing and gain(audio.footstep_voices[0], 0.3, -10.0))
	check("master multiplies UI", is_equal_approx(audio.ui_audio.volume, 0.15))
	audio.set_environment_volume(0.0)
	check("weather zero leaves other channels playing", audio.ambient.stream_paused and not audio.music[audio.active].stream_paused and audio.effects[0].playing and is_equal_approx(audio.ui_audio.volume, 0.15))
	audio.set_environment_volume(0.8)
	audio.set_character_volume(0.0)
	check("character zero stops actions and steps", audio.effects.all(func(p): return not p.playing) and audio.footstep_voices.all(func(p): return not p.playing))
	audio.play_event("gather")
	audio.reset_footsteps()
	audio.update_footsteps(1.5, false, "wood")
	check("character zero prevents new action and step voices", audio.effects.all(func(p): return not p.playing) and audio.footstep_voices.all(func(p): return not p.playing))
	audio.ui_audio.last_play.clear()
	audio.play_event("ui")
	check("legacy UI cue ignores character zero", audio.ui_audio.voices.any(func(p): return p.playing) and not audio.ambient.stream_paused)
	audio.set_character_volume(0.6)
	check("character restore does not replay stale effects", audio.effects.all(func(p): return not p.playing) and audio.footstep_voices.all(func(p): return not p.playing))
	audio.set_ui_volume(0.0)
	check("UI zero leaves music and weather", audio.ui_audio.voices.all(func(p): return not p.playing) and not audio.music[audio.active].stream_paused and not audio.ambient.stream_paused)
	audio.play_event("gather")
	check("UI zero leaves character actions", audio.effects.any(func(p): return p.playing))
	audio.set_ui_volume(0.3)
	audio.set_master_volume(0.0)
	check("master zero silences every channel", audio.music[audio.active].stream_paused and audio.ambient.stream_paused and audio.effects.all(func(p): return not p.playing) and audio.footstep_voices.all(func(p): return not p.playing) and is_zero_approx(audio.ui_audio.volume))
	audio.set_master_volume(0.5)
	check("master restore retains channel values", is_equal_approx(audio.music_volume, 0.4) and is_equal_approx(audio.character_volume, 0.6) and is_equal_approx(audio.environment_volume, 0.8) and is_equal_approx(audio.ui_volume, 0.3) and not audio.music[audio.active].stream_paused and not audio.ambient.stream_paused)
	audio.set_context("night", "town", "snow")
	await wait_for()
	check("phase change still crossfades", audio.music.all(func(p): return p.playing))
	audio.set_master_volume(0.25)
	await wait_for(0.9)
	check("master adjustment survives active music fade", gain(audio.music[audio.active], 0.1, -6.0) and not audio.music[1-audio.active].playing)
	audio.set_context("day", "town", "rain")
	await wait_for()
	audio.set_character_volume(0.3)
	check("character adjustment preserves music fade", audio.music.all(func(p): return p.playing))
	await wait_for(0.9)
	paused = true
	audio.set_master_volume(0.8)
	audio.ui_audio.last_play.clear()
	audio.play_event("ui_confirm")
	check("paused settings update UI gain", audio.ui_audio.can_process() and is_equal_approx(audio.ui_audio.volume, 0.24) and audio.ui_audio.voices.any(func(p): return p.playing))
	paused = false
	audio.queue_free()
	await process_frame
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._open_settings()
	await wait_for()
	var panel = menu.dialog
	check("menu inherits five saved channels", is_equal_approx(panel.master_slider.value, 0.8) and is_equal_approx(panel.music_slider.value, 0.4) and is_equal_approx(panel.character_slider.value, 0.3) and is_equal_approx(panel.environment_slider.value, 0.8) and is_equal_approx(panel.ui_slider.value, 0.3))
	for slider in [panel.master_slider, panel.music_slider, panel.character_slider, panel.environment_slider, panel.ui_slider]:
		await slider_input(slider, 0.65)
		check("real mouse adjusts " + slider.name, slider.value > 0.55 and slider.value < 0.75)
		check("numeric value follows " + slider.name, panel.get_node(slider.name + "Value").text == str(roundi(slider.value * 100)))
	panel.ui_slider.grab_focus()
	var before: float = panel.ui_slider.value
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_D
		event.physical_keycode = KEY_D
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	check("existing keyboard navigation adjusts slider", panel.ui_slider.value > before)
	Preferences.set_value("game", "auto_run", true)
	panel._reset_page()
	check("reset restores all five defaults", is_equal_approx(menu.audio.master_volume, 1.0) and is_equal_approx(menu.audio.music_volume, 0.22) and is_equal_approx(menu.audio.character_volume, 0.35) and is_equal_approx(menu.audio.environment_volume, 0.35) and is_equal_approx(menu.audio.ui_volume, 0.35))
	check("audio reset preserves unrelated preferences", Preferences.value("game", "auto_run", false))
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		root.get_node("Localization").set_language(locale, false)
		await wait_for()
		for control in panel.page_controls[0]:
			if control is Label:
				var translated := TranslationServer.translate(control.text)
				check("label fits " + locale + " " + control.name, control.get_theme_font("font").get_string_size(translated, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x <= control.size.x)
		if capture:
			RenderingServer.force_draw(false)
			var pixels: Image = menu.viewport.get_texture().get_image()
			pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
			check("capture " + locale, pixels.save_png(OUT + locale + ".png") == OK)
	menu.queue_free()
	await process_frame
	# An old mute has no hidden effect on the new independent sliders.
	legacy.set_value("audio", "music_muted", true)
	legacy.set_value("audio", "effects_muted", true)
	legacy.save(Preferences.file_path)
	var restored = load("res://Scenes/MainMenu/menu_audio.gd").new()
	root.add_child(restored)
	restored.set_character_volume(0.5)
	check("legacy mute clears only the adjusted channel", not restored.effects_muted and is_equal_approx(restored.character_volume, 0.5) and is_zero_approx(restored.environment_volume) and is_zero_approx(restored.ui_volume))
	restored.set_music_volume(0.4)
	check("legacy music mute clears on slider change", not restored.music_muted and not restored.music.stream_paused)
	restored.queue_free()
	await process_frame
	await wait_for(0.15)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("AUDIO SETTINGS VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
