extends Node
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Area = preload("res://Scenes/Gameplay/play_area.gd")
const Home = preload("res://Scenes/WitchHome/witch_home.tscn")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
var state = State.new()
var audio
var harvest
var lane
var location = "town"
var area
var font: Font
var ui: CanvasLayer
var header: Label
var inventory: Label
var notice: Label
var sidebar_title: Label
var summary: Label
var end_button: Button
var discard_button: Button
var menu_buttons: Array = []
var cook_buttons: Array = []
var backgrounds: Array[ColorRect] = []
var gate_labels: Array[Label] = []
var last_message := ""
var message_left := 0.0
var town_position = Vector2(408, 364)
var town_solids: Array[Rect2] = []
var town_roofs: Array = []
var markers: Node2D
var last_phase = "day"
var paused_for_test = false
const FIELD_GATE = Vector2(408, 334)
const REST_GATE = Vector2(448, 384)
const HOME_GATE = Vector2(224, 314)

func _ready() -> void:
	lane = get_parent()
	# The original visual-only container has no Control hit-test rectangle.
	lane.viewport.get_parent().size = Vector2(640, 360)
	town_solids = lane.solid_rects.duplicate()
	town_roofs = lane.weather.roof_rects.duplicate()
	font = UIFont.get_font()
	audio = preload("res://Sounds/Walala/audio_manager.gd").new()
	add_child(audio)
	harvest = preload("res://Scenes/Gameplay/harvest_actions.gd").new()
	harvest.loop = self
	lane.harvest = harvest
	lane.viewport.add_child(harvest)
	last_message = state.message
	_make_ui()
	audio.build_ui(ui, font)
	markers = Node2D.new()
	lane.world.add_child(markers)
	for spec in [[FIELD_GATE, "野外 E", "field", Vector2(26, 0)], [REST_GATE, "餐厅 E", "restaurant", Vector2(26, 8)], [HOME_GATE, "家 E", "home", Vector2(-33, 0)]]:
		var sign_node := Node2D.new()
		sign_node.position = spec[0] + spec[3]
		lane.actors.add_child(sign_node)
		var sign_sprite := Sprite2D.new()
		sign_sprite.texture = load(lane.ART + "outdoor_sign_" + spec[2] + ".png")
		sign_sprite.position.y = -sign_sprite.texture.get_height() / 2.0
		sign_node.add_child(sign_sprite)
		var text = Label.new()
		text.text = spec[1]
		text.position = spec[0] + Vector2(-22, -29)
		text.add_theme_font_override("font", font)
		text.add_theme_font_size_override("font_size", UIFont.BASE_SIZE)
		markers.add_child(text)
		gate_labels.append(text)
	_refresh()

func _label(pos: Vector2, size: Vector2, parent: Node) -> Label:
	var label = Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", UIFont.BASE_SIZE)
	label.add_theme_color_override("font_color", Color("fff1d3"))
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
	for rect in [Rect2(0, 0, 640, 26), Rect2(440, 64, 200, 153), Rect2(0, 310, 640, 30)]:
		var bg = ColorRect.new()
		bg.position = rect.position
		bg.size = rect.size
		bg.color = Color("28312f")
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(bg)
		backgrounds.append(bg)
	header = _label(Vector2(10, 4), Vector2(455, 24), ui)
	inventory = _label(Vector2(10, 27), Vector2(625, 34), ui)
	sidebar_title = _label(Vector2(448, 70), Vector2(184, 18), ui)
	var descriptions = ["蘑菇汤：切片菇2 / 12金", "莓果派：莓果酱2 / 14金", "炖菇：切片菇1+草料1 / 18金"]
	for i in range(3):
		var b = _button("%s  %d金" % [state.DISHES[i], state.PRICES[i]], Vector2(446, 94 + i * 31), Vector2(190, 27), _toggle_menu.bind(i))
		b.pressed.disconnect(_toggle_menu.bind(i))
		b.toggled.connect(_set_menu.bind(i))
		b.toggle_mode = true
		b.tooltip_text = descriptions[i]
		menu_buttons.append(b)
		var cook = _button("做" + state.DISHES[i], Vector2(446, 94 + i * 31), Vector2(190, 27), cook_dish.bind(i))
		cook.tooltip_text = descriptions[i]
		cook_buttons.append(cook)
	discard_button = _button("丢弃手中菜", Vector2(542, 282), Vector2(94, 25), state.discard)
	end_button = _button("提前结束白天", Vector2(470, 3), Vector2(166, 23), end_phase)
	notice = _label(Vector2(10, 311), Vector2(625, 30), ui)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary = _label(Vector2(30, 90), Vector2(388, 190), ui)
	var summary_bg = StyleBoxFlat.new()
	summary_bg.bg_color = Color("29352f")
	summary.add_theme_stylebox_override("normal", summary_bg)
	summary.visible = false

