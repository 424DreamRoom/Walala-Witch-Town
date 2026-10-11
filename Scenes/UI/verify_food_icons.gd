extends SceneTree
## Real food UI and held-dish rendering, with isolated preferences and save paths.
const FoodIcons = preload("res://Scenes/UI/food_icons.gd")
const Content = preload("res://Scenes/Campaign/content.gd")
const Campaign = preload("res://Scenes/Campaign/campaign_state.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const OUT := "res://output/food_icons/"
var failures := 0
var checks := 0
var capture := false
var lane
var loop

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Preferences.file_path = OUT + "preferences_%d.cfg" % OS.get_process_id()
	Saves.directory = OUT + "saves_%d" % OS.get_process_id()
	Saves.end_session()
	Campaign.pending_intro = false
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("FOOD ICON TEST ", title, ": ", "PASS" if ok else "FAIL")

func frames(count: int = 5) -> void:
	for i in range(count): await process_frame

func shot(name: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + name, lane.viewport.get_texture().get_image().save_png(OUT + name + ".png") == OK)

func run() -> void:
	for id in Content.DATA.items:
		if id in ["wood", "ore", "iron", "crystal", "scrap"]: continue
		check("ingredient " + id, FoodIcons.texture(id) != null)
	for recipe in Content.DATA.recipes:
		check("recipe " + recipe.id, FoodIcons.texture("dish_" + recipe.id) != null)
	for id in ["egg", "tomato", "bread", "dish_wheat_bread"]:
		var texture: Texture2D = FoodIcons.texture(id)
		check("MyArt native canvas " + id, texture.get_size() == Vector2(16, 16) and texture.resource_path.begins_with("res://MyArt/Icon/Food/"))
	check("bread recipe uses hand-drawn pixels", FoodIcons.texture("bread").get_image().get_data() == FoodIcons.texture("dish_wheat_bread").get_image().get_data())
	check("legacy ingredient aliases", FoodIcons.texture("herbs") == FoodIcons.texture("herb") and FoodIcons.texture("berries") == FoodIcons.texture("berry"))
	check("non-food art remains available", FoodIcons.from_path("res://Art/Campaign/icons/wood.aseprite").resource_path == "res://Art/Campaign/icons/wood.aseprite")
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(10)
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.state.campaign.introduced = true
	loop.state.campaign.player_name = "Food Test"
	loop.campaign_controller.open("食谱")
	await frames()
	check("real recipe UI opens", loop.hud.mode == "campaign")
	await shot("recipes")
	for index in range(Content.DATA.recipes.size()):
		if Content.DATA.recipes[index].id != "wheat_bread": continue
		var row: HBoxContainer = loop.campaign_controller.list.get_child(index + 1)
		check("cookbook bread prefers MyArt", row.get_child(0).texture == FoodIcons.texture("dish_wheat_bread"))
		loop.campaign_controller.list.get_parent().get_v_scroll_bar().value = row.position.y - 24
		await shot("recipes_bread")
	loop.campaign_controller.open("仓储")
	await frames()
	await shot("pantry")
	for id in ["tomato", "egg"]:
		var index: int = Content.DATA.items.keys().find(id)
		var row: HBoxContainer = loop.campaign_controller.list.get_child(index)
		check("pantry prefers MyArt " + id, row.get_child(0).texture == FoodIcons.texture(id))
		loop.campaign_controller.list.get_parent().get_v_scroll_bar().value = row.position.y - 24
		await shot("pantry_" + id)
	loop.hud.close_modal()
	loop.state.Items.change(loop.state, {"mushroom": 2, "berry": 2, "herb": 2})
	loop.hud.open_bag()
	await frames()
	await shot("backpack")
	loop.hud.close_modal()
	loop.enter("restaurant")
	await frames()
	for index in range(Content.DATA.recipes.size()):
		if Content.DATA.recipes[index].id == "wheat_bread": loop.state.held = index
	loop._refresh()
	await frames()
	check("held bread uses shared food texture", loop.area.dish_textures.wheat_bread == FoodIcons.texture("dish_wheat_bread"))
	await shot("held_bread")
	loop.state.held = -1
	lane.queue_free()
	await frames()
	print("FOOD ICON VERIFY END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
