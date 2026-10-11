extends SceneTree
var failures = 0
func _initialize(): run.call_deferred()
func check(title, ok):
	print("AUDIO TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1
func wait_for(seconds): await create_timer(seconds).timeout
func mouse_click(lane, position):
	var pos = lane.viewport.get_parent().position + position * lane.viewport.get_parent().scale
	var motion = InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion,true)
	await wait_for(0.05)
	for pressed in [true,false]:
		var e = InputEventMouseButton.new()
		e.position = pos
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		root.push_input(e,true)
		await wait_for(0.05)

func run():
	var lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await wait_for(0.2)
	lane.automation = true
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	var a = loop.audio
	print("DRIVER ", AudioServer.get_driver_name())
	for key in a.streams:
		var s = a.streams[key]
		check("decoded length " + key, s.get_length() > 0)
		var playback = s.instantiate_playback()
		playback.start(0)
		var data = playback.mix_audio(1.0, 2048)
		var energy = 0.0
		for frame in data: energy += frame.length_squared()
		check("decoded PCM nonzero " + key, energy > 0)
		playback.stop()
		playback = null
		s = null
		print("LENGTH ", key, " ", a.streams[key].get_length(), " ENERGY ", energy)
	await wait_for(1.0)
	check("day playing quiet gain", a.music[a.active].playing and a.music[a.active].volume_db < -18)
	var pos = a.music[a.active].get_playback_position()
	await wait_for(0.2)
	check("playback advances", a.music[a.active].get_playback_position() > pos)
	loop.enter("field")
	await wait_for(0.1)
	check("field same BGM no restart", a.current_music == "day_town" and a.music[a.active].get_playback_position() > pos)
	lane.weather.set_weather("rain")
	await wait_for(0.1)
	check("rain playing loop", a.current_ambient == "rain" and a.ambient.playing and a.ambient.stream.loop)
	lane.weather.set_weather("snow")
	await wait_for(0.1)
	check("snow calibrated wind", a.current_ambient == "wind" and a.ambient.playing and not a.ambient.stream_paused and absf(a.ambient.volume_db - (linear_to_db(a.channel_gain(a.environment_volume)) + 6.0)) < 0.1)
	lane.weather.clear_weather()
	await wait_for(0.1)
	check("clear stops ambience", not a.ambient.playing)
	lane.weather.set_weather("rain")
	loop.enter("restaurant")
	await wait_for(0.1)
	check("inside stops rain", not a.ambient.playing)
	loop.end_phase()
	await wait_for(0.2)
	check("crossfade both voices", a.music[0].playing and a.music[1].playing)
	await wait_for(0.8)
	check("night fade complete", a.current_music == "night_town3" and a.music[a.active].playing and not a.music[1-a.active].playing)
	for key in ["day_town", "night_town3", "rain", "wind"]:
		var p = AudioStreamPlayer.new()
		root.add_child(p)
		p.volume_db = -60
		p.stream = a.streams[key]
		p.play(p.stream.get_length()-0.15)
		await wait_for(0.5)
		check("actual end wraps " + key, p.playing and p.get_playback_position() < 1.0)
		p.queue_free()
	for key in ["gather", "process", "cook", "serve", "coins", "ui"]:
		for p in a.effects: p.stop()
		a.play_event(key)
		check("event voice starts " + key, a.effects[0].playing and a.effects[0].stream == a.streams[key])
		a.effects[0].stop()
	a.set_music_volume(0.1)
	check("music slider gain", absf(a.music[a.active].volume_db - (linear_to_db(0.1)-6)) < 0.1)
	a.music_muted = true
	a.effects_muted = true
	a.apply_volume()
	check("independent mute flags", a.music[a.active].stream_paused and a.effects_muted)
	a.play_event("ui")
	check("muted no effect playback", not a.effects[0].playing)
	a.music_muted = false
	a.effects_muted = false
	a.set_music_volume(0)
	a.set_effects_volume(0)
	check("zero sliders mute", a.music[a.active].stream_paused and a.effects_volume == 0)
	a.set_music_volume(0.22)
	a.set_effects_volume(0.35)
	check("restore settings", not a.music[a.active].stream_paused)
	# Night field is closed; test active outdoor rain in town.
	loop.enter("town")
	await wait_for(0.1)
	a.effects_muted = true
	a.apply_volume()
	check("active rain muted", a.ambient.stream_paused)
	a.effects_muted = false
	a.set_effects_volume(0.2)
	check("ambient gain and resume", not a.ambient.stream_paused and absf(a.ambient.volume_db - (linear_to_db(0.2)-12)) < 0.1)
	loop.enter("restaurant")
	a.set_effects_volume(0.35)
	var before = a.counts.duplicate()
	loop.cook_dish(0)
	loop.interact()
	await wait_for(0.2)
	check("failed action and frames no sounds", before == a.counts)
	await mouse_click(lane, Vector2(588,350))
	check("mouse opens settings", a.panel.visible)
	await mouse_click(lane, Vector2(500,117))
	check("mouse music mute", a.music_muted)
	await mouse_click(lane, Vector2(500,117))
	await mouse_click(lane, Vector2(500,189))
	check("mouse effects mute", a.effects_muted)
	await mouse_click(lane, Vector2(500,189))
	await mouse_click(lane, Vector2(520,148))
	check("mouse music slider", not is_equal_approx(a.music_volume, 0.22))
	await wait_for(0.1)
	RenderingServer.force_draw(false)
	check("settings screenshot", lane.viewport.get_texture().get_image().save_png("res://Sounds/Walala/Verification/settings.png") == OK)
	await mouse_click(lane, Vector2(530,264))
	await wait_for(0.2)
	RenderingServer.force_draw(false)
	check("visible credits", a.credits.visible)
	check("credits screenshot", lane.viewport.get_texture().get_image().save_png("res://Sounds/Walala/Verification/credits.png") == OK)
	var credit_text = a.credits.get_child(0)
	credit_text.get_v_scroll_bar().value = credit_text.get_v_scroll_bar().max_value
	await wait_for(0.1)
	RenderingServer.force_draw(false)
	check("credits bottom screenshot", lane.viewport.get_texture().get_image().save_png("res://Sounds/Walala/Verification/credits_bottom.png") == OK)
	await mouse_click(lane, Vector2(320,278))
	check("close credits", not a.credits.visible)
	lane.queue_free()
	await wait_for(0.1)
	print("AUDIO VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