func _set_menu(enabled: bool, dish: int) -> void:
	if state.phase == "day":
		state.menu[dish] = enabled
		audio.play_event("ui")

func _toggle_menu(dish: int) -> void:
	if state.phase == "day":
		state.menu[dish] = not state.menu[dish]

func near(pos: Vector2) -> bool:
	return lane.player.position.distance_to(pos) <= 27.0

func _show_feedback() -> void:
	last_message = state.message
	message_left = 3.5

func cook_dish(dish: int) -> void:
	if location != "restaurant" or not near(area.stations.kitchen):
		state.message = "请走到料理台前。"
		_show_feedback()
		return
	if state.start_cook(dish):
		audio.play_event("cook")
	_show_feedback()

func interact() -> void:
	if state.phase == "result":
		return
	if harvest.busy():
		harvest.interact()
		return
	if location == "town":
		if near(FIELD_GATE):
			if state.phase == "day":
				enter("field")
			else:
				state.message = "野外夜间关闭，请进餐厅营业。"
				_show_feedback()
		elif near(REST_GATE):
			enter("restaurant")
		elif near(HOME_GATE):
			enter("home")
	elif near(area.stations.exit):
		enter("town")
	elif location == "field":
		var selected: Dictionary = area.nearest_interaction()
		if not selected.is_empty():
			if selected.type == "resource":
				harvest.start(selected.node)
			else:
				if state.gather(selected.index):
					audio.play_event("gather")
				_show_feedback()
	elif location == "restaurant":
		if near(area.stations.prep):
			if state.process_raw():
				audio.play_event("process")
			_show_feedback()
		else:
			for i in range(3):
				if near(area.seats[i]):
					if state.serve(i):
						audio.play_event("serve")
					_show_feedback()
					return

func enter(target: String) -> void:
	if target == "field" and state.phase != "day":
		return
	harvest.cancel()
	# Detach inactive worlds: their collision bodies must not remain in the space.
	if location == "town":
		town_position = lane.player.position
		lane.player.reparent(lane.viewport, false)
		lane.viewport.remove_child(lane.world)
	else:
		lane.player.reparent(lane.viewport, false)
		lane.viewport.remove_child(area)
		area.queue_free()
		area = null
	location = target
	if target == "town":
		lane.viewport.add_child(lane.world)
		lane.player.reparent(lane.actors, false)
		lane.player.position = town_position
		lane.camera.limit_right = 1280
		lane.camera.limit_bottom = 960
		lane.solid_rects = town_solids.duplicate()
		lane.weather.configure(lane.camera, lane.player, town_roofs)
	else:
		area = Home.instantiate() if target == "home" else Area.new()
		if target != "home":
			area.kind = target
		area.loop = self
		lane.viewport.add_child(area)
		lane.viewport.move_child(area, 0)
		lane.player.reparent(area, false)
		lane.player.position = area.spawn if target == "home" else Vector2(60, 280)
		lane.camera.limit_right = area.world_size.x if target == "home" else 640
		lane.camera.limit_bottom = area.world_size.y if target == "home" else 360
		lane.solid_rects = area.solids.duplicate()
		lane.weather.configure(lane.camera, lane.player, [])
	lane.weather.visible = target not in ["restaurant", "home"]
	lane.player.velocity = Vector2.ZERO
	lane.camera.force_update_scroll()

