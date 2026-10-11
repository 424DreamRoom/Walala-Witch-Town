extends SceneTree
const UIAudio = preload("res://Sounds/Walala/ui_audio.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
var failures := 0
var checks := 0
var menu
var lane
var loop

func _initialize() -> void:
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("UI AUDIO ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func wait_for(seconds: float = 0.12) -> void:
	await create_timer(seconds).timeout

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		# Update Input action state as real keys do, for focus navigation feedback.
		Input.parse_input_event(event)
		await process_frame
	await wait_for()

func click(control: Control, viewport: SubViewport) -> void:
	var container := viewport.get_parent() as SubViewportContainer
	var pos := container.position + control.get_global_rect().get_center() * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion, true)
	await wait_for()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await wait_for()

func count(audio, cue: String) -> int:
	return int(audio.counts.get(cue, 0))

func run() -> void:
	Preferences.file_path = "res://output/ui_audio_test_%d.cfg" % OS.get_process_id()
	Saves.directory = "res://output/ui_audio_test_%d_saves" % OS.get_process_id()
	Saves.end_session()
	print("UI AUDIO DRIVER ", AudioServer.get_driver_name())
	var player := UIAudio.new()
	root.add_child(player)
	for cue in UIAudio.SOUNDS:
		var stream: AudioStream = UIAudio.SOUNDS[cue][0]
		var one_shot: bool = stream.loop_mode == AudioStreamWAV.LOOP_DISABLED if stream is AudioStreamWAV else not stream.loop
		check("short one-shot " + cue, stream != null and one_shot and stream.get_length() > 0 and stream.get_length() < 2.0)
		print("UI AUDIO LENGTH ", cue, " ", stream.get_length())
		var playback = stream.instantiate_playback()
		playback.start()
		var energy := 0.0
		for sample in playback.mix_audio(1.0, 8192): energy += sample.length_squared()
		playback.stop()
		playback = null
		check("nonzero PCM " + cue, energy > 0.0001)
		player.play(cue)
		await wait_for(0.06)
		check("starts " + cue, count(player, cue) == 1)
		player.stop()
	player.stop()
	player.last_play.clear()
	player.counts.clear()
	player.play("ui_hover")
	for i in range(100): player.play("ui_hover")
	check("hover flood limited", count(player, "ui_hover") == 1)
	player.play("ui_slider")
	for i in range(100): player.play("ui_slider")
	check("slider flood limited", count(player, "ui_slider") == 1)
	for i in range(100): player.play("ui_page")
	check("voice count bounded", player.voices.size() == 4 and player.get_child_count() == 4)
	player.set_volume(0.35, true)
	check("mute stops current UI immediately", player.voices.all(func(v): return not v.playing))
	var snapshot: Dictionary = player.counts.duplicate()
	player.play("ui_confirm")
	check("muted cue is silent", player.counts == snapshot)
	player.set_volume(0.0, false)
	player.play("ui_error")
	check("zero volume is silent", player.counts == snapshot)
	player.queue_free()
	await process_frame
	menu = load("res://Scenes/MainMenu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await wait_for(0.2)
	var ui = menu.audio.ui_audio
	check("initial focus silent", count(ui, "ui_hover") == 0)
	await key(KEY_S)
	check("keyboard navigation sound", count(ui, "ui_hover") > 0)
	await key(KEY_ENTER)
	check("keyboard opens settings sound", menu.modal == "settings" and count(ui, "ui_open") == 1)
	var opened := count(ui, "ui_open")
	var slider_before := count(ui, "ui_slider")
	menu.dialog.ui_slider.value = 0.5
	check("slider sound and gain", count(ui, "ui_slider") > slider_before and is_equal_approx(ui.volume, 0.5))
	menu.dialog.ui_slider.value = 0.0
	check("zero slider stops UI", is_zero_approx(ui.volume) and ui.voices.all(func(v): return not v.playing))
	await wait_for()
	menu.dialog.ui_slider.value = 0.5
	check("restored slider plays feedback", not ui.muted and count(ui, "ui_slider") > slider_before + 1)
	await key(KEY_ESCAPE)
	check("keyboard closes settings sound", menu.modal.is_empty() and count(ui, "ui_close") == 1)
	await click(menu.buttons[2], menu.viewport)
	check("mouse opens credits once", menu.modal == "credits" and count(ui, "ui_open") == opened + 1)
	await click(menu.dialog.get_node("Back"), menu.viewport)
	await click(menu.buttons[0], menu.viewport)
	Saves.directory = "res://output/ui_audio_blocked_%d" % OS.get_process_id()
	var blocked := FileAccess.open(Saves.directory, FileAccess.WRITE)
	blocked.store_string("blocks save directory")
	blocked.close()
	var rejected := count(ui, "ui_error")
	menu._select_slot(1)
	check("failed slot plays error and stays", count(ui, "ui_error") == rejected + 1 and not menu.transitioning)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	Saves.directory = "res://output/ui_audio_test_%d_saves" % OS.get_process_id()
	await wait_for()
	menu._select_slot(1)
	# Audio checks enter the world directly; opening-film input has separate tests.
	preload("res://Scenes/Campaign/campaign_state.gd").pending_intro = false
	check("valid slot plays confirmation", count(ui, "ui_confirm") == 1)
	await wait_for(0.6)
	lane = current_scene
	loop = lane.get_node("GameLoop")
	lane.automation = true
	loop.paused_for_test = true
	ui = loop.audio.ui_audio
	check("settings survive scene handoff", is_equal_approx(ui.volume, 0.5) and not ui.muted)
	await key(KEY_J)
	check("journal keyboard sound during pause", paused and loop.hud.mode == "journal" and count(ui, "ui_book_open") == 1)
	check("UI players process during pause", ui.can_process() and ui.voices.all(func(v): return v.can_process()))
	var pages := count(ui, "ui_page")
	var book: Control = loop.hud.quest_list.get_parent()
	for child in book.get_children():
		if child is Button and child.text == "已完成":
			await click(child, lane.viewport)
			break
	check("journal tabs turn page once", count(ui, "ui_page") == pages + 1)
	await key(KEY_J)
	check("journal closes by keyboard", not paused and count(ui, "ui_book_close") == 1)
	await click(loop.hud.slot_counts[0].get_parent(), lane.viewport)
	check("mouse opens bag once", paused and loop.hud.mode == "bag" and count(ui, "ui_open") == 1)
	await key(KEY_ESCAPE)
	check("escape closes bag once", not paused and count(ui, "ui_close") == 1)
	await key(KEY_H)
	var previous := count(ui, "ui_page")
	await key(KEY_E)
	check("dialogue advance sounds", loop.hud.mode == "dialogue" and count(ui, "ui_page") == previous + 1)
	await key(KEY_L)
	check("dialogue history sounds", count(ui, "ui_page") == previous + 2)
	var idle_counts: Dictionary = ui.counts.duplicate()
	await wait_for(0.25)
	check("typewriter and refresh do not spam", ui.counts == idle_counts)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check("pause menu opens with UI feedback", loop.save_menu.open and paused and count(ui, "ui_open") == 3)
	var saved := count(ui, "ui_confirm")
	await click(loop.save_menu.panel.get_node("Save"), lane.viewport)
	check("manual save confirms while paused", count(ui, "ui_confirm") == saved + 1 and "已保存到存档" in loop.save_menu.status.text)
	var confirm_voice: AudioStreamPlayer = null
	for voice in ui.voices:
		if voice.playing and voice.stream == UIAudio.SOUNDS["ui_confirm"][0]:
			confirm_voice = voice
	var position := confirm_voice.get_playback_position() if confirm_voice != null else -1.0
	await wait_for(0.04)
	if AudioServer.get_driver_name() != "Dummy":
		check("native playback advances while paused", confirm_voice != null and confirm_voice.playing and confirm_voice.get_playback_position() > position)
	idle_counts = ui.counts.duplicate()
	loop.save_menu.report_save({"ok": true}, true)
	check("autosave has no UI sound", ui.counts == idle_counts)
	await wait_for()
	loop.save_menu.report_save({"ok": false, "error": "test failure"})
	check("save failure feedback", count(ui, "ui_error") == 1 and loop.save_menu.open and paused)
	await key(KEY_ESCAPE)
	check("pause resumes with close sound", not paused and not loop.save_menu.open)
	loop.enter("store")
	lane.player.position = loop.area.stations.service
	await wait_for()
	var before_open := count(ui, "ui_open")
	loop.area.interact()
	check("shop open cue", count(ui, "ui_open") == before_open + 1 and loop.area.service_panel.visible)
	loop.area.interact()
	check("shop close cue", not loop.area.service_panel.visible)
	loop.audio.set_effects_muted(true)
	idle_counts = ui.counts.duplicate()
	loop.hud.open_bag()
	check("gameplay UI honors mute", ui.counts == idle_counts and ui.voices.all(func(v): return not v.playing))
	loop.hud.close_modal()
	loop.audio.set_effects_muted(false)
	loop.audio.set_effects_volume(0.0)
	idle_counts = ui.counts.duplicate()
	loop.hud.open_journal()
	check("gameplay UI honors zero", ui.counts == idle_counts)
	loop.hud.close_modal()
	loop.audio.set_effects_volume(0.5)
	loop.audio.set_effects_muted(false)
	ui.last_play.clear()
	var legacy := count(ui, "ui_click")
	loop.audio.play_event("ui")
	check("legacy interaction uses UI channel", count(ui, "ui_click") == legacy + 1)
	ui.stop()
	for voice in loop.audio.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
	lane.queue_free()
	await wait_for(0.2)
	Saves.end_session()
	for slot in range(1, 7):
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = Saves.slot_path(slot) + suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("UI AUDIO VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
