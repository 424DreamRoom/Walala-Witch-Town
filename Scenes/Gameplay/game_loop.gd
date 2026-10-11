extends Node
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Area = preload("res://Scenes/Gameplay/play_area.gd")
const DayNightCycle = preload("res://Scenes/Gameplay/day_night_cycle.gd")
const Home = preload("res://Scenes/WitchHome/witch_home.tscn")
const Farm = preload("res://Scenes/Farm/farm.tscn")
const Dock = preload("res://Scenes/Dock/dock.tscn")
const Blacksmith = preload("res://Scenes/Businesses/blacksmith.tscn")
const Store = preload("res://Scenes/Businesses/store.tscn")
const FurnitureStore = preload("res://Scenes/Businesses/furniture_store.tscn")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const I18n = preload("res://Localization/localized_text.gd")
const ThoughtBubble = preload("res://Scenes/Gameplay/thought_bubble.gd")
const FootstepSurfaces = preload("res://Sounds/Walala/footstep_surfaces.gd")
var state = State.new()
var day_night
var audio
var footstep_surfaces = FootstepSurfaces.new()
var harvest
var lane
var location = "town"
var area
var font: Font
var ui: CanvasLayer
var header: Label
var inventory: Label
var notice: Label
var thought_bubble: ThoughtBubble
var sidebar_title: Label
var summary: Label
var end_button: Button
var discard_button: Button
var recipe_button: Button
var service_hours: Label
var menu_buttons: Array = []
var cook_buttons: Array = []
var backgrounds: Array[Panel] = []
var gate_labels: Array[Label] = []
var last_message := ""
var message_left := 0.0
var town_position = Vector2(408, 364)
# First doorstep below the house; the feet clear its collision edge at y=250.
const HOME_EXIT_POSITION := Vector2(270, 258)
var farm_position = HOME_EXIT_POSITION
var town_solids: Array[Rect2] = []
var town_roofs: Array = []
var markers: Node2D
var last_phase = "day"
var awaiting_open := false
var paused_for_test = false
var save_menu
var hud
var builder
const AUTOSAVE_INTERVAL_MINUTES := 6.0 * 60.0
const AUTOSAVE_RETRY_SECONDS := 30.0
var next_autosave_at := 0.0
var autosave_retry_left := 0.0
var restoring_save := true
var FIELD_GATE = Vector2(454, 10)
var REST_GATE = Vector2(570, 718)
var FARM_GATE = Vector2(8, 364)
var DOCK_GATE = Vector2(1272, 652)
var BLACKSMITH_GATE = Vector2(1020, 556)
var STORE_GATE = Vector2(620, 376)
var FURNITURE_GATE = Vector2(200, 636)
var GATES: Array = []
const LARGE_AREAS = ["home", "farm", "dock", "blacksmith", "store", "furniture_store"]
var exit_pending := false
var exit_latched := true
var campaign_controller