func reset_player() -> void:
	harvest.cancel()
	if location != "town":
		lane.player.position = area.spawn if location == "home" else Vector2(60, 280)

func end_phase() -> void:
	harvest.cancel()
	audio.play_event("ui")
	if state.phase == "result":
		state.next_day()
		if location != "town":
			enter("town")
	else:
		state.end_phase()
	_sync_phase()

func _sync_phase() -> void:
	if last_phase != state.phase:
		if state.phase == "night" and location != "restaurant":
			enter("restaurant")
		if state.phase == "result" and state.income > 0:
			audio.play_event("coins")
		last_phase = state.phase
	lane.set_physics_process(state.phase != "result")

func _process(delta: float) -> void:
	if not paused_for_test:
		state.tick(delta)
	_sync_phase()
	harvest.advance(delta)
	audio.set_context(state.phase, location, lane.weather.get_weather())
	if state.message != last_message:
		last_message = state.message
		message_left = 3.5
	else:
		message_left = maxf(0.0, message_left - delta)
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			interact()
		elif event.physical_keycode == KEY_R:
			reset_player.call_deferred()
		elif event.physical_keycode == KEY_ESCAPE:
			harvest.cancel()

func _refresh() -> void:
	var phase_name = {"day": "白天", "night": "营业", "result": "结算"}[state.phase]
	header.text = "第%d天 · %s %03d秒 · %s · %d金" % [state.day, phase_name, ceili(state.remaining), {"town": "小镇", "field": "野外", "restaurant": "餐厅", "home": "小女巫的家"}[location], state.coins]
	var active: bool = state.phase != "result"
	var in_restaurant: bool = location == "restaurant" and active
	var show_menu: bool = in_restaurant and state.phase == "day"
	var show_cooking: bool = in_restaurant and state.phase == "night" and near(area.stations.kitchen)
	backgrounds[0].size.y = 62 if in_restaurant else (46 if location == "field" and active else 26)
	backgrounds[1].visible = show_menu or show_cooking
	sidebar_title.visible = backgrounds[1].visible
	sidebar_title.text = "菜单" if show_menu else "料理"
	inventory.visible = active and location in ["field", "restaurant"]
	notice.visible = active and location != "home" and message_left > 0.0 and not state.message.is_empty()
	backgrounds[2].visible = notice.visible
	var bag: String = "背包 %d/12：蘑菇%d  莓果%d  香草%d" % [state.raw[0]+state.raw[1]+state.raw[2], state.raw[0], state.raw[1], state.raw[2]]
	inventory.text = bag
	if location == "field":
		inventory.text = "菇%d  莓%d  草%d（%d/12）  |  木材%d  矿石%d  鱼%d" % [state.raw[0], state.raw[1], state.raw[2], state.raw[0] + state.raw[1] + state.raw[2], state.resources.wood, state.resources.ore, state.resources.fish]
	if in_restaurant:
		inventory.text = "%s　|　厨房：菇%d  莓%d  草%d\n本晚 %d金" % [bag, state.materials[0], state.materials[1], state.materials[2], state.income]
		if state.cooking >= 0:
			inventory.text += "　%s %.1f秒" % [state.DISHES[state.cooking], state.cook_left]
		elif state.held >= 0:
			inventory.text += "　手中：" + state.DISHES[state.held]
	notice.text = state.message
	for i in range(gate_labels.size()):
		var gate: Vector2 = [FIELD_GATE, REST_GATE, HOME_GATE][i]
		gate_labels[i].visible = active and location == "town" and near(gate)
		gate_labels[i].position.y = floorf(minf(gate.y - 29, lane.player.position.y - lane.CHARACTER_SIZE.y - gate_labels[i].size.y - 4))
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
	summary.visible = state.phase == "result"
	summary.text = state.result

func _exit_tree() -> void:
	# Detached town is owned here when exiting from an interior.
	if is_instance_valid(lane.world) and not lane.world.is_inside_tree():
		lane.world.free()
