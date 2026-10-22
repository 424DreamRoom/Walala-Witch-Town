extends RefCounted
## Home and farm share rendering, collision and chest behavior.
const Catalog = preload("res://Scenes/Building/furniture_catalog.gd")

static func rebuild(owner: Node2D, area: String) -> void:
	for body in owner.furniture_bodies:
		body.collision_layer = 0
		owner.remove_child(body)
		body.queue_free()
	owner.furniture_bodies.clear()
	for item in owner.loop.state.furniture.placed:
		if Catalog.area_of(item) != area: continue
		var body := StaticBody2D.new()
		body.name = "Furniture" + str(item.id)
		body.position = Catalog.position_of(item)
		body.set_meta("furniture_id", item.id)
		owner.add_child(body)
		var sprite: Node2D
		if item.kind == "chest":
			sprite = preload("res://Scenes/Storage/chest_sprite.gd").new()
			sprite.home = owner
			sprite.chest_id = item.id
		else:
			sprite = Sprite2D.new()
			sprite.texture = Catalog.texture(item.kind)
			sprite.position.y = -sprite.texture.get_height() / 2.0
		body.add_child(sprite)
		if sprite is Sprite2D and item.kind in Catalog.LEGACY_IDS:
			preload("res://Scenes/Gameplay/ambient_animation.gd").attach(sprite, "home_" + item.kind)
		if not Catalog.RECIPES[item.kind].solid: body.z_index = -1
		if Catalog.blocking(item.kind):
			var dimensions: Vector2 = Catalog.RECIPES[item.kind].size
			owner.loop.lane._collision(body, dimensions, Vector2(0, -dimensions.y / 2.0))
			owner.solids.append(Catalog.footprint(item.kind, body.position))
		else: body.collision_layer = 0
		if Catalog.RECIPES[item.kind].category == "lighting":
			var light := preload("res://Scenes/Building/construction_light.gd").new()
			light.loop = owner.loop
			light.position.y = -24
			body.add_child(light)
		owner.furniture_bodies.append(body)

static func nearest_chest(owner: Node2D, area: String) -> Dictionary:
	var result := {}
	var distance := 27.0
	for item in owner.loop.state.furniture.placed:
		if item.kind != "chest" or Catalog.area_of(item) != area: continue
		var rect := Catalog.footprint("chest", Catalog.position_of(item))
		var player: Vector2 = owner.loop.lane.player.position
		var candidate := player.distance_to(player.clamp(rect.position, rect.end))
		if candidate < distance:
			result = item
			distance = candidate
	return result

static func nearest_instrument(owner: Node2D, area: String) -> Dictionary:
	var result := {}
	var distance := 27.0
	for item in owner.loop.state.furniture.placed:
		if item.kind not in Catalog.INSTRUMENT_IDS or Catalog.area_of(item) != area: continue
		var rect := Catalog.footprint(item.kind, Catalog.position_of(item))
		var player: Vector2 = owner.loop.lane.player.position
		var candidate := player.distance_to(player.clamp(rect.position, rect.end))
		if candidate < distance:
			result = item
			distance = candidate
	return result

static func bench_preferred(owner: Node2D, area: String) -> bool:
	var player: Vector2 = owner.loop.lane.player.position
	var distance := Catalog.bench_distance(owner.loop.state.furniture, area, player)
	if distance > Catalog.WORKBENCH_REACH: return false
	var chest := nearest_chest(owner, area)
	if chest.is_empty(): return true
	var rect := Catalog.footprint("chest", Catalog.position_of(chest))
	return distance < player.distance_to(player.clamp(rect.position, rect.end))
