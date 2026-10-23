extends SceneTree
const OUT := "res://output/all_room_centering/"
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
var lane
var loop
func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	preload("res://Scenes/Campaign/campaign_state.gd").pending_intro = false
	run.call_deferred()
func frames() -> void:
	for i in range(3):
		await process_frame
		await physics_frame
func shot(title: String) -> void:
	await frames()
	RenderingServer.force_draw(false)
	lane.viewport.get_texture().get_image().save_png(OUT + "before_" + title + ".png")
func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.state.restaurant_leased = true
	loop.state.campaign.settling_in = true
	for level in range(4):
		loop.state.furniture.legacy_fixtures = level == 3
		loop.state.furniture.house_level = mini(level, 2)
		loop.enter("home")
		await shot("home_%d" % level)
	for kind in ["store", "blacksmith", "furniture_store", "restaurant"]:
		loop.enter(kind)
		await shot(kind)
	lane.queue_free()
	await frames()
	quit()
