extends Node2D
## Tall fixtures share the player's feet-based Y sorting.
const ART := "res://Art/Environment/Hearthwood/"
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const ResidentActor = preload("res://Scenes/Campaign/resident_actor.gd")
const ActorCollision = preload("res://Scenes/Gameplay/actor_collision.gd")
const ShopFood = preload("res://Scenes/Businesses/food_catalog.gd")
@export_enum("blacksmith", "store", "furniture_store") var kind := "blacksmith"
var loop
var solids: Array[Rect2] = []
var stations := {"exit": Vector2(320, 449), "service": Vector2.ZERO}
var spawn := Vector2(320, 405)
var world_size := Vector2i(640, 480)
var service_panel: Panel
var stock: Label
var exit_label: Label
var staff: ResidentActor
var staff_id := ""
var staff_caption := ""
var buttons: Array[Button] = []
var actions: Array = []
var fire: Sprite2D
var clock := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + kind + "_layout.json"))
	world_size = Vector2i(layout.size[0], layout.size[1])
	spawn = Vector2(layout.spawn[0], layout.spawn[1])
	stations.exit = Vector2(layout.exit[0], layout.exit[1])
	stations.service = Vector2(layout.service[0], layout.service[1])
	var ground := preload("res://Art/Source/tile_ground.gd").create(ART + layout.get("ground", kind + "_ground") + ".aseprite")
	ground.z_index = -1
	add_child(ground)
	for values in layout.walls:
		var rect := Rect2(values[0], values[1], values[2], values[3])
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		add_child(body)
		loop.lane._collision(body, rect.size, Vector2.ZERO)
		solids.append(rect)
	for item in layout.furniture:
		var body := StaticBody2D.new()
		body.name = item.kind
		body.position = Vector2(item.x, item.y)
		add_child(body)
		var sprite := Sprite2D.new()
		sprite.texture = load(ART + item.kind + ".aseprite")
		if item.kind == "smith_furnace":
			sprite.texture = load(ART + "smith_fire.aseprite")
			sprite.hframes = 4
			fire = sprite
		sprite.position.y = -sprite.texture.get_height() / 2.0
		body.add_child(sprite)
		if kind == "store" and item.kind == "store_counter":
			_make_food_display(body)
		var size := Vector2(item.w, item.h)
		loop.lane._collision(body, size, Vector2(0, -size.y / 2.0))
		solids.append(Rect2(body.position - Vector2(size.x / 2, size.y), size))
	_make_staff()
	var prompts := Node2D.new()
	prompts.z_index = 10
	add_child(prompts)
	exit_label = _label("小镇", stations.exit, prompts)
	if kind != "furniture_store": _make_panel()

func _make_staff() -> void:
	staff_id = "ember" if kind == "blacksmith" else "lumi"
	staff_caption = "铁匠 · 余烬" if kind == "blacksmith" else "店主 · 露米"
	if kind == "furniture_store": staff_caption = "家具商人"
	var npc := Node2D.new()
	npc.name = "BlacksmithNPC" if kind == "blacksmith" else "StoreNPC"
	# Feet stand behind the anvil/counter, clear of their collision rectangles.
	npc.position = Vector2(294, 276) if kind == "blacksmith" else Vector2(352, 248)
	add_child(npc)
	var ordinal := 0
	for i in range(loop.state.Content.DATA.npcs.size()):
		if loop.state.Content.DATA.npcs[i].id == staff_id:
			ordinal = i
			break
	staff = ResidentActor.new()
	staff.configure(staff_id, ordinal)
	npc.add_child(staff)
	solids.append(ActorCollision.footprint(npc.position))

