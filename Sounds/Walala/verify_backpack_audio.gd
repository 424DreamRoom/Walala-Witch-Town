extends "res://Sounds/Walala/verify_pause_audio.gd"
## Real HUD, backpack and audio with a minimal world, independent of town art.

class TestWeather extends RefCounted:
	var weather := "rain"
	func get_weather() -> String: return weather

class TestHarvest extends RefCounted:
	func cancel() -> void: pass

class TestLane extends Node2D:
	var viewport: SubViewport
	var player := Node2D.new()
	var weather := TestWeather.new()
	var test_direction := Vector2.ZERO
	func _ready() -> void:
		var container := SubViewportContainer.new()
		container.size = Vector2(640, 360)
		container.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(container)
		viewport = SubViewport.new()
		viewport.size = Vector2i(640, 360)
		viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
		container.add_child(viewport)
		viewport.add_child(player)
	func _physics_process(delta: float) -> void:
		player.position += test_direction * delta * 90.0

class TestLoop extends Node:
	var state = preload("res://Scenes/Gameplay/loop_state.gd").new()
	var audio
	var hud
	var lane
	var location := "town"
	var ui := CanvasLayer.new()
	var header := Label.new()
	var inventory := Label.new()
	var end_button := Button.new()
	var discard_button := Button.new()
	var summary := Label.new()
	var backgrounds := [Panel.new()]
	var harvest := TestHarvest.new()
	var save_menu := {"open": false, "leaving": false}
	var campaign_controller = null
	var builder = null
	var paused_for_test := true
	func _process(delta: float) -> void:
		if not paused_for_test: state.tick(delta)
	func _autosave() -> void: pass

func run() -> void:
	print("PAUSE AUDIO DRIVER ", AudioServer.get_driver_name())
	lane = TestLane.new()
	root.add_child(lane)
	current_scene = lane
	loop = TestLoop.new()
	loop.lane = lane
	lane.add_child(loop)
	loop.audio = load("res://Sounds/Walala/audio_manager.gd").new()
	loop.add_child(loop.audio)
	lane.viewport.add_child(loop.ui)
	for control in [loop.header, loop.inventory, loop.end_button, loop.discard_button, loop.summary, loop.backgrounds[0]]:
		loop.ui.add_child(control)
	loop.audio.build_ui(loop.ui, preload("res://Scenes/Gameplay/ui_font.gd").get_font())
	loop.hud = load("res://Scenes/UI/game_hud.gd").new()
	loop.hud.loop = loop
	loop.add_child(loop.hud)
	for weather in ["rain", "snow"]:
		lane.weather.weather = weather
		loop.audio.set_context("day", "town", weather)
		await wait_for(0.9)
		await backpack_pause()
	lane.queue_free()
	await process_frame
	await wait_for(0.2)
	Saves.end_session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferences.file_path))
	print("PAUSE AUDIO VERIFY END failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