func _ready() -> void:
	lane = get_parent()
	var town_layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lane.ART + "town_layout.json"))
	var gates: Dictionary = town_layout.get("gates", {})
	FIELD_GATE = _gate(gates, "field", FIELD_GATE)
	REST_GATE = _gate(gates, "restaurant", REST_GATE)
	FARM_GATE = _gate(gates, "farm", FARM_GATE)
	DOCK_GATE = _gate(gates, "dock", DOCK_GATE)
	BLACKSMITH_GATE = _gate(gates, "blacksmith", BLACKSMITH_GATE)
	STORE_GATE = _gate(gates, "store", STORE_GATE)
	FURNITURE_GATE = _gate(gates, "furniture_store", FURNITURE_GATE)
	GATES = [FIELD_GATE, REST_GATE, FARM_GATE, DOCK_GATE, BLACKSMITH_GATE, STORE_GATE, FURNITURE_GATE]
	var loaded := Saves.consume_pending()
	if not loaded.is_empty():
		state.restore_save_data(loaded.state)
	day_night = DayNightCycle.new()
	day_night.name = "DayNightCycle"
	lane.viewport.add_child(day_night)
	day_night.configure(location)
	day_night.sync(state)
	# The original visual-only container has no Control hit-test rectangle.
	lane.viewport.get_parent().size = Vector2(640, 360)
	town_solids = lane.solid_rects.duplicate()
	town_roofs = lane.weather.roof_rects.duplicate()
	font = UIFont.get_font()
	audio = preload("res://Sounds/Walala/audio_manager.gd").new()
	add_child(audio)
	footstep_surfaces.configure(town_layout)
	lane.player_moved.connect(_on_player_moved)
	harvest = preload("res://Scenes/Gameplay/harvest_actions.gd").new()
	harvest.loop = self
	lane.harvest = harvest
	lane.player.add_child(harvest)
	last_message = state.message
	_make_ui()
	audio.build_ui(ui, font)
	markers = Node2D.new()
	markers.z_index = preload("res://Scenes/Gameplay/world_depth.gd").LABEL
	lane.world.add_child(markers)
	for spec in [[FIELD_GATE, "野外", "field", Vector2(30, 36)], [REST_GATE, "餐厅", "restaurant", Vector2(26, 8)], [FARM_GATE, "月芽农场 ←", "home", Vector2(26, -12)], [DOCK_GATE, "潮汐码头", "dock", Vector2(-32, 24)], [BLACKSMITH_GATE, "余烬铁匠铺", "blacksmith", Vector2(-33, 0)], [STORE_GATE, "橡果杂货店", "store", Vector2(-33, 0)], [FURNITURE_GATE, "榛木家具店", "furniture_store", Vector2(-33, 0)]]:
		var sign_node := Node2D.new()
		sign_node.position = spec[0] + spec[3]
		lane.actors.add_child(sign_node)
		var sign_sprite := Sprite2D.new()
		sign_sprite.texture = load(lane.ART + (spec[2] + "_sign.aseprite" if spec[2] in ["blacksmith", "store"] else "outdoor_sign_" + spec[2] + ".aseprite"))
		sign_sprite.position.y = -sign_sprite.texture.get_height() / 2.0
		sign_node.add_child(sign_sprite)
		var text = Label.new()
		text.text = spec[1]
		text.position = spec[0] + Vector2(-22, -29)
		text.add_theme_font_override("font", font)
		text.add_theme_font_size_override("font_size", UIFont.BASE_SIZE)
		markers.add_child(text)
		gate_labels.append(text)
	if not loaded.is_empty():
		_restore_world(loaded.world)
	else:
		enter_home_doorstep()
	last_phase = state.phase
	_sync_phase()
	_schedule_next_autosave()
	restoring_save = false
	save_menu = preload("res://Scenes/Save/save_menu.gd").new()
	save_menu.loop = self
	add_child(save_menu)
	hud = preload("res://Scenes/UI/game_hud.gd").new()
	hud.loop = self
	add_child(hud)
	builder = preload("res://Scenes/Building/furniture_builder.gd").new()
	builder.loop = self
	add_child(builder)
	campaign_controller = preload("res://Scenes/Campaign/campaign_controller.gd").new()
	campaign_controller.loop = self
	add_child(campaign_controller)
	_refresh()
	Localization.language_changed.connect(_refresh_language)

func _refresh_language(_locale: String) -> void:
	_refresh()

func enter_home_doorstep() -> void:
	if location != "farm": enter("farm")
	farm_position = HOME_EXIT_POSITION
	lane.player.position = HOME_EXIT_POSITION
	lane.player.velocity = Vector2.ZERO
	lane.facing = 0
	lane._animate(false, false, 0.0)
	lane.camera.reset_smoothing()
	lane.camera.force_update_scroll()