func _label(value: String, pos: Vector2, parent: Node) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_override("font", UIFont.get_font())
	label.add_theme_font_size_override("font_size", UIFont.BASE_SIZE)
	label.add_theme_color_override("font_color", Color("fff1d3"))
	label.add_theme_color_override("font_shadow_color", Color("30251f"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if parent is Panel or parent is Button:
		label.add_theme_color_override("font_color", UISkin.INK)
		# Zero offset alone leaves Godot's 1px shadow outline filling the glyphs.
		label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		label.add_theme_constant_override("shadow_outline_size", 0)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _make_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	service_panel = Panel.new()
	service_panel.position = Vector2(406, 65)
	service_panel.size = Vector2(228, 244)
	service_panel.add_theme_stylebox_override("panel", UISkin.panel_style())
	layer.add_child(service_panel)
	_label("余烬铁匠铺" if kind == "blacksmith" else "橡果杂货店", Vector2(10, 8), service_panel)
	_label(staff_caption, Vector2(10, 29), service_panel).name = "StaffCaption"
	stock = _label("", Vector2(10, 48), service_panel)
	service_panel.size.y += 20
	var specs: Array = [["smelt", "熔炼铁锭  矿2 + 木1"], ["sell_ore", "售出矿石 ×1   +3金"], ["sell_wood", "售出木材 ×1   +1金"]] if kind == "blacksmith" else [["buy_mushroom", "买蘑菇 ×1    3金"], ["buy_berry", "买莓果 ×1    3金"], ["buy_herb", "买香草 ×1    3金"], ["sell_iron", "售出铁锭 ×1   +8金"], ["sell_fish", "售出鱼 ×1     +4金"]]
	if kind == "store":
		specs.append(["buy_seeds", "香草种子 ×4    2金"])
		specs.append(["sell_herb", "售出香草 ×1    +3金"])
		service_panel.position.y = 12
		service_panel.size.y = 330
	for i in range(specs.size()):
		var button := Button.new()
		button.text = specs[i][1]
		button.position = Vector2(10, (180 + i * 18) if kind == "store" else (86 + i * 28))
		button.size = Vector2(208, 25)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", UIFont.get_font())
		button.add_theme_font_size_override("font_size", UIFont.BASE_SIZE)
		if kind == "store":
			UISkin.compact_button(button)
		loop.audio.ui_audio.bind_button(button)
		button.pressed.connect(transact.bind(specs[i][0]))
		service_panel.add_child(button)
		# Parent theme inheritance must finish before applying the compact height.
		if kind == "store": button.size = Vector2(208, 18)
		buttons.append(button)
		actions.append(specs[i][0])
	if kind == "store": _make_food_cards()
	if kind == "blacksmith":
		var upgrades := [["WandUpgrades", "法杖升级", "wand"], ["EquipmentUpgrades", "背包升级", "bag"]]
		for index in range(upgrades.size()):
			var spec: Array = upgrades[index]
			var upgrade := Button.new()
			upgrade.name = spec[0]
			upgrade.text = spec[1]
			upgrade.position = Vector2(10, 178 + index * 28)
			upgrade.size = Vector2(208, 25)
			UIFont.apply_control(upgrade)
			UISkin.compact_button(upgrade)
			loop.audio.ui_audio.bind_button(upgrade)
			upgrade.pressed.connect(_open_upgrades.bind(spec[2]))
			service_panel.add_child(upgrade)
	_label("白天营业", Vector2(10, 307 if kind == "store" else 240), service_panel)
	service_panel.hide()

func _make_food_display(counter: Node2D) -> void:
	var display := Node2D.new()
	display.name = "MyArtFoodDisplay"
	counter.add_child(display)
	var index := 0
	for id in ShopFood.DATA:
		var sprite := Sprite2D.new()
		sprite.name = id
		sprite.texture = ShopFood.DATA[id].texture
		sprite.position = Vector2(-53 + index * 23, -39)
		display.add_child(sprite)
		index += 1

func _make_food_cards() -> void:
	_label("今日食材", Vector2(10, 85), service_panel)
	var index := 0
	for id in ShopFood.DATA:
		var food: Dictionary = ShopFood.DATA[id]
		var button := Button.new()
		button.name = "Food_" + id
		button.position = Vector2(10 + index * 72, 102)
		button.size = Vector2(64, 72)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = ""
		UISkin.compact_button(button)
		loop.audio.ui_audio.bind_button(button)
		button.pressed.connect(transact.bind("buy_" + id))
		service_panel.add_child(button)
		var icon := TextureRect.new()
		icon.name = "FoodIcon"
		icon.texture = food.texture
		icon.position = Vector2(16, 4)
		icon.size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var name_label := _label(food.name, Vector2(0, 39), button)
		name_label.size = Vector2(64, 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var price := _label(tr("%d金") % food.price, Vector2(0, 55), button)
		price.name = "Price"
		price.size = Vector2(64, 12)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		buttons.append(button)
		actions.append("buy_" + id)
		index += 1

func interact() -> void:
	if kind == "furniture_store":
		if _at_service() and not get_tree().paused:
			if loop.state.phase == "day": loop.hud.open_house_upgrades(self)
			else:
				loop.state.message = "柜台已打烊。"
				loop._show_feedback()
		return
	if _at_service() and not get_tree().paused:
		service_panel.visible = not service_panel.visible
		loop.audio.play_event("ui_open" if service_panel.visible else "ui_close")
		if service_panel.visible: _refresh_panel()
		if loop.state.phase != "day":
			loop.state.message = "柜台已打烊。"
			loop._show_feedback()

func _at_service() -> bool:
	return is_inside_tree() and loop.area == self and loop.location == kind and loop.near(stations.service)

func _open_upgrades(id: String) -> void:
	if service_panel.visible and _at_service() and not get_tree().paused:
		loop.hud.open_equipment_upgrades(self, id)

func transact(action: String) -> void:
	# Stale clicks cannot trade remotely or after closing the panel.
	if not service_panel.visible or not _at_service() or get_tree().paused or action not in actions:
		return
	if loop.state.business_transaction(action):
		loop.audio.play_event("mine" if action == "smelt" else "coins")
		loop._autosave()
	else:
		loop.audio.play_event("ui_error")
	loop._show_feedback()
	_refresh_panel()

func _refresh_panel() -> void:
	var s = loop.state
	s.Items.ensure_bag(s)
	var used := 0
	for slot in s.bag_slots:
		if not slot.is_empty(): used += 1
	stock.text = tr("木%d  矿%d  铁%d  鱼%d\n背包 %d/%d · %d金") % [s.resources.wood, s.resources.ore, s.resources.iron, s.resources.fish, used, s.bag_capacity(), s.coins]
	if kind == "store":
		stock.text = tr("蘑菇%d  莓果%d  香草%d\n背包 %d/%d · %d金") % [s.raw[0], s.raw[1], s.raw[2], used, s.bag_capacity(), s.coins]
	if kind == "blacksmith":
		for id in ["WandUpgrades", "EquipmentUpgrades"]:
			service_panel.get_node(id).disabled = s.phase != "day"
	for i in range(buttons.size()):
		buttons[i].disabled = not s.can_business(actions[i])
		if buttons[i].has_node("Price"):
			buttons[i].get_node("Price").text = tr("%d金") % ShopFood.DATA[actions[i].trim_prefix("buy_")].price

func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(fire):
		fire.frame = int(clock * 6.0) % 4
	staff.pose(delta, false)
	if not is_instance_valid(loop.lane.player):
		return
	var active: bool = loop.state.phase != "result"
	exit_label.visible = active and loop.near(stations.exit)
	exit_label.position = stations.exit + Vector2(-24, -65)
	if kind == "furniture_store": return
	if not active or not loop.near(stations.service):
		service_panel.hide()
	if service_panel.visible:
		_refresh_panel()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(service_panel) and event is InputEventKey and event.is_action_pressed("ui_cancel"):
		service_panel.hide()
