extends SceneTree

const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/town_entry_position/"

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
	loop.enter("farm")
	lane.player.position = Vector2(938, 364)
	await frames()
	lane.test_direction = Vector2.RIGHT
	for i in range(45):
		await frames(1)
		if loop.location == "town":
			lane.test_direction = Vector2.ZERO
			break
	await frames(12)
	print("TOWN ENTRY PREVIEW location=", loop.location, " position=", lane.player.position, " home_exit=", loop.HOME_EXIT_POSITION)
	RenderingServer.force_draw(false)
	var captured := root.get_texture().get_image().save_png(OUT + "town_entry.png") == OK
	var correct: bool = loop.location == "town" and lane.player.position == Vector2(8, 364) and loop.HOME_EXIT_POSITION == Vector2(938, 364)
	lane.queue_free()
	await frames()
	quit(0 if captured and correct else 1)
