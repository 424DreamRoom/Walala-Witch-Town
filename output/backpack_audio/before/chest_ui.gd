extends Control
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Session = preload("res://Scenes/Storage/grid_session.gd")
const Slot = preload("res://Scenes/Storage/inventory_slot.gd")
const Equipment = preload("res://Scenes/Equipment/equipment_catalog.gd")
const I18n = preload("res://Localization/localized_text.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
var hud
var chest_id := -1
var session
var title: Label
var bag_heading: Label
var chest_heading: Label
var status: Label
var claim: Button
var cursor: Control
var cursor_count: Label
var bag_slots: Array[Button] = []
var chest_slots: Array[Button] = []
var drag_side := ""
var drag_index := -1

func _ready() -> void:
	name = "ChestStorage" if chest_id >= 0 else "Backpack"
	position = Vector2(20, 14)
	size = Vector2(600, 332)
	session = Session.new(hud.loop.state, chest_id)
	var paper: Panel = hud.panel(Rect2(Vector2.ZERO, size), self)
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	title = hud.label("", Rect2(20, 10, 520, 26), self, UISkin.INK, 18)
	var close: Button = hud.button("×", Rect2(550, 10, 32, 25), self, hud.close_modal, "")
	close.name = "CloseChest"
	if chest_id >= 0:
		chest_heading = hud.label("", Rect2(38, 40, 524, 22), self, UISkin.MUTED_INK)
		_create_slots("chest", 12, 66)
	bag_heading = hud.label("", Rect2(38, 112 if chest_id >= 0 else 46, 524, 22), self, UISkin.MUTED_INK)
	_create_slots("bag", 36, 140 if chest_id >= 0 else 78)
	status = hud.label("", Rect2(38, 303, 340, 18), self, UISkin.MUTED_INK)
	claim = hud.button("", Rect2(390, 301, 172, 24), self, _claim, "")
	claim.name = "ClaimLegacyItems"
	cursor = hud.ornament("", Vector2.ZERO, self)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.z_index = 20
	cursor_count = hud.label("", Rect2(12, 17, 24, 16), cursor, Color("fff0cf"))
	cursor_count.add_theme_color_override("font_shadow_color", Color("30212c"))
	cursor_count.add_theme_constant_override("shadow_offset_x", 1)
	cursor_count.add_theme_constant_override("shadow_offset_y", 1)
	refresh_language()
	bag_slots[0].grab_focus()

func _create_slots(side: String, capacity: int, y: int) -> void:
	for index in range(capacity):
		var cell := Slot.new()
		cell.name = side.capitalize() + "Slot" + str(index)
		cell.position = Vector2(38 + (index % 12) * 44, y + (index / 12) * 44)
		cell.size = Vector2(40, 40)
		cell.focus_mode = Control.FOCUS_ALL
		UIFont.apply_control(cell)
		UISkin.compact_button(cell)
		cell.activate = _activate.bind(side, index)
		add_child(cell)
		var icon: Control = hud.ornament("", Vector2(8, 4), cell)
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var quantity: Label = hud.label("", Rect2(3, 23, 33, 14), cell, Color("fff0cf"))
		quantity.name = "Count"
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if side == "bag": bag_slots.append(cell)
		else: chest_slots.append(cell)

func _activate(right: bool, quick: bool, side: String, index: int) -> void:
	var empty: bool = session.hand.is_empty()
	if session.click(side, index, right, quick):
		if empty and not right and not quick and not session.hand.is_empty():
			drag_side = side
			drag_index = index
		_changed()

func _changed() -> void:
	hud.loop.audio.play_event("ui_click")
	hud.refresh()
	refresh_language()
	if session.hand.is_empty(): hud.loop._autosave()

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or event.pressed or drag_index < 0: return
	for side in ["bag", "chest"]:
		var cells: Array = bag_slots if side == "bag" else chest_slots
		for index in range(cells.size()):
			if not cells[index].disabled and cells[index].get_global_rect().has_point(event.position):
				if (side != drag_side or index != drag_index) and session.click(side, index): _changed()
	drag_index = -1
	drag_side = ""

func _process(_delta: float) -> void:
	if not is_instance_valid(cursor): return
	var focused := get_viewport().gui_get_focus_owner()
	if ControllerInput.using_controller and not ControllerInput.pointer_active and focused != null and is_ancestor_of(focused):
		cursor.global_position = focused.get_global_rect().get_center() + Vector2(5, 5)
	else:
		cursor.position = get_local_mouse_position() + Vector2(5, 5)

func _claim() -> void:
	if not session.hand.is_empty(): return
	var moved := Items.claim_overflow(hud.loop.state)
	_changed()
	status.text = tr("已领取 %d 个物品。") % moved

func refresh_language() -> void:
	var state = hud.loop.state
	title.text = tr("木箱 #%d") % chest_id if chest_id >= 0 else tr("女巫的随身背包")
	var used := 0
	for slot in state.bag_slots:
		if not slot.is_empty(): used += 1
	bag_heading.text = tr("背包 · %d / %d 格") % [used, state.bag_capacity()]
	if chest_id >= 0:
		var occupied := 0
		for slot in session.slots("chest"):
			if not slot.is_empty(): occupied += 1
		chest_heading.text = tr("箱子 · %d / %d 格") % [occupied, Items.CHEST_SLOTS]
	for side in ["bag", "chest"]:
		var cells: Array = bag_slots if side == "bag" else chest_slots
		var data: Array = session.slots(side)
		for index in range(cells.size()):
			var cell: Button = cells[index]
			var locked := index >= data.size()
			var slot: Dictionary = {} if locked else data[index]
			var id: String = slot.get("id", "")
			cell.disabled = locked
			cell.modulate.a = 0.35 if locked else 1.0
			var icon = cell.get_node("Icon")
			icon.kind = id
			icon.queue_redraw()
			cell.get_node("Count").text = str(slot.count) if int(slot.get("count", 0)) > 1 else ""
			cell.text = "·" if locked else ""
			cell.tooltip_text = tr("未解锁") if locked else tr("空格子") if id.is_empty() else I18n.format("%s ×%d", [Items.NAMES[id], slot.count])
			if id in Items.TOOLS: cell.tooltip_text += " · " + tr(Equipment.TIERS[state.equipment[id]])
	claim.text = tr("领取旧版物品")
	claim.visible = not state.bag_overflow.is_empty()
	claim.disabled = not session.hand.is_empty()
	claim.tooltip_text = tr("旧版溢出物品")
	cursor.visible = not session.hand.is_empty()
	cursor.kind = session.hand.get("id", "")
	cursor.queue_redraw()
	cursor_count.text = str(session.hand.count) if int(session.hand.get("count", 0)) > 1 else ""

func finish() -> void:
	if session != null:
		session.finish()
		hud.refresh()
		hud.loop._autosave()
		session = null

func _exit_tree() -> void:
	if session != null: session.finish()