func _gate(gates: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Array = gates.get(key, [fallback.x, fallback.y])
	return Vector2(value[0], value[1])

func _safe_town_position(value: Vector2) -> Vector2:
	if not value.is_finite() or value.x < 5 or value.y < 6 or value.x > lane.world_size.x - 5 or value.y > lane.world_size.y:
		return lane.SPAWN
	var feet := Rect2(value - Vector2(5, 6), Vector2(10, 6))
	for rect in town_solids:
		if rect.intersects(feet):
			return lane.SPAWN
	return value

func _restore_world(world_data: Dictionary) -> void:
	exit_latched = true
	var saved_message: String = state.message
	lane.weather.set_weather(world_data.weather)
	var saved_farm: Array = world_data.get("farm_position", [HOME_EXIT_POSITION.x, HOME_EXIT_POSITION.y])
	farm_position = Vector2(saved_farm[0], saved_farm[1])
	if world_data.location != "town":
		var was_restoring := restoring_save
		restoring_save = true
		enter(world_data.location)
		restoring_save = was_restoring
	state.message = saved_message
	town_position = _safe_town_position(Vector2(world_data.town_position[0], world_data.town_position[1]))
	var restored_position := Vector2(world_data.position[0], world_data.position[1])
	lane.player.position = _safe_town_position(restored_position) if location == "town" else restored_position
	if location in ["restaurant", "blacksmith", "store", "furniture_store"]:
		lane.player.position = _safe_interior_position(restored_position)
	if location == "home" and not state.furniture.legacy_fixtures:
		var feet := Rect2(restored_position - Vector2(5, 6), Vector2(10, 6))
		var floor := State.Furniture.House.floor_for(state.furniture)
		if not floor.has_point(restored_position) and not Rect2(296, 416, 48, 60).has_point(restored_position):
			lane.player.position = area.spawn
		elif area.solids.any(func(rect): return rect.intersects(feet)):
			lane.player.position = area.spawn
	lane.facing = int(world_data.facing)
	lane._animate(false, false, 0.0)
	lane.camera.reset_smoothing()
	lane.camera.force_update_scroll()
	last_message = state.message
	# Loaded feedback is historical and may contain obsolete UI instructions.
	message_left = 0.0

func _safe_interior_position(value: Vector2) -> Vector2:
	# Old saves can refer to floor removed when the public interiors were tightened.
	if not value.is_finite(): return area.spawn
	var feet := Rect2(value - Vector2(5, 6), Vector2(10, 6))
	if not area.walkable_regions.any(func(rect): return rect.encloses(feet)):
		return area.spawn
	if area.solids.any(func(rect): return rect.intersects(feet)):
		return area.spawn
	return value

func save_progress() -> Dictionary:
	if Saves.active_slot == 0:
		return {"ok": false, "error": "没有使用中的存档"}
	var position: Vector2 = lane.player.position
	var outdoor_position: Vector2 = position if location == "town" else town_position
	var now := maxi(Saves.created_at, int(Time.get_unix_time_from_system()))
	var farm_return: Vector2 = position if location == "farm" else farm_position
	var snapshot := {"state": state.to_save_data(), "world": {"location": location, "position": [position.x, position.y], "town_position": [outdoor_position.x, outdoor_position.y], "farm_position": [farm_return.x, farm_return.y], "facing": lane.facing, "weather": lane.weather.get_weather()}, "play_seconds": Saves.play_seconds, "created_at": Saves.created_at, "saved_at": now, "saved_at_text": Time.get_datetime_string_from_system(false, true)}
	if save_menu != null:
		save_menu.indicator.begin_save()
	var result := Saves.write_slot(Saves.active_slot, snapshot)
	if save_menu != null:
		save_menu.indicator.finish_save(result.ok)
	if result.ok:
		_schedule_next_autosave()
	return result

func _game_time_minutes() -> float:
	return (state.day - 1) * 1440.0 + state.get_time_minutes()

func _schedule_next_autosave() -> void:
	# Six-hour boundaries plus the 22:00 closing save also survive loading.
	# Manual saves between boundaries do not postpone the next automatic save.
	next_autosave_at = (floori(_game_time_minutes() / AUTOSAVE_INTERVAL_MINUTES) + 1) * AUTOSAVE_INTERVAL_MINUTES
	var closing_at: float = (state.day - 1) * 1440.0 + state.CLOSE_MINUTES
	if state.phase != "result": next_autosave_at = minf(next_autosave_at, closing_at)
	autosave_retry_left = 0.0

func _autosave() -> void:
	# Gameplay events share this gate and never cause extra writes.
	if restoring_save or Saves.active_slot == 0 or save_menu == null:
		return
	if paused_for_test or get_tree().paused or harvest.busy() or autosave_retry_left > 0.0:
		return
	if _game_time_minutes() < next_autosave_at:
		return
	var result := save_progress()
	save_menu.report_save(result, true)
	if not result.ok:
		# Leave the boundary pending without retrying a failed write every frame.
		autosave_retry_left = AUTOSAVE_RETRY_SECONDS

func _label(pos: Vector2, size: Vector2, parent: Node) -> Label:
	var label = Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", UIFont.BASE_SIZE)
	label.add_theme_color_override("font_color", UISkin.INK)
	parent.add_child(label)
	return label

func _button(text: String, pos: Vector2, size: Vector2, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", UIFont.BASE_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	ui.add_child(button)
	return button

func _make_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	lane.viewport.add_child(ui)
	for rect in [Rect2(0, 0, 640, 26), Rect2(440, 64, 200, 153)]:
		var bg = Panel.new()
		bg.position = rect.position
		bg.size = rect.size
		bg.add_theme_stylebox_override("panel", UISkin.panel_style(rect.size.y < 40))
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(bg)
		backgrounds.append(bg)
	header = _label(Vector2(10, 4), Vector2(455, 24), ui)
	inventory = _label(Vector2(10, 27), Vector2(625, 34), ui)
	sidebar_title = _label(Vector2(450, 74), Vector2(180, 18), ui)
	var descriptions = ["蘑菇汤：切片菇2 / 12金", "莓果派：莓果酱2 / 14金", "炖菇：切片菇1+草料1 / 18金"]
	for i in range(3):
		var b = _button(I18n.format("%s  %d金", [state.DISHES[i], state.PRICES[i]]), Vector2(450, 96 + i * 31), Vector2(180, 27), _toggle_menu.bind(i))
		b.pressed.disconnect(_toggle_menu.bind(i))
		b.toggled.connect(_set_menu.bind(i))
		b.toggle_mode = true
		b.tooltip_text = descriptions[i]
		menu_buttons.append(b)
		var cook = _button(I18n.format("做%s", [state.DISHES[i]]), Vector2(450, 96 + i * 31), Vector2(180, 27), cook_dish.bind(i))
		cook.tooltip_text = descriptions[i]
		cook_buttons.append(cook)
	discard_button = _button("丢弃手中菜", Vector2(542, 282), Vector2(94, 25), state.discard)
	service_hours = _label(Vector2(450, 190), Vector2(180, 22), ui)
	recipe_button = _button("食谱", Vector2(450, 219), Vector2(180, 26), open_recipes)
	end_button = _button("开始营业", Vector2(470, 3), Vector2(166, 23), end_phase)
	thought_bubble = ThoughtBubble.new()
	thought_bubble.loop = self
	ui.add_child(thought_bubble)
	backgrounds.append(thought_bubble)
	notice = thought_bubble.caption
	summary = _label(Vector2(30, 90), Vector2(388, 190), ui)
	summary.add_theme_stylebox_override("normal", UISkin.panel_style())
	summary.visible = false

func _set_menu(enabled: bool, dish: int) -> void:
	if state.set_menu_dish(dish, enabled):
		audio.play_event("ui")
	else:
		menu_buttons[dish].set_pressed_no_signal(state.menu[dish])
		_show_feedback()

func open_recipes() -> void:
	if location == "restaurant" and state.phase == "day" and campaign_controller != null:
		campaign_controller.open("食谱")

func _toggle_menu(dish: int) -> void:
	if state.phase == "day":
		_set_menu(not state.menu[dish],dish)

func near(pos: Vector2) -> bool:
	return lane.player.position.distance_to(pos) <= 27.0

func _show_feedback() -> void:
	last_message = state.message
	message_left = 3.5

func cook_dish(dish: int) -> void:
	if location != "restaurant" or not near(area.stations.kitchen):
		state.message = "不在料理台旁"
		_show_feedback()
		return
	if state.start_cook(dish):
		audio.play_event("cook")
	_show_feedback()

func _road_exit(target: String, gate: Vector2, direction: Vector2, width: float, arrival: Vector2) -> Dictionary:
	var size := Vector2(16, width) if direction.x != 0 else Vector2(width, 16)
	return {"target": target, "rect": Rect2(gate - size / 2.0, size), "direction": direction, "return": arrival}

func _scene_exits() -> Array[Dictionary]:
	if location == "town":
		var exits: Array[Dictionary] = [
			_road_exit("field", FIELD_GATE, Vector2.UP, 34, FIELD_GATE + Vector2(0, 34)),
			_road_exit("dock", DOCK_GATE, Vector2.RIGHT, 42, DOCK_GATE + Vector2(-34, 0)),
			_road_exit("farm", FARM_GATE, Vector2.LEFT, 52, FARM_GATE),
		]
		for spec in [[REST_GATE, "restaurant"], [BLACKSMITH_GATE, "blacksmith"], [STORE_GATE, "store"], [FURNITURE_GATE, "furniture_store"]]:
			exits.append({"target": spec[1], "rect": Rect2(spec[0] + Vector2(-16, -18), Vector2(32, 20)), "direction": Vector2.UP, "return": spec[0] + Vector2(0, 34), "door": spec[0]})
		return exits
	if location == "farm":
		return [
			_road_exit("town", area.stations.exit, Vector2.RIGHT, 52, FARM_GATE),
			{"target": "home", "rect": Rect2(area.stations.home + Vector2(-16, -18), Vector2(32, 20)), "direction": Vector2.UP, "return": HOME_EXIT_POSITION, "door": area.stations.home},
		]
	var exit_position: Vector2 = area.stations.exit
	if location in ["field", "dock"]:
		return [_road_exit("town", exit_position, area.exit_direction if location == "field" else Vector2.LEFT, 34 if location == "field" else 42, town_position)]
	var downstairs: bool = location in ["home", "blacksmith", "store", "furniture_store"]
	return [{"target": "farm" if location == "home" else "town", "rect": Rect2(exit_position + Vector2(-24, 0), Vector2(48, 24)) if downstairs else Rect2(exit_position + Vector2(-16, -20), Vector2(24, 40)), "direction": Vector2.DOWN if downstairs else Vector2.LEFT, "return": farm_position if location == "home" else town_position, "door": exit_position}]

func _try_door_exit() -> bool:
	# Doors use the normal interaction distance and a fresh interact press.
	# Unlike road boundaries, they remain usable when loading at the doorway.
	for exit in _scene_exits():
		if exit.has("door") and near(exit.door):
			exit_pending = true
			_use_scene_exit.call_deferred(location, exit)
			return true
	return false

func _check_scene_exit(distance: float) -> void:
	if exit_pending or state.phase == "result" or get_tree().paused:
		return
	var touching := false
	var exits := _scene_exits()
	for exit in exits:
		if not exit.has("door") and exit.rect.grow(4.0).has_point(lane.player.position):
			touching = true
	if not touching:
		exit_latched = false
	if exit_latched or distance <= 0.01:
		return
	for exit in exits:
		if not exit.has("door") and exit.rect.has_point(lane.player.position) and lane.player.velocity.dot(exit.direction) > 0.0:
			exit_latched = true
			exit_pending = true
			# Moving/reparenting physics bodies must happen after the physics callback.
			_use_scene_exit.call_deferred(location, exit)
			return

func _use_scene_exit(source: String, exit: Dictionary) -> void:
	exit_pending = false
	if source != location or state.phase == "result" or get_tree().paused:
		return
	if exit.target in ["field", "dock"] and state.phase != "day":
		state.message = "夜间关闭"
		_show_feedback()
		return
	travel(exit.target, exit["return"])

func interact() -> void:
	if exit_pending or state.phase == "result" or get_tree().paused:
		return
	if harvest.busy():
		harvest.interact()
		return
	if _try_door_exit(): return
	if campaign_controller != null and campaign_controller.try_interact(): return
	if location == "field":
		var selected: Dictionary = area.nearest_interaction()
		if not selected.is_empty():
			if selected.type == "resource":
				harvest.start(selected.node)
			elif selected.type == "campaign":
				if state.Campaign.gather(state, area.region_id, selected.index): audio.play_event("gather")
				_show_feedback()
			else:
				if state.gather(selected.index):
					audio.play_event("gather")
				_show_feedback()
	elif location == "dock":
		var selected: Dictionary = area.nearest_interaction()
		if not selected.is_empty():
			harvest.start(selected.node)
	elif location in ["home", "farm", "blacksmith", "store", "furniture_store"]:
		area.interact()
	elif location == "restaurant":
		if near(area.stations.prep):
			if state.process_raw():
				audio.play_event("process")
			_show_feedback()
		else:
			for i in range(state.Campaign.restaurant(state).seats):
				if near(area.seats[i]):
					if state.serve(i):
						audio.play_event("serve")
					_show_feedback()
					return

func travel(target: String, return_position: Vector2 = Vector2.INF) -> void:
	if restoring_save:
		enter(target, return_position)
		return
	if SceneTransition.active: return
	exit_pending = true
	harvest.cancel()
	audio.reset_footsteps()
	await SceneTransition.run(_commit_travel.bind(target, return_position))
	exit_pending = false

func _commit_travel(target: String, return_position: Vector2) -> void:
	enter(target, return_position)
	_refresh()
	if campaign_controller != null:
		campaign_controller._update_decor()

# Immediate world setup is also used by save restoration and the opening scene.
func enter(target: String, return_position: Vector2 = Vector2.INF) -> void:
	var requested_region: String = state.campaign.region if target == "field" and restoring_save else target
	if not state.Campaign.entry(state.Content.DATA.regions, requested_region).is_empty():
		if state.phase != "day" or state.campaign.chapter < state.Campaign.entry(state.Content.DATA.regions, requested_region).chapter: return
		state.campaign.region = requested_region
		target = "field"
	elif target == "field":
		state.campaign.region = "field"
	if target in ["field", "dock"] and state.phase != "day":
		return
	if builder != null and builder.active(): builder.close()
	if hud != null and hud.mode == "chest": hud.close_modal()
	harvest.cancel()
	audio.reset_footsteps()
	var source: String = location
	if source == "farm":
		farm_position = HOME_EXIT_POSITION if target == "home" else lane.player.position
	audio.reset_footsteps()
	# Detach inactive worlds: their collision bodies must not remain in the space.
	if location == "town":
		town_position = _safe_town_position(return_position) if return_position.is_finite() else lane.player.position
		lane.player.reparent(lane.viewport, false)
		lane.viewport.remove_child(lane.world)
	else:
		lane.player.reparent(lane.viewport, false)
		lane.viewport.remove_child(area)
		area.queue_free()
		area = null
	location = target
	exit_pending = false
	exit_latched = true
	if target == "town":
		if source == "farm":
			# Arrive at the marked western entrance even with an older save.
			town_position = FARM_GATE
		lane.viewport.add_child(lane.world)
		lane.player.reparent(lane.actors, false)
		lane.player.position = _safe_town_position(town_position)
		lane.camera.limit_right = lane.world_size.x
		lane.camera.limit_bottom = lane.world_size.y
		lane.solid_rects = town_solids.duplicate()
		lane.weather.configure(lane.camera, lane.player, town_roofs)
	else:
		if target == "field" and state.campaign.region != "field":
			area = preload("res://Scenes/Campaign/exploration_area.gd").new()
			area.region_id = state.campaign.region
		elif target == "farm":
			area = Farm.instantiate()
		elif target == "blacksmith":
			area = Blacksmith.instantiate()
		elif target == "store":
			area = Store.instantiate()
		elif target == "furniture_store":
			area = FurnitureStore.instantiate()
		else:
			area = Home.instantiate() if target == "home" else Dock.instantiate() if target == "dock" else Area.new()
		if target not in LARGE_AREAS:
			area.kind = target
		area.loop = self
		lane.viewport.add_child(area)
		lane.viewport.move_child(area, 0)
		lane.player.reparent(area, false)
		lane.player.position = area.spawn
		if target == "farm" and source == "home":
			# Use the front doorstep arrival, including from older saves.
			farm_position = HOME_EXIT_POSITION
			lane.player.position = farm_position
			lane.facing = 0
		lane.camera.limit_right = area.world_size.x if target in LARGE_AREAS else 640
		lane.camera.limit_bottom = area.world_size.y if target in LARGE_AREAS else 360
		lane.solid_rects = area.solids.duplicate()
		lane.weather.configure(lane.camera, lane.player, area.roof_rects if target == "farm" else [])
	lane.weather.visible = target not in ["restaurant", "home", "blacksmith", "store", "furniture_store"]
	day_night.configure(location)
	day_night.sync(state)
	lane.player.velocity = Vector2.ZERO
	lane._animate(false, false, 0.0)
	lane.camera.force_update_scroll()
	audio.set_context(state.phase, location, lane.weather.get_weather())
	if last_phase == state.phase:
		_autosave()

func _on_player_moved(distance: float, running: bool) -> void:
	if state.phase != "result":
		var surface = footstep_surfaces.resolve(location, lane.player.position, lane.weather.get_weather())
		if location == "farm" and surface != "snow" and state.farm.plots.has(str(area.Terrain.index_at(lane.player.position))): surface = "dirt"
		audio.update_footsteps(distance, running, surface)
	_check_scene_exit(distance)
	audio.set_context(state.phase, location, lane.weather.get_weather())

func reset_player() -> void:
	harvest.cancel()
	exit_latched = true
	if location != "town":
		lane.player.position = area.spawn

func end_phase() -> void:
	if state.phase == "day" and location != "restaurant": return
	harvest.cancel()
	audio.play_event("ui")
	if state.phase == "result":
		state.next_day()
		if location != "town":
			travel("town")
	else:
		state.end_phase()
	_sync_phase()

func _sync_phase() -> void:
	var preparation_due: bool = state.phase == "day" and state.remaining <= 0.0
	if preparation_due and not awaiting_open:
		harvest.cancel()
		if location != "restaurant": travel("restaurant")
	awaiting_open = preparation_due
	if last_phase != state.phase:
		if state.phase == "night" and location != "restaurant":
			travel("restaurant")
		if state.phase == "result" and state.income > 0:
			audio.play_event("coins")
		if state.phase == "result":
			audio.reset_footsteps()
		last_phase = state.phase
		_autosave()
	lane.set_physics_process(state.phase != "result")
	day_night.sync(state)

func _process(delta: float) -> void:
	# Rain wets all tilled soil, including at night and while the player is indoors.
	if lane.weather.get_weather() == "rain":
		state.rain_on_farm()
	if not paused_for_test:
		state.tick(delta)
		if Saves.active_slot > 0:
			Saves.play_seconds += delta
			autosave_retry_left = maxf(0.0, autosave_retry_left - delta)
	_sync_phase()
	harvest.advance(delta)
	audio.set_context(state.phase, location, lane.weather.get_weather())
	_autosave()
	if state.message != last_message:
		last_message = state.message
		message_left = 3.5
	else:
		message_left = maxf(0.0, message_left - delta)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if InputBindings.capture_active: return
	if InputBindings.is_action_press(event):
		if event.is_action_pressed("interact"):
			interact()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.physical_keycode == KEY_R:
			if not InputBindings.is_bound_event(event): reset_player.call_deferred()
		elif event.is_action_pressed("ui_cancel"):
			harvest.cancel()

func _refresh() -> void:
	var phase_name = {"day": "白天", "night": "营业", "result": "结算"}[state.phase]
	header.text = I18n.format("第%d天 · %s %03d秒 · %s · %d金", [state.day, phase_name, ceili(state.remaining), {"town": "小镇", "farm": "月芽农场", "field": "野外", "restaurant": "餐厅", "home": "小女巫的家", "dock": "潮汐码头", "blacksmith": "余烬铁匠铺", "store": "橡果杂货店", "furniture_store": "榛木家具店"}[location], state.coins])
	var active: bool = state.phase != "result"
	var in_restaurant: bool = location == "restaurant" and active
	var show_menu: bool = in_restaurant and state.phase == "day"
	var show_cooking: bool = in_restaurant and state.phase == "night" and near(area.stations.kitchen)
	backgrounds[0].size.y = 62 if in_restaurant else (46 if location in ["field", "dock"] and active else 26)
	backgrounds[1].visible = show_menu or show_cooking
	backgrounds[1].size.y = 222 if show_menu else 153
	sidebar_title.visible = backgrounds[1].visible
	sidebar_title.text = I18n.format("今日菜单 %d/%d", [state.menu.count(true), state.Campaign.restaurant(state).menu]) if show_menu else tr("料理")
	service_hours.visible = show_menu
	service_hours.text = I18n.format("18:00–22:00 · %d分钟", [int(state.NIGHT_SECONDS / 60)])
	recipe_button.visible = show_menu
	inventory.visible = active and location in ["field", "restaurant", "dock"]
	notice.visible = active and location != "home" and message_left > 0.0 and not state.message.is_empty() and not get_tree().paused
	backgrounds[2].visible = notice.visible
	var bag: String = tr("背包 %d/%d：蘑菇%d  莓果%d  香草%d") % [state.raw[0]+state.raw[1]+state.raw[2], state.bag_capacity(), state.raw[0], state.raw[1], state.raw[2]]
	inventory.text = bag
	if location in ["field", "dock"]:
		inventory.text = tr("菇%d  莓%d  草%d（%d/%d）  |  木材%d  矿石%d  鱼%d") % [state.raw[0], state.raw[1], state.raw[2], state.raw[0] + state.raw[1] + state.raw[2], state.bag_capacity(), state.resources.wood, state.resources.ore, state.resources.fish]
	if in_restaurant:
		inventory.text = tr("%s　|　厨房：菇%d  莓%d  草%d\n本晚 %d金") % [bag, state.materials[0], state.materials[1], state.materials[2], state.income]
		if state.cooking >= 0:
			inventory.text += I18n.format("　%s %.1f秒", [state.DISHES[state.cooking], state.cook_left])
		elif state.held >= 0:
			inventory.text += tr("　手中：") + tr(state.DISHES[state.held])
	thought_bubble.set_message(ThoughtBubble.message_text(state))
	for i in range(gate_labels.size()):
		var gate: Vector2 = GATES[i]
		gate_labels[i].visible = active and location == "town" and near(gate)
		gate_labels[i].position.y = floorf(maxf(8.0, minf(gate.y - 29, lane.player.position.y - lane.CHARACTER_SIZE.y - gate_labels[i].size.y - 4)))
	for i in range(3):
		menu_buttons[i].visible = show_menu
		cook_buttons[i].visible = show_cooking
		if menu_buttons[i].button_pressed != state.menu[i] and not menu_buttons[i].is_hovered():
			menu_buttons[i].set_pressed_no_signal(state.menu[i])
		menu_buttons[i].disabled = state.phase != "day"
		cook_buttons[i].disabled = state.phase != "night" or location != "restaurant" or not near(area.stations.kitchen) or state.cooking >= 0 or state.held >= 0 or not state.menu[i] or not state.can_cook(i)
	discard_button.disabled = state.held < 0
	discard_button.visible = in_restaurant and state.held >= 0
	end_button.text = {"day": "开始营业", "night": "结束营业", "result": "进入次日"}[state.phase]
	end_button.disabled = show_menu and not state.opening_error().is_empty()
	end_button.tooltip_text = tr(state.opening_error()) if show_menu else ""
	summary.visible = state.phase == "result"
	summary.text = state.get_result_text()
	if hud != null:
		hud.refresh()

func _exit_tree() -> void:
	# Detached town is owned here when exiting from an interior.
	if is_instance_valid(lane.world) and not lane.world.is_inside_tree():
		lane.world.free()
