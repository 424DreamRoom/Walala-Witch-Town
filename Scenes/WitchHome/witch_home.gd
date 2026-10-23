extends Node2D

const ART := "res://Art/Environment/Hearthwood/"
const Furniture = preload("res://Scenes/Building/furniture_catalog.gd")
const House = preload("res://Scenes/Building/house_catalog.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
var loop
var solids: Array[Rect2] = []
var fixed_rects: Array[Rect2] = []
var furniture_bodies: Array[StaticBody2D] = []
var stations := {"exit": Vector2(320, 449)}
var spawn := Vector2(320, 405)
var world_size := Vector2i(640, 480)
var room_bounds := Rect2i()
var chest_hint: Label

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "home_layout.json"))
	world_size = House.world_size(loop.state.furniture)
	spawn = Vector2(layout.spawn[0], layout.spawn[1])
	stations.exit = Vector2(layout.exit[0], layout.exit[1])
	var ground := preload("res://Art/Source/tile_ground.gd").create(House.ground_path(loop.state.furniture))
	ground.z_index = Depth.GROUND
	add_child(ground)
	room_bounds = preload("res://Scenes/Gameplay/room_framing.gd").prepare(self, House.ground_path(loop.state.furniture))
	_add_doorway_foreground(ground)
	if loop.state.furniture.legacy_fixtures:
		for values in layout.walls:
			_add_solid(Rect2(values[0], values[1], values[2], values[3]))
	else:
		for rect in House.walls(loop.state.furniture): _add_solid(rect)
	for item in layout.furniture:
		if not loop.state.furniture.legacy_fixtures: break
		if item.kind.trim_prefix("home_") in Furniture.IDS: continue
		var body := StaticBody2D.new()
		body.position = Vector2(item.x, item.y)
		add_child(body)
		var sprite := Sprite2D.new()
		sprite.texture = load(ART + item.kind + ".aseprite")
		sprite.position.y = -sprite.texture.get_height() / 2.0
		body.add_child(sprite)
		preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, item.kind)
		var size := Vector2(item.w, item.h)
		loop.lane._collision(body, size, Vector2(0, -size.y / 2))
		solids.append(Rect2(body.position - Vector2(size.x / 2, size.y), size))
	fixed_rects = solids.duplicate()
	refresh_furniture()
	chest_hint = Label.new()
	chest_hint.z_index = 100
	chest_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest_hint.add_theme_color_override("font_color", Color("fff0cf"))
	chest_hint.add_theme_color_override("font_shadow_color", Color("392b2d"))
	chest_hint.add_theme_constant_override("shadow_offset_x", 1)
	chest_hint.add_theme_constant_override("shadow_offset_y", 1)
	UIFont.apply_control(chest_hint)
	add_child(chest_hint)

func refresh_furniture() -> void:
	solids = fixed_rects.duplicate()
	preload("res://Scenes/Building/placed_construction.gd").rebuild(self, "home")
	loop.lane.solid_rects = solids.duplicate()

func nearest_chest() -> Dictionary:
	return preload("res://Scenes/Building/placed_construction.gd").nearest_chest(self, "home")

func interact() -> void:
	if preload("res://Scenes/Building/placed_construction.gd").bench_preferred(self, "home"):
		loop.builder.open_catalog()
		return
	var instrument := preload("res://Scenes/Building/placed_construction.gd").nearest_instrument(self, "home")
	if not instrument.is_empty():
		loop.hud.open_instrument(instrument.kind)
		return
	var chest := nearest_chest()
	if not chest.is_empty(): loop.hud.open_chest(chest.id)

func _process(_delta: float) -> void:
	var chest := nearest_chest()
	var bench := preload("res://Scenes/Building/placed_construction.gd").bench_preferred(self, "home")
	var instrument := preload("res://Scenes/Building/placed_construction.gd").nearest_instrument(self, "home")
	chest_hint.visible = (bench or not instrument.is_empty() or not chest.is_empty()) and loop.hud != null and loop.hud.mode.is_empty() and not loop.builder.active()
	if not chest_hint.visible: return
	var subject := "建造工作台" if bench else "钢琴" if not instrument.is_empty() else "木箱"
	var anchor: Vector2 = loop.lane.player.position if bench else Furniture.position_of(instrument if not instrument.is_empty() else chest)
	chest_hint.text = tr(subject)
	chest_hint.position = anchor - Vector2(chest_hint.get_minimum_size().x / 2.0, 54)

func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	add_child(body)
	loop.lane._collision(body, rect.size, Vector2.ZERO)
	solids.append(rect)

func _add_doorway_foreground(ground: TileMapLayer) -> void:
	# The threshold row belongs in the same Y-sorted group as actors. Keeping it
	# in the background tilemap lets the witch draw over the doorway shadow.
	# Anchor the copied row at its lower edge so feet above it pass behind and
	# feet below it pass in front, matching the authored step depth.
	var row := floori(stations.exit.y / 16.0) - 1
	var anchor_y := float(row + 1) * 16.0
	var anchor := Node2D.new()
	anchor.name = "DoorwayForeground"
	anchor.position = Vector2(0, anchor_y)
	anchor.z_index = Depth.ACTOR
	var overlay := TileMapLayer.new()
	overlay.name = "Threshold"
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.tile_set = ground.tile_set
	overlay.position.y = -anchor_y
	var half_width := 64.0
	for cell in ground.get_used_cells():
		if cell.y != row: continue
		var center_x := (float(cell.x) + 0.5) * 16.0
		if absf(center_x - stations.exit.x) > half_width: continue
		var source := ground.get_cell_source_id(cell)
		if source < 0: continue
		overlay.set_cell(cell, source, ground.get_cell_atlas_coords(cell), ground.get_cell_alternative_tile(cell))
	anchor.add_child(overlay)
	add_child(anchor)
