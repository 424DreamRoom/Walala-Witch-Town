extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Catalog = preload("res://Scenes/Building/furniture_catalog.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const OUT := "res://output/construction/"
var failures := 0
var checks := 0
var lane
var loop
var capture := false
var restart := ""

func _initialize() -> void:
	var profile := OUT + "profile_%d" % OS.get_process_id()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profile = arg.trim_prefix("--profile=")
		if arg == "--capture": capture = true
		if arg in ["--write", "--read"]: restart = arg
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile))
	Preferences.file_path = profile + "/preferences.cfg"
	Saves.directory = profile + "/saves"
	Saves.end_session()
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks += 1
	print("CONSTRUCTION ", title, ": ", "PASS" if passed else "FAIL")
	if not passed: failures += 1

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func click(control: Control) -> void:
	await click_at(control.get_global_rect().get_center())

func click_at(point: Vector2) -> void:
	var container: SubViewportContainer = lane.viewport.get_parent()
	var screen := container.position + point * container.scale
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	root.push_input(motion, true)
	await frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = screen
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await frames()

func shot(title: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	check("capture " + title, pixels.save_png(OUT + title + ".png") == OK)

func rich_state():
	var s := State.new()
	s.resources.wood = 100
	s.resources.iron = 40
	s.resources.ore = 100
	s.furniture.house_level = 2
	for item in Catalog.FarmTerrain.layout.props: s.resource_damage[item.resource_id] = s.RESOURCE_HITS
	return s

func domain_checks() -> void:
	check("at least sixty distinct recipes", Catalog.IDS.size() >= 60 and Catalog.RECIPES.size() == Catalog.IDS.size())
	var s = rich_state()
	var before: Dictionary = s.to_save_data()
	check("remote crafting rejected without charges", not s.craft_furniture("bed") and s.resources == before.resources and s.furniture == before.furniture)
	check("other maps cannot supply a workbench", not s.can_craft_furniture("stool", "town", Catalog.STARTER_BENCH))
	check("distant workbench cannot supply crafting", not s.can_craft_furniture("stool", "farm", Vector2(900, 500)))
	for kind in Catalog.IDS:
		s = rich_state()
		var recipe: Dictionary = Catalog.RECIPES[kind]
		check("icon and world sprite " + kind, Catalog.icon(kind) != null and Catalog.texture(kind) != null)
		check("craft exact materials " + kind, s.craft_furniture(kind, "farm", Catalog.STARTER_BENCH + Vector2(0, 20)) and s.resources.wood == 100 - recipe.wood and s.resources.iron == 40 - recipe.iron and s.resources.ore == 100 - recipe.ore and s.furniture.stock[kind] == 1)
		var area: String = "farm" if recipe.area == "farm" else "home"
		var point := Vector2(640, 512) if area == "farm" else Vector2(240, 320)
		var player := Vector2(416, 312) if area == "farm" else Vector2(320, 405)
		check("place and validate save " + kind, s.place_furniture(kind, point, player, area) and not State.normalize_save_data(s.to_save_data()).is_empty())
		var id: int = s.furniture.next_id - 1
		check("move then reclaim " + kind, s.move_furniture(id, point + Vector2(16, 0), player) and s.store_furniture(id) and s.furniture.stock[kind] == 1 and not s.store_furniture(id))
	s = rich_state()
	s.resources.wood = 1
	var stock: Dictionary = s.furniture.stock.duplicate(true)
	check("one missing material prevents all charges", not s.craft_furniture("workbench", "farm", Vector2(416, 312)) and s.resources.iron == 40 and s.resources.ore == 100 and s.furniture.stock == stock)
	s = rich_state()
	s.furniture.stock.workbench = 1
	check("home workbench can be placed", s.place_furniture("workbench", Vector2(240, 320), Vector2(320, 405)))
	check("placed home workbench enables crafting", s.can_craft_furniture("stool", "home", Vector2(240, 336)))
	check("home workbench cannot work across maps", not s.can_craft_furniture("stool", "farm", Vector2(240, 336)))
	check("removing workbench immediately removes access", s.store_furniture(1) and not s.can_craft_furniture("stool", "home", Vector2(240, 336)))
	s.furniture.stock.picket_fence = 10
	check("outdoor fence cannot be placed inside", not s.place_furniture("picket_fence", Vector2(240, 320), Vector2(320, 405)))
	check("entrance road stays open", not s.place_furniture("picket_fence", Vector2(640, 336), Vector2(416, 312), "farm"))
	check("workbench footprint protected", not s.place_furniture("picket_fence", Catalog.STARTER_BENCH, Vector2(416, 312), "farm"))
	check("outdoor perimeter protected", not s.place_furniture("picket_fence", Vector2(10, 10), Vector2(416, 312), "farm"))
	var plot: int = Catalog.FarmTerrain.index_at(Vector2(640, 512))
	s.farm.plots[str(plot)] = {"growth": -1, "watered": false}
	check("existing crops protected", not s.place_furniture("picket_fence", Vector2(640, 512), Vector2(416, 312), "farm"))
	s.farm.plots.clear()
	check("cleared farm supports fence", s.place_furniture("picket_fence", Vector2(640, 512), Vector2(416, 312), "farm"))
	check("built footprint blocks tilling", not Catalog.FarmTerrain.can_till(s, plot))
	s.furniture.stock.stone_path = 1
	check("path can pass beneath fence", s.place_furniture("stone_path", Vector2(640, 512), Vector2(416, 312), "farm") and not Catalog.blocking("stone_path"))
	check("stock is shared across maps", s.furniture.stock.picket_fence == 9)
	var saved: Dictionary = s.to_save_data()
	check("outdoor area persists", State.normalize_save_data(saved).furniture == s.furniture)
	var invalid: Dictionary = saved.duplicate(true)
	invalid.furniture.placed[0].area = "town"
	check("unknown construction area rejected", State.normalize_save_data(invalid).is_empty())
	invalid = saved.duplicate(true)
	invalid.farm.plots[str(plot)] = {"growth": -1, "watered": false}
	check("overlap between crops and buildings rejected on load", State.normalize_save_data(invalid).is_empty())
	invalid = saved.duplicate(true)
	invalid.furniture.placed.append(invalid.furniture.placed[0].duplicate())
	check("duplicate building IDs rejected", State.normalize_save_data(invalid).is_empty())
	var legacy: Dictionary = Catalog.legacy_data()
	for kind in Catalog.IDS:
		if kind not in Catalog.LEGACY_IDS: legacy.stock.erase(kind)
	var migrated := Catalog.normalize(legacy)
	check("seven-recipe saves migrate with original furniture", not migrated.is_empty() and migrated.placed == legacy.placed and migrated.stock.workbench == 0 and migrated.stock.picket_fence == 0)
	s.phase = "night"
	check("night crafting never charges", not s.craft_furniture("stool", "farm", Vector2(416, 312)) and s.furniture == saved.furniture)

func run() -> void:
	if restart != "--read": domain_checks()
	check("isolated save slot opens", Saves.begin_slot(1).ok)
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	current_scene = lane
	await frames(6)
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.audio.set_music_muted(true)
	loop.audio.set_effects_muted(true)
	if restart == "--read":
		check("fresh process restores home location", loop.location == "home")
		check("fresh process restores outdoor furniture", loop.state.furniture.placed.any(func(item): return item.kind == "picket_fence" and Catalog.area_of(item) == "farm"))
		check("fresh process restores indoor bed", loop.state.furniture.placed.any(func(item): return item.kind == "single_bed" and Catalog.area_of(item) == "home"))
		check("fresh process restores chest contents", loop.state.furniture.placed.any(func(item): return item.kind == "chest" and item.items.get("wood", 0) == 5))
	else:
		loop.state.campaign.introduced = true
		loop.state.campaign.guide_met = true
		State.Campaign.pending_intro = false
		loop.enter("farm")
		for item in Catalog.FarmTerrain.layout.props: loop.state.resource_damage[item.resource_id] = loop.state.RESOURCE_HITS
		loop.area.refresh_resources()
		loop.state.resources.wood = 90
		loop.state.resources.iron = 30
		loop.state.resources.ore = 60
		lane.player.position = Vector2(416, 312)
		lane.camera.force_update_scroll()
		await key(KEY_E)
		var builder = loop.builder
		check("real interaction opens workbench catalog", builder.mode == "catalog" and paused)
		check("catalog has eight icon entries per page", builder.recipe_buttons.size() == 8 and builder.recipe_buttons.all(func(button): return button.icon != null))
		for locale in ["zh_CN", "en", "ja", "zh_TW"]:
			root.get_node("Localization").set_language(locale, false)
			await shot("catalog_" + locale)
		root.get_node("Localization").set_language("zh_CN", false)
		var listed := {}
		for index in range(9):
			builder.page = index
			builder._catalog()
			for id in builder.visible_ids: listed[id] = true
		check("all recipes accessible through pages", listed.size() == Catalog.IDS.size() and builder.root.get_node("FurnitureCatalog/NextPage").disabled)
		var categories: OptionButton = builder.root.get_node("FurnitureCatalog/Categories")
		categories.select(3)
		categories.item_selected.emit(3)
		check("category filters bed recipes", builder.visible_ids.size() == 5 and builder.visible_ids.all(func(id): return Catalog.RECIPES[id].category == "beds"))
		builder.category = "all"
		builder.page = 0
		builder._catalog()
		var search: LineEdit = builder.root.get_node("FurnitureCatalog/Search")
		search.text = "栅栏"
		search.text_changed.emit(search.text)
		check("name filter keeps matching icons", builder.visible_ids.size() == 4 and builder.visible_ids.all(func(id): return Catalog.RECIPES[id].title.contains("栅栏")))
		builder.search_text = ""
		builder._catalog()
		await click(builder.root.get_node("FurnitureCatalog/NextPage"))
		check("real paging exposes fences", "picket_fence" in builder.visible_ids)
		await click(builder.root.get_node("FurnitureCatalog/Recipe_picket_fence"))
		await click(builder.detail.get_node("Craft"))
		check("real craft consumes listed materials", loop.state.resources.wood == 87 and loop.state.furniture.stock.picket_fence == 1)
		await click(builder.detail.get_node("Place"))
		await click_at(lane.viewport.get_canvas_transform() * Vector2(512, 288))
		check("real mouse placement creates collision", builder.mode == "edit" and Catalog.footprint("picket_fence", Vector2(512, 288)) in lane.solid_rects and loop.area.furniture_bodies.size() == 1)
		var fence_id: int = loop.state.furniture.next_id - 1
		await click(builder.move_button)
		await key(KEY_D)
		await key(KEY_E)
		check("real keyboard moves fence atomically", loop.state.furniture_by_id(fence_id).x == 528)
		await click(builder.store_button)
		check("real reclaim removes collision", loop.state.furniture.stock.picket_fence == 1 and loop.area.furniture_bodies.is_empty())
		builder.cursor = Vector2(1000, 600)
		await key(KEY_D)
		check("large farm keyboard placement pans camera", lane.camera.position != builder.camera_position_before)
		builder.close()
		check("world resumes and HUD returns", not paused and loop.hud.base.visible)
		# A built fence blocks actual CharacterBody movement.
		check("outdoor fence restored for collision check", loop.state.place_furniture("picket_fence", Vector2(512, 288), lane.player.position, "farm"))
		loop.area.refresh_furniture()
		lane.player.position = Vector2(512, 310)
		lane.test_direction = Vector2.UP
		for i in range(20): await physics_frame
		lane.test_direction = Vector2.ZERO
		check("outdoor fence physically blocks walking", lane.player.position.y >= 293)
		# Local benches, beds, storage, paths, lamps and crops coexist across maps.
		lane.player.position = Vector2(416, 312)
		for spec in [["wood_gate", Vector2(560, 288)], ["street_lamp", Vector2(608, 288)], ["flower_box", Vector2(680, 288)], ["stone_path", Vector2(512, 288)], ["chest", Vector2(736, 288)]]:
			loop.state.furniture.stock[spec[0]] = 1
			check("outdoor scene furnishing " + spec[0], loop.state.place_furniture(spec[0], spec[1], lane.player.position, "farm"))
		var chest_id: int = loop.state.furniture.next_id - 1
		check("outdoor chest stores inventory", loop.state.transfer_chest(chest_id, "wood", 5, true) == 5)
		loop.area.refresh_furniture()
		lane.player.position = Vector2(736, 310)
		await key(KEY_E)
		check("outdoor chest opens actual inventory", loop.hud.mode == "chest")
		loop.hud.close_modal()
		check("nonempty outdoor chest cannot be reclaimed", not loop.state.store_furniture(chest_id))
		loop.state.message = ""
		loop.last_message = ""
		loop.message_left = 0
		await shot("farm_construction")
		var lamp: PointLight2D
		for body in loop.area.furniture_bodies:
			for child in body.get_children():
				if child is PointLight2D: lamp = child
		lamp._process(0)
		check("outdoor lamps are dim during daytime", not lamp.enabled)
		var remaining: float = loop.state.remaining
		loop.state.remaining = 0
		lamp._process(0)
		check("outdoor lamps brighten at dusk", lamp.enabled and lamp.energy > 0)
		loop.state.remaining = remaining
		loop.enter("home")
		check("outdoor objects do not leak into home", loop.area.furniture_bodies.is_empty())
		lane.player.position = Vector2(320, 405)
		loop.state.furniture.stock.workbench = 1
		loop.state.furniture.stock.single_bed = 1
		check("starter room accepts bed and workbench", loop.state.place_furniture("workbench", Vector2(256, 336), lane.player.position) and loop.state.place_furniture("single_bed", Vector2(384, 352), lane.player.position))
		loop.area.refresh_furniture()
		lane.player.position = Vector2(256, 357)
		await key(KEY_E)
		check("placed home bench opens actual catalog", builder.active() and not builder.detail.get_node("Craft").disabled)
		builder.close()
		loop.state.furniture.stock.chest = 1
		check("adjacent chest fixture placed", loop.state.place_furniture("chest", Vector2(256, 384), lane.player.position))
		var nearby_id: int = loop.state.furniture.next_id - 1
		loop.area.refresh_furniture()
		await key(KEY_E)
		check("closer chest retains interaction beside workbench", loop.hud.mode == "chest" and not builder.active())
		loop.hud.close_modal()
		check("adjacent fixture reclaimed", loop.state.store_furniture(nearby_id))
		loop.area.refresh_furniture()
		lane.player.position = Vector2(384, 400)
		builder.open_catalog()
		check("craft button unavailable away from bench", builder.detail.get_node("Craft").disabled)
		builder.close()
		await shot("home_construction")
		loop.hud.open_map()
		loop.hud.map_view.show_region("farm", false)
		check("map displays outdoor construction", loop.hud.map_view.canvas.region_items("farm").any(func(item): return item.kind == "built_picket_fence"))
		await shot("farm_map")
		loop.hud.close_modal()
		var expected: Dictionary = loop.state.furniture.duplicate(true)
		check("save construction to isolated disk", loop.save_progress().ok)
		check("disk round trip retains areas and storage", Saves.read_slot(1).ok and Saves.read_slot(1).data.state.furniture == expected)
		loop.enter("farm")
		check("returning to farm preserves collisions", loop.area.furniture_bodies.size() == 6 and Catalog.footprint("picket_fence", Vector2(512, 288)) in lane.solid_rects)
		# Contact sheet is rendered by Godot from the same textures used in buttons.
		if capture:
			var sheet := Image.create(8 * 96, 9 * 96, false, Image.FORMAT_RGBA8)
			sheet.fill(Color("f0ddb1"))
			for index in range(Catalog.IDS.size()):
				var pixels: Image = Catalog.icon(Catalog.IDS[index]).get_image()
				pixels.resize(80, 80, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(pixels, Rect2i(0, 0, 80, 80), Vector2i((index % 8) * 96 + 8, (index / 8) * 96 + 8))
			check("icon contact sheet", sheet.save_png(OUT + "icons_%d.png" % Catalog.IDS.size()) == OK)
	Saves.end_session()
	lane.queue_free()
	await frames(6)
	await create_timer(0.2).timeout
	print("CONSTRUCTION VERIFY END checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
