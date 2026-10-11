extends Node
## A paused building session. Inventory changes occur only after confirmation.
const Catalog = preload("res://Scenes/Building/furniture_catalog.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const I18n = preload("res://Localization/localized_text.gd")
var loop
var layer: CanvasLayer
var root: ColorRect
var detail: Control
var resource_label: Label
var status_label: Label
var selection_label: Label
var move_button: Button
var store_button: Button
var recipe_buttons: Array[Button] = []
var mode := ""
var selected_kind := "stool"
var selected_id := -1
var cursor := Vector2(392, 368)
var error := ""
var feedback := ""
var paused_before := false
var hud_visible_before := true
var camera_position_before := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 70
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	loop.lane.viewport.add_child(layer)
	root = ColorRect.new()
	root.name = "FurnitureBuilder"
	root.size = Vector2(640, 360)
	root.hide()
	layer.add_child(root)
	root.gui_input.connect(_room_input)
	root.draw.connect(_draw_room)
	Localization.language_changed.connect(func(_locale: String):
		if mode == "catalog": _catalog()
		elif active(): _room(mode))
	InputBindings.bindings_changed.connect(func():
		if active() and mode != "catalog": _room(mode))

func active() -> bool:
	return not mode.is_empty()

func open_catalog() -> bool:
	if loop.location != "home" or loop.state.phase != "day" or loop.save_menu.open: return false
	if not active():
		if not loop.hud.mode.is_empty(): loop.hud.close_modal()
		loop.harvest.cancel()
		loop.audio.reset_footsteps()
		paused_before = get_tree().paused
		hud_visible_before = loop.hud.base.visible
		camera_position_before = loop.lane.camera.position
		# Keep the floor visible even when building starts beside the north wall.
		loop.lane.camera.position += Vector2(320, 300) - loop.lane.camera.global_position
		loop.lane.camera.force_update_scroll()
		get_tree().paused = true
		loop.hud.base.hide()
		loop.lane.player.velocity = Vector2.ZERO
		loop.audio.play_event("ui_open")
	feedback = ""
	root.show()
	_catalog()
	return true

func close() -> void:
	if not active(): return
	mode = ""
	root.hide()
	loop.hud.base.visible = hud_visible_before
	loop.lane.camera.position = camera_position_before
	loop.lane.camera.force_update_scroll()
	get_tree().paused = paused_before
	loop.audio.play_event("ui_close")

func cancel() -> void:
	if mode in ["place", "move"]:
		if mode == "move": _room("edit")
		else: _catalog()
	else:
		close()

func _clear() -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	root.queue_redraw()

func _panel(rect: Rect2, parent: Node) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", UISkin.panel_style())
	parent.add_child(panel)
	return panel

func _label(text: String, rect: Rect2, parent: Node, font_size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_color_override("font_color", UISkin.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFont.apply_control(label, font_size)
	parent.add_child(label)
	return label

func _button(text: String, rect: Rect2, parent: Node, callback: Callable, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.clip_text = true
	UIFont.apply_control(button)
	UISkin.compact_button(button)
	loop.audio.ui_audio.bind_button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _catalog() -> void:
	mode = "catalog"
	_clear()
	root.color = Color(0.12, 0.08, 0.15, 0.66)
	var book := _panel(Rect2(40, 24, 560, 312), root)
	book.name = "FurnitureCatalog"
	_label("家具建造", Rect2(20, 12, 520, 32), book, 24)
	resource_label = _label("", Rect2(20, 48, 520, 20), book)
	recipe_buttons.clear()
	for index in range(Catalog.IDS.size()):
		var kind: String = Catalog.IDS[index]
		var entry := _button(Catalog.RECIPES[kind].title, Rect2(20, 78 + index * 27, 188, 25), book, func():
			selected_kind = kind
			feedback = ""
			_refresh_catalog(), "Recipe_" + kind)
		entry.toggle_mode = true
		recipe_buttons.append(entry)
	detail = Control.new()
	detail.position = Vector2(228, 76)
	book.add_child(detail)
	_button("整理房间", Rect2(20, 278, 188, 26), book, func():
		selected_id = -1
		_room("edit"), "Arrange")
	_button("返回", Rect2(428, 278, 112, 26), book, close, "Done")
	_refresh_catalog()
	recipe_buttons[Catalog.IDS.find(selected_kind)].grab_focus()

func _refresh_catalog() -> void:
	resource_label.text = tr("木材 %d · 铁锭 %d") % [loop.state.resources.wood, loop.state.resources.iron]
	for index in range(recipe_buttons.size()): recipe_buttons[index].set_pressed_no_signal(Catalog.IDS[index] == selected_kind)
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var recipe: Dictionary = Catalog.RECIPES[selected_kind]
	_label(recipe.title, Rect2(0, 0, 310, 24), detail, 18)
	var picture := TextureRect.new()
	picture.texture = Catalog.texture(selected_kind)
	picture.position = Vector2(0, 28)
	picture.size = Vector2(120, 112)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(picture)
	_label("制作材料", Rect2(138, 34, 160, 20), detail)
	_label(tr("木材 %d / %d") % [loop.state.resources.wood, recipe.wood], Rect2(138, 60, 160, 20), detail)
	_label(tr("铁锭 %d / %d") % [loop.state.resources.iron, recipe.iron], Rect2(138, 86, 160, 20), detail)
	var placed := 0
	for item in loop.state.furniture.placed:
		if item.kind == selected_kind: placed += 1
	_label(tr("收纳 %d · 已摆放 %d") % [loop.state.furniture.stock[selected_kind], placed], Rect2(0, 146, 310, 20), detail)
	var craft := _button("制作", Rect2(0, 174, 146, 26), detail, _craft, "Craft")
	craft.disabled = not loop.state.can_craft_furniture(selected_kind)
	var place := _button("摆放", Rect2(158, 174, 146, 26), detail, func():
		cursor = _snap(loop.lane.player.position + Vector2(64, -16))
		_room("place"), "Place")
	place.disabled = loop.state.furniture.stock[selected_kind] <= 0 or loop.state.furniture.placed.size() >= Catalog.MAX_PLACED
	_label(tr(feedback), Rect2(0, 204, 310, 22), detail)

func _craft() -> void:
	if loop.state.craft_furniture(selected_kind):
		feedback = "制作完成"
		loop.audio.play_event("process")
		loop._autosave()
	else:
		feedback = loop.state.message
		loop.audio.play_event("ui_error")
	_refresh_catalog()
	detail.get_node("Craft").grab_focus()

func _room(new_mode: String) -> void:
	mode = new_mode
	_clear()
	root.color = Color.TRANSPARENT
	var heading := _panel(Rect2(8, 8, 624, 42), root)
	selection_label = _label("", Rect2(12, 3, 210, 34), heading)
	status_label = _label("", Rect2(224, 3, 388, 34), heading)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bar := _panel(Rect2(8, 314, 624, 38), root)
	if mode in ["place", "move"]:
		_button("确认摆放", Rect2(10, 7, 140, 24), bar, _confirm, "ConfirmPlace")
		_button("取消", Rect2(160, 7, 100, 24), bar, cancel, "CancelPlace")
	else:
		move_button = _button("移动", Rect2(10, 7, 108, 24), bar, _start_move, "Move")
		store_button = _button("收回", Rect2(128, 7, 108, 24), bar, _store, "Store")
		_button("制作家具", Rect2(246, 7, 140, 24), bar, _catalog, "Catalog")
		_button("完成", Rect2(502, 7, 110, 24), bar, close, "Finish")
	_update_preview()

func _snap(point: Vector2) -> Vector2:
	var floor := Catalog.House.floor_for(loop.state.furniture)
	return Vector2(clampf(roundf(point.x / Catalog.GRID) * Catalog.GRID, floor.position.x, floor.end.x), clampf(roundf(point.y / Catalog.GRID) * Catalog.GRID, floor.position.y + Catalog.GRID, floor.end.y))

func _update_preview() -> void:
	if mode == "catalog" or not active(): return
	if mode in ["place", "move"]:
		error = Catalog.placement_error(loop.state.furniture, selected_kind, cursor, selected_id if mode == "move" else -1, loop.lane.player.position)
		selection_label.text = tr(Catalog.RECIPES[selected_kind].title)
		status_label.text = tr("可以摆放" if error.is_empty() else error)
		status_label.add_theme_color_override("font_color", Color("52714c") if error.is_empty() else Color("a14b45"))
	else:
		var item: Dictionary = loop.state.furniture_by_id(selected_id)
		selection_label.text = tr("整理房间") if item.is_empty() else tr(Catalog.RECIPES[item.kind].title)
		status_label.text = tr("未选择家具") if item.is_empty() else tr("已选择")
		move_button.disabled = item.is_empty()
		store_button.disabled = item.is_empty() or loop.state.furniture.stock[item.kind] >= Catalog.MAX_STOCK
		if not item.is_empty() and item.kind == "chest" and not item.get("items", {}).is_empty():
			store_button.disabled = true
			status_label.text = tr("箱子内仍有物品")
	root.queue_redraw()

func _start_move() -> void:
	var item: Dictionary = loop.state.furniture_by_id(selected_id)
	if item.is_empty(): return
	selected_kind = item.kind
	cursor = Catalog.position_of(item)
	_room("move")

func _confirm() -> void:
	if not error.is_empty():
		loop.audio.play_event("ui_error")
		return
	var changed: bool
	if mode == "move":
		changed = loop.state.move_furniture(selected_id, cursor, loop.lane.player.position)
	else:
		changed = loop.state.place_furniture(selected_kind, cursor, loop.lane.player.position)
		if changed: selected_id = loop.state.furniture.next_id - 1
	if changed:
		loop.area.refresh_furniture()
		loop.audio.play_event("ui_confirm")
		loop._autosave()
		_room("edit")
	else:
		loop.audio.play_event("ui_error")
		_update_preview()

func _store() -> void:
	if not loop.state.store_furniture(selected_id): return
	selected_id = -1
	loop.area.refresh_furniture()
	loop.audio.play_event("ui_confirm")
	loop._autosave()
	_update_preview()

func _pick(point: Vector2) -> void:
	selected_id = -1
	var best_y := -INF
	for item in loop.state.furniture.placed:
		var texture: Texture2D = Catalog.texture(item.kind)
		var sprite_rect := Rect2(Catalog.position_of(item) - Vector2(texture.get_width() / 2.0, texture.get_height()), texture.get_size())
		if sprite_rect.has_point(point) and item.y >= best_y:
			selected_id = item.id
			best_y = item.y
	_update_preview()

func _room_input(event: InputEvent) -> void:
	if mode == "catalog" or not active(): return
	if event is InputEventMouseMotion:
		cursor = _snap(loop.lane.viewport.get_canvas_transform().affine_inverse() * event.position)
		_update_preview()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = loop.lane.viewport.get_canvas_transform().affine_inverse() * event.position
			cursor = _snap(point)
			if mode in ["place", "move"]:
				_update_preview()
				_confirm()
			else:
				_pick(point)

func _draw_room() -> void:
	if mode == "catalog" or not active(): return
	var transform: Transform2D = loop.lane.viewport.get_canvas_transform()
	var floor := Catalog.House.floor_for(loop.state.furniture)
	for x in range(int(floor.position.x), int(floor.end.x) + 1, Catalog.GRID):
		root.draw_line(transform * Vector2(x, floor.position.y), transform * Vector2(x, floor.end.y), Color(0.95, 0.86, 0.63, 0.20))
	for y in range(int(floor.position.y), int(floor.end.y) + 1, Catalog.GRID):
		root.draw_line(transform * Vector2(floor.position.x, y), transform * Vector2(floor.end.x, y), Color(0.95, 0.86, 0.63, 0.20))
	if mode in ["place", "move"]:
		var texture: Texture2D = Catalog.texture(selected_kind)
		var tint := Color(0.65, 1.0, 0.65, 0.75) if error.is_empty() else Color(1.0, 0.4, 0.4, 0.75)
		root.draw_texture(texture, (transform * cursor - Vector2(texture.get_width() / 2.0, texture.get_height())).round(), tint)
		var rect := Catalog.footprint(selected_kind, cursor)
		root.draw_rect(Rect2(transform * rect.position, rect.size), tint, false, 1.0)
	else:
		var item: Dictionary = loop.state.furniture_by_id(selected_id)
		if not item.is_empty():
			var rect := Catalog.footprint(item.kind, Catalog.position_of(item))
			root.draw_rect(Rect2(transform * rect.position, rect.size), Color("f7dda0"), false, 2.0)

func _input(event: InputEvent) -> void:
	if not active() or InputBindings.capture_active: return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction) or not event.is_pressed(): return
	var focused: Control = loop.lane.viewport.gui_get_focus_owner()
	if event.is_action_pressed("ui_accept") and focused != null and root.is_ancestor_of(focused): return
	if event.is_action_pressed("ui_cancel"):
		cancel()
	elif mode != "catalog":
		if event.is_action_pressed("move_left", true) or event.is_action_pressed("ui_left"): cursor.x -= Catalog.GRID
		elif event.is_action_pressed("move_right", true) or event.is_action_pressed("ui_right"): cursor.x += Catalog.GRID
		elif event.is_action_pressed("move_up", true) or event.is_action_pressed("ui_up"): cursor.y -= Catalog.GRID
		elif event.is_action_pressed("move_down", true) or event.is_action_pressed("ui_down"): cursor.y += Catalog.GRID
		elif not event.is_echo() and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
			if mode in ["place", "move"]: _confirm()
			else: _pick(cursor)
		else: return
		cursor = _snap(cursor)
		_update_preview()
	else: return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if active(): get_tree().paused = paused_before
	if is_instance_valid(layer): layer.queue_free()
