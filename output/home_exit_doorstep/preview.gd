extends SceneTree

const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Navigation = preload("res://Scenes/LanternLane/verification_navigation.gd")
const OUT := "res://output/home_exit_doorstep/"

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	run.call_deferred()

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame
		await physics_frame

func run() -> void:
	var lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	var loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	if not await Navigation.walk(lane, loop.area.stations.exit):
		quit(1)
		return
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()
	await frames(12)
	print("HOME EXIT PREVIEW location=", loop.location, " position=", lane.player.position, " facing=", lane.facing)
	RenderingServer.force_draw(false)
	var captured := root.get_texture().get_image().save_png(OUT + "home_exit.png") == OK
	var correct: bool = loop.location == "farm" and lane.player.position == Vector2(270, 258) and lane.facing == 0
	lane.queue_free()
	await frames()
	quit(0 if captured and correct else 1)
