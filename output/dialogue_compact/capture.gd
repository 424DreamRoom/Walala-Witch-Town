extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/dialogue_compact/"
var lane
var loop
var geometry := {}

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	run.call_deferred()

func frames(count: int = 4) -> void:
	for i in range(count): await process_frame

func click(control: Control) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var point: Vector2 = container.position + control.get_global_rect().get_center() * container.scale
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func shot(filename: String) -> void:
	loop.hud.dialogue_text.visible_characters = -1
	loop.hud._line_complete()
	await frames()
	await RenderingServer.frame_post_draw
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	pixels.save_png(OUT + filename + ".png")
	var name_plate: Control = loop.hud.modal.get_node("DialogueLayout/DialogueNamePlate")
	var speaker: Label = name_plate.get_node("DialogueSpeaker")
	var entries := []
	for entry in loop.hud.choices_root.get_children():
		entries.append({"text": entry.text, "rect": str(entry.get_global_rect()), "minimum": str(entry.get_combined_minimum_size())})
	geometry[filename] = {"name": str(name_plate.get_global_rect()), "speaker_rect": str(speaker.get_global_rect()), "speaker_lines": speaker.get_line_count(), "speaker_minimum": str(speaker.get_combined_minimum_size()), "choices": str(loop.hud.choices_root.get_global_rect()), "entries": entries}
	print("DIALOGUE CAPTURE ", filename, " ", JSON.stringify(geometry[filename]))

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.enter("farm")
	lane.player.position = loop.HOME_EXIT_POSITION
	lane.camera.force_update_scroll()
	await frames()
	var service = root.get_node("Localization")
	for locale in ["zh_CN", "en", "ja", "zh_TW"]:
		service.set_language(locale, false)
		loop.state.campaign.chapter = 0
		loop.campaign_controller.show_guide()
		await shot(locale + "_three")
		await click(loop.hud.choices_root.get_child(0))
		var mouse_ok: bool = loop.hud.mode == "dialogue" and paused and loop.hud.lines == loop.campaign_controller.Guide.current_lines(loop.state)
		print("DIALOGUE MOUSE ", locale, " ", "PASS" if mouse_ok else "FAIL")
		if not mouse_ok: quit(1); return
		loop.hud.close_modal()
		loop.state.campaign.chapter = 12
		loop.campaign_controller.show_guide_topics()
		await shot(locale + "_four")
		await key(KEY_S)
		await key(KEY_ENTER)
		var keyboard_ok: bool = loop.hud.mode == "dialogue" and paused and loop.hud.lines == loop.campaign_controller.Guide.TOPICS[0].lines
		print("DIALOGUE KEYBOARD ", locale, " ", "PASS" if keyboard_ok else "FAIL")
		if not keyboard_ok: quit(1); return
		loop.hud.close_modal()
	var report := FileAccess.open(OUT + "geometry.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(geometry, "\t"))
	lane.queue_free()
	await frames()
	quit()
